# Tsar
### Tarsnap Always Rotating

Simple script to help manage tarsnap backups by removing unwanted files according to the [grandfather-father-son](https://en.wikipedia.org/wiki/Backup_rotation_scheme#Grandfather-father-son) backup rotation scheme.

Tsar only manages the cleanup of existing archives, and does so in a simple organized way. The manner in which the archives have been created or their naming conventions play no role in Tsar's function, as it uses archive creation dates from Tarsnap. It will keep the specified number of daily, weekly and monthly backups, deleting the rest. It may be run with cron, or manually.

A few parameters are editable directly within the script, such as the number of daily, weekly and monthly backups to keep, as well as days of the week and days of the month to preserve for weekly and monthly backups. As Tsar runs the `tarsnap` command twice - once to obtain the list of archives, and again to delete them as necessary - different commands may be specified for each execution. This is handy when different keys or configuration files and options are used for different tarsnap tasks.

Once configured, Tsar may be executed without any parameters. A couple of flags are available, however:
```
-d   Dry run. Will show the delete command instead of running it.
-v   Verbose output. Will produce commentary to the progress of the script, as well as logic behind keeping the files that need not be deleted.
