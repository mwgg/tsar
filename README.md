# Tarsnap Always Rotating

Simple script to help manage your tarsnap backups by removing unwanted files according to the [grandfather-father-son](https://en.wikipedia.org/wiki/Backup_rotation_scheme#Grandfather-father-son) scheme.

Tsar doesn't manage creating backups, but only the cleanup, in a simple organized and configurable way. it will keep the specified number of daily, weekly and monthly backups, deleting the rest.

Options:
```
-d   Dry run. Will show the delete command instead of running it.
-v   Verbose output.
```

A few parameters are editable directly within the script, such as the number of daily, weekly and monthly backups to keep, as well as days of the week and days of the month to preserve for weekly and monthly backups.

As Tsar runs the `tarsnap` command twice - once to obtain the list of archives, and again to delete them as necessary - you may also specify different commands. This comes in handy when you are using different keys or configuration files and options for different tarsnap tasks.
