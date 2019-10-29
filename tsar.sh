#!/usr/bin/env bash

set -e
set -u

#
# TarSnap Always Rotating
# github.com/mwgg/tsar
#
# Script to help manage your tarsnap backups, allowing you to use any method
# to create them. Tsar will keep the specified number of daily, weekly and
# monthly backups, deleting the rest.
# A few configuration options are available below this section.
#
# Options:
# -a   Number of daily backups to keep
# -d   Dry run. Will show the delete command instead of running it.
# -k   Tarsnap Key used for writing / deleting backups. Defaults to /root/tarsnap.key.
# -m   Number of monthly backups to keep
# -r   Tarsnap Key used for reading list of backups. Defaults to /root/tarsnap.read.key.
# -v   Verbose output.
# -w   Number of weekly backups to keep
#

###############################################################################
# Configuration:
# Default key locations, which can be overridden by command line parameters:
TARSNAP_READ_KEY="/root/tarsnap.read.key"
TARSNAP_DELETE_KEY="/root/tarsnap.key"

# If you need extra specific options, you can specify them here:
TARSNAP_EXTRA_READ_OPTIONS=""
TARSNAP_EXTRA_DELETE_OPTIONS=""

# Default number of daily, weekly and monthly backups to keep (overridden by command line parameters):
DAILY=30
WEEKLY=12
MONTHLY=48

# Preserve backups older than x months:
IGNORE=0

DOW=1 # Day of the week for weekly # 0 is Sunday
DOM=1 # Day of the month for monthly

###############################################################################

usage() {
    echo "usage: ${0##*/} [-dv] [-k write-key] [-r readonly-key] [-a days] [-w weeks] [-m months]" >&2
    exit 1
}

echo_verbose() {
    [ "$VERBOSE" -eq 1 ] && echo "$@"
    return 0
}

DRY=0
VERBOSE=0
while getopts "dvr:k:a:w:m:" option;do
    case "${option}" in
	a) DAILY=$OPTARG;;
        d) DRY=1;;
	k) TARSNAP_DELETE_KEY=$OPTARG;;
	m) MONTHLY=$OPTARG;;
	r) TARSNAP_READ_KEY=$OPTARG;;
        v) VERBOSE=1;;
	w) WEEKLY=$OPTARG;;
        *) usage;;
    esac
done

if [[ ! $DAILY =~ ^[0-9]+$ ]] ; then
    echo "Number of daily backups to keep needs to be an integer. $DAILY is not a valid value."
    echo "Please specify a valid integer with the -a flag"
    exit 2
elif [[ ! $WEEKLY =~ ^[0-9]+$ ]] ; then
    echo "Number of weekly backups to keep needs to be an integer. $WEEKLY is not a valid value."
    echo "Please specify a valid integer with the -w flag"
    exit 2
elif [[ ! $MONTHLY =~ ^[0-9]+$ ]] ; then
    echo "Number of monthly backups to keep needs to be an integer. $MONTHLY is not a valid value."
    echo "Please specify a valid integer with the -m flag"
    exit 2
fi

if [ ! -e $TARSNAP_READ_KEY ] ; then
    echo "Tarsnap key doesn't exist: $TARSNAP_READ_KEY"
    echo "Please specify a valid key with the -r flag"
    exit 2
elif [ ! -e $TARSNAP_DELETE_KEY ] ; then
    echo "Tarsnap key doesn't exist: $TARSNAP_DELETE_KEY"
    echo "Please specify a valid key with the -k flag"
    exit 2
fi

# The actual commands we use for going to Tarsnap
TARSNAP_R="tarsnap -v --list-archives --keyfile $TARSNAP_READ_KEY $TARSNAP_EXTRA_READ_OPTIONS" # for getting archive list
TARSNAP_D="tarsnap -d --keyfile $TARSNAP_DELETE_KEY $TARSNAP_EXTRA_DELETE_OPTIONS" # for deleting, archive names will be appended here

if [ -e /usr/bin/shred ] ; then
    # Standard place Linux has shred
    SHRED="/usr/bin/shred -u"
elif [ -e /usr/local/bin/gshred ] ; then
    # If you install GNU CoreUtils from FreeBSD Ports
    SHRED="/usr/local/bin/gshred -u"
else
    # Don't have GNU Coreutils.
    SHRED="rm -f"
fi

OSTYPE=$(uname)
LIST=$(mktemp)
LIST_TO_DELETE=$(mktemp)
D_OUTPUT=$(mktemp)
EXIT_CODE=0
FILES_TO_DELETE=0
DATE_UNIX=$(date +%s)
DATE=$(date +%D)
DAILY_DIFF_SEC=$((DAILY*86400))
WEEKLY_DIFF_SEC=$((WEEKLY*604800))
if [ $IGNORE -gt 0 ];then MONTHLY_MAX_UNIX=$(date +%s -d "$DATE -$IGNORE months");fi

if [ "$OSTYPE" = 'FreeBSD' ]; then
    MONTHLY_DATE_UNIX=$(date -v -"$MONTHLY"m -j +%s)
else
    MONTHLY_DATE_UNIX=$(date +%s -d "$DATE -$MONTHLY months")
fi

echo_verbose "Getting the list of archives from Tarsnap"

if ! $TARSNAP_R > "$LIST";then
    cat "$LIST" # tarsnap finished with an error, show it
    $SHRED "$LIST"
    exit 3
fi

while read -r line;do
    FILE_DATE=$(echo "$line" | awk '{print $2}')
    FILE_NAME=$(echo "$line" | awk '{print $1}')
    
    if [ "$OSTYPE" = 'FreeBSD' ]; then
	FILE_DOW=$(date -j -f "%F" "$FILE_DATE" +%w)
	FILE_DOM=$(date -j -f "%F" "$FILE_DATE" +%d)
	FILE_UNIX=$(date -j -f "%F" "$FILE_DATE" +%s)
    else
	FILE_DOW=$(date +%w -d "$FILE_DATE")
	FILE_DOM=$(date +%d -d "$FILE_DATE")
	FILE_UNIX=$(date +%s -d "$FILE_DATE")
    fi
    
    if [ $((DATE_UNIX-FILE_UNIX)) -lt "$DAILY_DIFF_SEC" ];then
        echo_verbose "File younger than $DAILY days, not touching: $FILE_NAME"
        continue
    elif [ "$FILE_DOW" -eq "$DOW" ] && [ $((DATE_UNIX-FILE_UNIX)) -lt "$WEEKLY_DIFF_SEC" ];then
        echo_verbose "File younger than $WEEKLY weeks and its DOW is $FILE_DOW, not touching: $FILE_NAME"
        continue
    elif [ "$FILE_DOM" -eq "$DOM" ] && [ "$MONTHLY_DATE_UNIX" -lt "$FILE_UNIX" ];then
        echo_verbose "File younger than $MONTHLY months and its DOM is $FILE_DOM, not touching: $FILE_NAME"
        continue
    elif [ $IGNORE -gt 0 ] && [ "$MONTHLY_MAX_UNIX" -gt "$FILE_UNIX" ];then
        echo_verbose "File older than $IGNORE months, not touching: $FILE_NAME"
        continue
    fi

    echo "$FILE_NAME" >> "$LIST_TO_DELETE"
    ((++FILES_TO_DELETE))
done < "$LIST"

echo_verbose "Total number of $FILES_TO_DELETE files can be deleted."

if [ "$FILES_TO_DELETE" -gt 0 ];then
    while read -r line;do
        TARSNAP_D="$TARSNAP_D -f $(printf "%q" "$line")"
    done < "$LIST_TO_DELETE"

    if [ "$DRY" -eq 1 ];then
        echo "The following command would be executed:"
        echo "$TARSNAP_D"
    else
        while true
        do
            $TARSNAP_D 2>&1 | tee "$D_OUTPUT"
            EXIT_CODE=$?
            if ! grep -q "Passphrase is incorrect" "$D_OUTPUT";then
                break
            fi
        done
    fi
else
    echo "Nothing to do."
fi

echo_verbose "Getting rid of temporary files."
$SHRED "$LIST" "$LIST_TO_DELETE" "$D_OUTPUT"
echo_verbose "Done."
exit $EXIT_CODE
