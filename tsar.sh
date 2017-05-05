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
# -d   Dry run. Will show the delete command instead of running it.
# -v   Verbose output.
# 

###############################################################################
# Configuration:
# If you are using multiple keys or other specific options, you can specify them here:
TARSNAP_R="tarsnap -v --list-archives --keyfile /root/tarsnap.read.key" # for getting archive list
TARSNAP_D="tarsnap -d --keyfile /root/tarsnap.key" # for deleting, archive names will be appended here

# Number of daily, weekly and monthly backups to keep:
DAILY=30
WEEKLY=12
MONTHLY=48

# Preserve backups older than x months:
IGNORE=0

DOW=1 # Day of the week for weekly # 0 is Sunday
DOM=1 # Day of the month for monthly

###############################################################################

DRY=0
VERBOSE=0
while getopts "dv" option;do
    case "${option}" in
        d) DRY=1;;
        v) VERBOSE=1;;
    esac
done

LIST=$(mktemp)
LIST_TO_DELETE=$(mktemp)
D_OUTPUT=$(mktemp)
EXIT_CODE=0
FILES_TO_DELETE=0
DATE_UNIX=$(date +%s)
DATE=$(date +%D)
DAILY_DIFF_SEC=$((DAILY*86400))
WEEKLY_DIFF_SEC=$((WEEKLY*604800))
MONTHLY_DATE_UNIX=$(date +%s -d "$DATE -$MONTHLY months")
if [ $IGNORE -gt 0 ];then MONTHLY_MAX_UNIX=$(date +%s -d "$DATE -$IGNORE months");fi

if [ "$VERBOSE" -eq 1 ];then echo "Getting the list of archives from Tarsnap";fi

if ! $TARSNAP_R > "$LIST";then
    cat "$LIST" # tarsnap finished with an error, show it
    shred -u "$LIST"
    exit 3
fi

while read -r line;do
    FILE_DATE=$(echo "$line" | awk '{print $2}')
    FILE_NAME=$(echo "$line" | awk '{print $1}')
    FILE_DOW=$(date +%w -d "$FILE_DATE")
    FILE_DOM=$(date +%d -d "$FILE_DATE")
    FILE_UNIX=$(date +%s -d "$FILE_DATE")
    
    if [ $((DATE_UNIX-FILE_UNIX)) -lt "$DAILY_DIFF_SEC" ];then
        if [ "$VERBOSE" -eq 1 ];then
            echo "File younger than $DAILY days, not touching: $FILE_NAME"
        fi
        continue
    elif [ "$FILE_DOW" -eq "$DOW" ] && [ $((DATE_UNIX-FILE_UNIX)) -lt "$WEEKLY_DIFF_SEC" ];then
        if [ "$VERBOSE" -eq 1 ];then
            echo "File younger than $WEEKLY weeks and its DOW is $FILE_DOW, not touching: $FILE_NAME"
        fi
        continue
    elif [ "$FILE_DOM" -eq "$DOM" ] && [ "$MONTHLY_DATE_UNIX" -lt "$FILE_UNIX" ];then
        if [ "$VERBOSE" -eq 1 ];then
            echo "File younger than $MONTHLY months and its DOM is $FILE_DOM, not touching: $FILE_NAME"
        fi
        continue
	elif [ $IGNORE -gt 0 ] && [ "$MONTHLY_MAX_UNIX" -gt "$FILE_UNIX" ];then
		if [ "$VERBOSE" -eq 1 ];then
			echo "File older than $IGNORE months, not touching: $FILE_NAME"
		fi
		continue
    fi

    echo "$FILE_NAME" >> "$LIST_TO_DELETE"
    ((FILES_TO_DELETE++))
done < "$LIST"

if [ "$VERBOSE" -eq 1 ];then echo "Total number of $FILES_TO_DELETE files can be deleted.";fi

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

if [ "$VERBOSE" -eq 1 ];then echo "Getting rid of temporary files.";fi
shred -u "$LIST" "$LIST_TO_DELETE" "$D_OUTPUT"
if [ "$VERBOSE" -eq 1 ];then echo "Done.";fi
exit $EXIT_CODE
