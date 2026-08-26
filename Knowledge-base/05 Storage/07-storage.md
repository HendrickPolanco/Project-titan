# 💾 Module 7 — Linux Storage

> Status: 🟡 First disk completed / second disk + RAID pending (needs case for both drives simultaneously)
> Related certifications: Network+, Security+ (general sysadmin practice)

---

## 1. The full storage flow

Before a disk can store files, it goes through 4 stages:

1. **Detection** — Linux recognizes it as a block device (`/dev/sdX`)
2. **Partitioning** — dividing the disk into one or more partitions
3. **Formatting (filesystem)** — giving that partition a filesystem (ext4 is the Linux standard)
4. **Mounting** — telling Linux "make this formatted partition accessible at this folder"

Without step 4, even a formatted disk isn't usable — it needs to be "mounted" somewhere in the folder tree.

### Key terms

- **`lsblk`** ("list block devices") — shows all disks/partitions Linux recognizes, as a tree. A "block device" is any storage device that reads/writes in fixed-size blocks (disks, SSDs, USBs), as opposed to "character devices" (keyboard, mouse) that send data byte by byte.
- **`/dev/`** — the folder where Linux represents hardware devices as files. `sda` = first detected SATA/USB disk.

---

## 2. Real-world case: reusing a drive from an old Synology NAS

`lsblk` on a "used" disk (not blank) can reveal an existing structure. This is exactly what happened with one of TITAN's drives — it came from an old Synology NAS:

```
sda                    1.8T  disk
├─sda1                 2.4G  part
├─sda2                   2G  part
├─sda3                   1K  part
└─sda5                 1.8T  part
  └─md127               1.8T  raid1
    └─vg1000-lv         1.8T  lvm
```

This exact pattern (small partition + ~2G partition + tiny 1K partition + large partition in RAID1+LVM) is the classic Synology DSM partition layout.

### Confirming before touching anything

```bash
sudo lvs                              # list active LVM logical volumes
sudo blkid /dev/vg1000/lv             # check filesystem type
```

`blkid` returned `TYPE="ext4"` and a `LABEL` in DSM's format — confirming it was Synology data, standard ext4 (no extra driver needed).

### Safely exploring before deciding

```bash
sudo mkdir -p /mnt/nas-viejo
sudo mount -o ro /dev/vg1000/lv /mnt/nas-viejo   # -o ro = read-only, no risk while exploring
df -h /mnt/nas-viejo                              # check usage
ls -la /mnt/nas-viejo                             # check contents
```

In this case: only 54GB used out of 1.8TB (3%), containing old user folders (personal files, photos, music) plus Synology system folders (prefixed with `@`). Since the same data existed on the second drive, and a portable SSD is planned for long-term backup, the decision was made to wipe this drive and reuse it for TITAN.

---

## 3. Tearing down an existing RAID+LVM structure

**⚠️ Only do this once you're certain the data isn't needed — these steps are destructive.**

The structure has 3 layers stacked on top of raw partitions, and each must be undone top-down:

```
ext4 (filesystem)
  ↓
vg1000-lv (LVM)
  ↓
md127 (RAID1)
  ↓
sda5, sda1, sda2, sda3 (old partitions)
```

```bash
# 1. Unmount
sudo umount /mnt/nas-viejo

# 2. Deactivate the LVM logical volume
sudo lvchange -an /dev/vg1000/lv

# 3. Remove the Volume Group and Physical Volume
sudo vgremove vg1000
sudo pvremove /dev/md127

# 4. Stop and clear the RAID
sudo mdadm --stop /dev/md127
sudo mdadm --zero-superblock /dev/sda5   # erases the "memory" that this partition was part of a RAID
```

### ⚠️ Point of no return — wiping all partition signatures

```bash
sudo wipefs -a /dev/sda
```

This erases all partition table / filesystem signatures on the whole disk. After this, `sda1`, `sda2`, etc. cease to exist, and the disk is blank. **Verify with `lsblk` afterward** that no partitions remain before proceeding.

---

## 4. Partitioning a blank disk — `fdisk`

**`fdisk`** ("fixed disk") — interactive tool to create/modify/delete partitions.

```bash
sudo fdisk /dev/sda
```

Inside the interactive prompt (`Command (m for help):`), single-letter commands:

| Key | Meaning | Action |
|---|---|---|
| `n` | new | Create a new partition |
| `p` | primary | Partition type (standard, almost always what you want) |
| `w` | write | Save changes to disk permanently |
| `q` | quit | Exit without saving (safe to cancel) |
| `d` | delete | Delete an existing partition |
| `m` | menu | Show help menu |

**Sequence to create one partition using the whole disk:**
1. `n` → Enter (accept `primary`) → Enter (accept partition number `1`) → Enter (accept first sector) → Enter (accept last sector — uses all available space)
2. `w` → writes changes to disk

**Common mistake:** running `fdisk -l /dev/sda` (with `-l`, "list") instead of `fdisk /dev/sda`. The `-l` flag only prints disk info and exits immediately — it does **not** open the interactive prompt, so typing `n` afterward gets interpreted as a shell command (`n: command not found`).

---

## 5. Formatting — `mkfs.ext4`

**`mkfs`** ("make filesystem") — creates a filesystem inside a partition.

```bash
sudo mkfs.ext4 /dev/sda1
```

Without this step, `mount` fails with an "unknown filesystem type" error — the partition exists, but has no structure to organize files yet.

---

## 6. Mounting

```bash
sudo mkdir -p /mnt/titan-storage      # create the mount point folder
sudo mount /dev/sda1 /mnt/titan-storage
```

### Why the available space is slightly less than the disk's advertised size

Three separate factors, each small, that stack up:

1. **TB vs TiB** — manufacturers advertise "2TB" using base-10 (1TB = 1,000,000,000,000 bytes); Linux measures in TiB, base-2 (1 TiB = 1,099,511,627,776 bytes). Since a TiB is slightly larger, the same physical "2TB" disk shows as ~1.82 TiB in Linux.
2. **ext4's reserved root margin** — by default, `mkfs.ext4` reserves ~5% of space for the root user (emergency space if the disk fills up).
3. **Filesystem metadata** — ext4 needs to store its own internal structures (inodes, journal, tables).

Net result: "2TB" (marketing) → 1.82 TiB (Linux measurement) → minus ~5% reserved + metadata → ~1.7TB usable.

### Recovering the reserved 5% (optional, for data disks)

```bash
sudo tune2fs -m 0 /dev/sda1
```

`tune2fs` ("tune" + "2fs", for the ext2/3/4 family) adjusts parameters of an *existing* ext filesystem without reformatting. `-m` sets the reserved percentage; `0` removes the root safety margin entirely. Reasonable for a data disk; less advisable on the system's root partition (where that margin matters if the disk fills up).

---

## 7. Automatic mounting at boot — `/etc/fstab`

**`fstab`** ("filesystems table") — the file listing which partitions Linux should mount automatically, and where, on every boot. A manual `mount` only lasts until the next reboot.

### Why use UUID instead of the device name

```bash
sudo blkid /dev/sda1
```

Device names like `/dev/sda1` **can change** between reboots (e.g. if another disk is added, Linux might rename things to `sdb1`). The **UUID** is a unique, permanent identifier for that specific partition — safer for `fstab` to avoid mounting the wrong disk in the wrong place.

### Procedure

```bash
sudo cp /etc/fstab /etc/fstab.backup     # backup first, same discipline as sshd_config
sudo nano /etc/fstab
```

Add a line at the end:
```
UUID=<your-uuid-here>  /mnt/titan-storage  ext4  defaults  0  2
```

- 5th field (`0`): whether to back up with `dump` (legacy tool, rarely used today)
- 6th field (`2`): fsck check order at boot (`1` for root `/`, `2` for everything else)

### Testing without rebooting

```bash
sudo mount -a
```

`-a` ("all") mounts everything listed in `fstab` that isn't already mounted. If there's a syntax error, this surfaces it immediately — a bad `fstab` entry can otherwise cause boot issues discovered only after a reboot.

### ⚠️ Real lesson: a typo that produced no error

A typo (`defautls` instead of `defaults`) was written into `fstab`. Running `sudo mount -a` produced **no error at all** — the partition mounted anyway, but without the standard options `defaults` groups together (the unrecognized option was silently ignored by `mount`).

**Lesson:** the absence of an error does not guarantee the command did exactly what was intended. Always verify the actual applied result:

```bash
mount | grep titan-storage
# /dev/sda1 on /mnt/titan-storage type ext4 (rw,relatime)
```

After fixing the typo, `(rw,relatime)` confirmed `defaults` was correctly applied.

---

## 8. Pending — when the case arrives for both drives

- RAID theory (why it exists, RAID1 vs RAID5, mirroring vs parity)
- Applying the same partition/format/mount flow to the second 2TB drive
- Deciding whether to combine both drives in a software RAID for TITAN, or keep them independent
