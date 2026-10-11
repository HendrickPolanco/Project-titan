# ⚙️ Module 8 — Software and Automation

> Status: ✅ Completed
> Related certifications: Network+, Security+ (general sysadmin practice)

---

## 1. Package management — `apt`

```bash
sudo apt update      # refreshes the LIST of available packages — installs nothing yet
sudo apt upgrade     # installs newer versions of already-installed packages
sudo apt install X   # installs package X
sudo apt remove X    # uninstalls X
```

**Key distinction:** `update` does not update software — it only refreshes the catalog of what versions exist. `upgrade` is what actually installs those newer versions. That's why they're almost always run together: `sudo apt update && sudo apt upgrade`.

---

## 2. Bash scripting basics

A **script** is a text file containing a list of commands, run all at once instead of typed one by one.

### Minimal structure

```bash
#!/bin/bash
echo "Hello TITAN"
```

- **`#!/bin/bash`** (the "shebang") — the first line of any bash script. Tells the system "run this file using bash," regardless of how it's invoked.

### Variables

```bash
#!/bin/bash
name="TITAN"
echo "Hello, $name"
```

- Defined **without spaces** around `=` (`name="TITAN"`, not `name = "TITAN"` — a classic bash syntax error).
- To **use** a variable's value, prefix it with `$` (`$name`); to **define** it, no `$`.

### Making a script executable

```bash
chmod +x my_script.sh
./my_script.sh
```

Reading and writing a file does not grant permission to execute it — `r`, `w`, `x` are independent permission bits. A script is just text until the execute bit is explicitly set; without it, `./my_script.sh` fails with "Permission denied."

### Arguments and special variables

```bash
#!/bin/bash
echo "First argument: $1"
echo "Script name: $0"
```

Running `./greet.sh Hendrick` sets `$1` to `Hendrick`. `$0` is always the script's own name. This makes scripts reusable instead of hardcoding values.

### Conditionals — `if`

```bash
#!/bin/bash
if [ -d /mnt/titan-storage ]; then
    echo "The disk is mounted"
else
    echo "The disk is NOT mounted"
fi
```

- **`[ -d path ]`** — checks "does this path exist AND is it a directory?" (`-f` checks for a specific file instead)
- **`then` / `else` / `fi`** — bash's required block structure (`fi` is "if" spelled backward, closing the block)

### Real example — a simple backup script

```bash
#!/bin/bash
date_stamp=$(date +%Y-%m-%d)
tar -czf /mnt/titan-storage/backup_$date_stamp.tar.gz /home/titan_admin/documents
echo "Backup completed: backup_$date_stamp.tar.gz"
```

- **`$(date +%Y-%m-%d)`** — runs the `date` command with that format and stores the result in the `date_stamp` variable. `$()` means "run this and give me the output as text."
- **`tar -czf`** — creates a compressed archive with the date embedded in the filename.

**Why use `$(date ...)` instead of hardcoding today's date?** The script becomes reusable without editing. A hardcoded date means manually editing the script before every run — and eventually forgetting, and overwriting an old backup with the wrong name. With the dynamic date, the script works identically today, tomorrow, or a year from now, with zero changes.

---

## 3. Cron — scheduling when a script runs

A backup script you have to remember to run manually every day has the same core problem as a hardcoded date: it depends on your memory. **Cron** solves this — a task scheduler that runs a script automatically at a specified time, with no manual trigger needed.

```bash
crontab -e
```
Opens the current user's scheduled task list for editing.

### The 5-field syntax

```
minute  hour  day-of-month  month  day-of-week  command
```

`*` means "any/every" in that field. A line of `* * * * *` means "every minute, of every hour, of every day."

### Worked examples

| Goal | Cron line |
|---|---|
| Every day at 2:00 AM | `0 2 * * * /path/to/script.sh` |
| Every day at 3:30 AM | `30 3 * * * /path/to/script.sh` |
| Every Monday at 6:00 PM | `0 18 * * 1 /path/to/script.sh` |
| First day of every month, midnight | `0 0 1 * * /path/to/script.sh` |
| Every Friday at 11:00 PM | `0 23 * * 5 /path/to/script.sh` |
| Every December 15th, 9:00 AM (fixed yearly date) | `0 9 15 12 * /path/to/script.sh` |

**Day-of-week numbering:** `0` = Sunday, `1` = Monday, `2` = Tuesday ... `6` = Saturday.

**Common trap:** confusing "day-of-month" (3rd field) with "day-of-week" (5th field). Putting `1` in the day-of-month field means "the 1st of every month," not "every Monday" — the day-of-week number belongs in the 5th field specifically.

**Fixed calendar dates** (like Dec 15th) leave the day-of-week field as `*`, since a specific date doesn't depend on which weekday it falls on in a given year.

---

## 4. What this enables for TITAN

With bash scripting + cron combined, TITAN can:
- Run backups automatically on a schedule, with dynamically generated filenames
- Check system health (e.g. verify `/mnt/titan-storage` is still mounted) and log or alert if something's wrong
- Run maintenance tasks (log cleanup, `apt update` checks) without manual intervention

This is the foundation for the "automated maintenance" layer of the homelab, ahead of Module 10 (Docker), where many services will benefit from the same kind of scheduled, unattended operations.
