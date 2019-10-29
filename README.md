# Tsar
### Tarsnap Always Rotating

Simple script to help manage tarsnap backups by removing unwanted files according to the [grandfather-father-son](https://en.wikipedia.org/wiki/Backup_rotation_scheme#Grandfather-father-son) backup rotation scheme.

Tsar only manages cleanup of existing archives, but does so in a simple and straight-forward way. The manner in which the archives have been created or their naming conventions play no role in Tsar's function, as it uses archive creation dates obtained from Tarsnap. It will keep the specified number of daily, weekly and monthly backups, deleting the rest. It may be run with cron (if configured with a non-passphrased Tarsnap key), or manually.

A few parameters are editable directly within the script, such as the number of daily, weekly and monthly backups to keep, as well as days of the week and days of the month to preserve for weekly and monthly backups.

It is possible to protect older backups not using this scheme from deletion. Check the options in the script before first run.

Tsar runs the `tarsnap` command twice - once to obtain the list of archives, and again to delete them as necessary - and different commands may be specified for each execution. This is handy when different keys or configuration files and options are used for different tarsnap tasks, or if you wish to supply Tsar with a list of archives from a different source - just replace the command and make sure its output is a list of archives in the same format as produced by `tarsnap -v --list-archives`.

Once configured, Tsar may be executed without any parameters. A couple of flags are available, however:
```
-a <number>            Number of daily backups to keep
-d                     Dry run. Will show the delete command instead of running it.
-k <tarsnap-keyfile>   Tarsnap Key used for writing / deleting backups. Defaults to /root/tarsnap.key.
-m <number>            Number of monthly backups to keep
-r <tarsnap-keyfile>   Tarsnap Key used for reading list of backups. Defaults to /root/tarsnap.read.key.
-v                     Verbose output. Will produce commentary to the progress of the script, as well as logic behind keeping the files that need not be deleted.
-w <number>            Number of weekly backups to keep

```
