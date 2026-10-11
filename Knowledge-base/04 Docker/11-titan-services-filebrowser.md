# 📁 Module 11 — FileBrowser (replaced Samba)

> Status: ✅ Deployed and working
> Samba was removed after persistent, hard-to-diagnose client-side connection issues (stuck Finder credentials/mounts) unrelated to the server config, which was confirmed correct throughout

---

## Why the switch

Samba (`ghcr.io/depau/docker-samba:main`) was fully verified healthy server-side — correct UFW rules, correct `DOCKER-USER` rules, user existed in Samba's own user database (`pdbedit -L`), and `smbutil view` from the Mac successfully listed the shares. Despite that, the Finder repeatedly failed to browse the share with generic "need permission" errors, and a stale mount (`/Volumes/titan`) from an earlier, apparently-successful connection was quietly interfering with later attempts. Rather than keep fighting SMB client quirks across Mac/Windows, switched to a web-based file manager — no OS-level network protocol involved, works identically from any device with a browser.

**Lesson:** SMB is notoriously finicky to debug across different OS implementations. When server-side is confirmed correct via every available check (rules, logs, user DB, protocol-level tools) and the client still fails inconsistently, it's reasonable to route around the problem with a different tool rather than keep debugging the protocol itself.

---

## What FileBrowser is

A self-hosted web file manager — browse, upload, download, delete files through a browser, like a personal Google Drive interface. No client-side setup needed on any device.

⚠️ Note: this project is archived as of 2026-09-01 (per its own startup log: "no further releases and no security fixes"). Acceptable for LAN-only use behind the existing firewall, but worth keeping in mind — not a long-term pick if internet-facing use is ever considered.

---

## Deployment

```bash
sudo mkdir -p /opt/titan/filebrowser
sudo chown -R titan_admin:titan_admin /opt/titan/filebrowser

docker run -d --name filebrowser \
  -p 8081:80 \
  -v /mnt/titan-storage:/srv \
  -v /opt/titan/filebrowser:/database \
  --group-add <GID> \
  filebrowser/filebrowser

docker update --restart unless-stopped filebrowser
sudo ufw allow from 192.168.10.0/24 to any port 8081
```

- `-v /mnt/titan-storage:/srv` — the browsable/writable folder, same HDD path used by Jellyfin/Immich
- `-v /opt/titan/filebrowser:/database` — its own config/user database (NVMe)
- `--group-add <GID>` — see the permissions section below for why this is needed

### First-run login

The image generates a **random** admin password on first start (not a fixed `admin`/`admin` default) — grab it from the logs immediately after the first run:
```bash
docker logs filebrowser
# look for: User 'admin' initialized with randomly generated password: <value>
```

---

## Real troubleshooting: 403 errors reading/writing files

Symptom: could log in fine, but any file operation (viewing, downloading, uploading into `/srv/media/...`) returned `403 permission denied` in the logs, even though the underlying folder existed.

### Root cause

The process inside the FileBrowser container runs as its own UID, unrelated to `titan_admin`'s UID on the host. Docker bind mounts don't translate ownership — Linux checks the *numeric* UID/GID of the process against the file's actual owner/group on disk. If neither matches and "others" isn't writable, every operation is denied.

### The quick-but-risky fix (rejected in favor of the proper one)

```bash
sudo chmod -R 777 /mnt/titan-storage
```
Works, but gives every process on the system full read/write/execute on the entire shared storage — too permissive even for a LAN-only setup, and not something worth normalizing as a habit.

### The fix actually used — shared group

```bash
# 1. Create one shared group, reusable for every future service needing write access
sudo groupadd titan-share

# 2. Make it (and titan_admin) the owner of the shared storage
sudo chown -R titan_admin:titan-share /mnt/titan-storage
sudo chmod -R 775 /mnt/titan-storage        # owner+group: rwx, others: r-x only
sudo chmod -R g+s /mnt/titan-storage        # new files/folders inherit the titan-share group automatically

# 3. Find the new group's GID
getent group titan-share                   # e.g. titan-share:x:1003:

# 4. Recreate the container, adding it to that group
docker stop filebrowser
docker rm filebrowser
docker run -d --name filebrowser \
  -p 8081:80 \
  -v /mnt/titan-storage:/srv \
  -v /opt/titan/filebrowser:/database \
  --group-add 1003 \
  filebrowser/filebrowser
docker update --restart unless-stopped filebrowser
```

`--group-add <GID>` makes the container's internal process a member of `titan-share` on the host side — since the folder's group owner is `titan-share` with `rwx` group permissions (from the `775`), the container can now read/write without needing `others` to have any access at all.

**This pattern is reusable** for any future service that needs write access to `/mnt/titan-storage` — just `--group-add` the same GID rather than repeating the permission fight per-service.

---

## Pending

- [ ] Consider a maintained alternative eventually, given FileBrowser's archived status (e.g. filestash, or a Nextcloud-style solution if more features are wanted later)
