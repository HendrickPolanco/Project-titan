# 📓 2026-08-23 — SSH Hardening Completed + Storage (Module 7) + Quiz App

## What was covered today

- Closed out the pending SSH hardening from Module 6 (executed live on TITAN)
- Full Module 7 — Linux Storage: disk detection, tearing down an inherited RAID1+LVM structure from an old Synology NAS, partitioning, formatting, mounting, and permanent mounting via `/etc/fstab`
- Added a new "TITAN Homelab" category (34 questions) to a personal quiz app, covering applied practice from this and prior sessions

## SSH hardening — real troubleshooting encountered

Set `PasswordAuthentication no`, `PubkeyAuthentication yes`, `PermitRootLogin no` in `/etc/ssh/sshd_config`, but password login kept working after `systemctl restart sshd`.

**Root cause found:** `/etc/ssh/sshd_config.d/50-cloud-init.conf` contained `PasswordAuthentication yes`, and since `sshd_config` includes that directory near the top of the file, the first matching directive wins — the cloud-init override took precedence over the change made later in the main file.

**Fix:** edited `50-cloud-init.conf` directly, changed to `no`, restarted `sshd`.

**Verified correctly this time:** opened a new terminal without closing the active session, tested `ssh titan_admin@10.0.0.27` with password → `Permission denied (publickey)` (expected). Confirmed `ssh titan` (key-based) still worked. Hardening confirmed complete.

## Storage — applied to a real disk with history

One of TITAN's 2TB drives came from a previous Synology NAS, with an existing RAID1 + LVM + ext4 structure (~54GB of old user data, deemed disposable since duplicated on the second drive).

```bash
# Explored safely first (read-only mount)
sudo mount -o ro /dev/vg1000/lv /mnt/nas-viejo

# Torn down in order: filesystem → LVM → RAID → partitions
sudo umount /mnt/nas-viejo
sudo lvchange -an /dev/vg1000/lv
sudo vgremove vg1000
sudo pvremove /dev/md127
sudo mdadm --stop /dev/md127
sudo mdadm --zero-superblock /dev/sda5
sudo wipefs -a /dev/sda

# Fresh partition, filesystem, mount
sudo fdisk /dev/sda            # created sda1, full disk
sudo mkfs.ext4 /dev/sda1
sudo mkdir -p /mnt/titan-storage
sudo mount /dev/sda1 /mnt/titan-storage

# Permanent mount via fstab (UUID-based)
sudo cp /etc/fstab /etc/fstab.backup
# added: UUID=6f76c01b-... /mnt/titan-storage ext4 defaults 0 2
sudo mount -a
```

Result: `/dev/sda1 on /mnt/titan-storage type ext4 (rw,relatime)`, 1.7TB usable.

## Mistakes caught and corrected today

1. `fdisk -l /dev/sda` confused with `fdisk /dev/sda` — the `-l` flag only lists info and exits, doesn't open the interactive prompt
2. `sudo -p /mnt/titan-storage` — flag placed on `sudo` instead of on `mkdir`
3. A typo (`defautls` instead of `defaults`) in `/etc/fstab` produced **no error** on `mount -a`, but silently failed to apply the intended options — verified only by checking `mount | grep` for the real applied result
4. Ran `wipefs -a` before the planned verification step — no harm done since the data was already confirmed disposable, but a reminder that destructive commands deserve the full verification sequence every time, not just when it's convenient

## Quiz app — TITAN Homelab category added

Extended a personal quiz app (`quizmaster-v2`) with a new category for applied, TITAN-specific practice (separate from the existing generic Network+/Security+ theory categories). 34 questions covering subnetting math, DHCP/DNS, routing, UFW, SSH hardening (including the cloud-init bug), and storage/fstab — meant for practicing on the phone away from the homelab.

## Pending

- [ ] Module 7 continued: second 2TB drive + RAID theory, once the case arrives
- [ ] Module 8 — Automation (bash scripting, cron)
- [ ] Module 9 — Advanced security
- [ ] Module 10 — Docker/Virtualization

## Overall progress

```
Linux fundamentals       ██████████ 100%
SSH                       ██████████ 100%
Networking                ██████████ 100%
Firewall/Linux Security   ██████████ 100%
Storage                   ████████░░  80%
Automation                 ░░░░░░░░░░   0%
Docker/Virtualization      ░░░░░░░░░░   0%
```
