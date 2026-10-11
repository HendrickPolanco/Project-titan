# 🗂️ Module 11 — Samba, Uptime Kuma, Portainer

> Status: Uptime Kuma ✅ and Portainer ✅ are running. **Samba was later removed and replaced by FileBrowser** (see `11-titan-services-filebrowser.md`); its section is kept because the lessons still apply.

---

## 1. Samba — network file share (removed later)

### What it is
Implementation of the SMB/CIFS protocol — what makes a folder on TITAN appear as a normal network drive in the Mac Finder or Windows Explorer, instead of using `scp` for every transfer.

### Image choice
The classic `dperson/samba` image is **abandoned** (no maintenance, no security patches). The actively maintained drop-in replacement with the same syntax was used:
```
ghcr.io/depau/docker-samba:main
```

### Ports
```
139  → NetBIOS (legacy compatibility)
445  → modern SMB (what current Mac/Windows use)
```

### Deployment
```bash
docker run -d --name samba -p 139:139 -p 445:445 -v /mnt/titan-storage:/storage ghcr.io/depau/docker-samba:main -u "titan_admin;<password>" -s "titan;/storage;yes;no;no;titan_admin"
```
- `-u "user;password"` — creates a Samba user. Samba keeps its **own** user database, separate from Linux/SSH users even when the name matches.
- `-s "name;path;browseable;readonly;guestok;validusers"` — defines the share: name shown in Finder; path inside the container; visible in network listing; writable (`no` = not read-only); guest access (`no` = login required, least privilege); who may access.

Never paste the real password in chat or in any file that goes to the repo.

### Why it was replaced
Server side was verified correct at every layer (UFW rules, `DOCKER-USER` rules, the user present in Samba's own database with `docker exec samba pdbedit -L`, and `smbutil view //user@ip` from the Mac successfully listing the shares). The client side kept failing with generic permission errors, and a stale mount from an earlier successful attempt (`/Volumes/titan`, found with `mount | grep titan`) was interfering with new ones. When the server is verified correct and one client protocol keeps misbehaving, routing around it with a simpler tool (a web file manager) is reasonable.

Useful macOS commands from that debugging: `smbutil view //user@ip` (list shares), `mount | grep <name>` (find stale mounts), `mount_smbfs` (mount by hand — `smbutil` has no `mount` subcommand).

---

## 2. Uptime Kuma — monitoring

### What it is
Periodically checks whether services respond and alerts if one goes down. **It does not discover Docker containers on its own** — it is independent of Docker, and every monitor has to be added by hand with its own address.

### Deployment
```bash
sudo mkdir -p /opt/titan/uptime-kuma
sudo chown -R titan_admin:titan_admin /opt/titan/uptime-kuma
docker run -d --name uptime-kuma -p 3001:3001 -v /opt/titan/uptime-kuma:/app/data --add-host=host.docker.internal:host-gateway louislam/uptime-kuma:1
docker update --restart unless-stopped uptime-kuma
sudo ufw allow from 192.168.10.0/24 to any port 3001
```
- `:1` pins the major version, avoiding an unannounced jump to a new major release.
- `--add-host=host.docker.internal:host-gateway` makes the name `host.docker.internal` resolve, from inside the container, to the TITAN host. `host-gateway` is a value Docker understands, so no IP is hardcoded.

### Monitors
Type **HTTP(s)** for web services and **TCP Port** for non-HTTP ones:

| Service | Address |
|---|---|
| Pi-hole | `http://host.docker.internal:8080/admin` |
| Jellyfin | `http://host.docker.internal:8096` |
| Immich | `http://host.docker.internal:2283` |
| a TCP service | type TCP Port, host `host.docker.internal`, its port |

The URL field arrives pre-filled with `https://`. Pasting a full URL **on top** of it produced `https://http://...` and the error `getaddrinfo ENOTFOUND http`. Select all and clear the field before typing. Editing the broken monitor did not fully reset it; deleting and recreating it did.

### Troubleshooting saga: monitors stuck "Down" with `timeout of 48000ms exceeded`
The same address loaded fine in the Mac's browser, so Pi-hole itself was healthy and the problem was **container → host** traffic.

1. First hypothesis: the `DOCKER-USER` chain does not cover Docker's internal network as a source. Added `sudo iptables -I DOCKER-USER -s 172.17.0.0/16 -j ACCEPT`. Still timed out.
2. Isolated the problem from inside the container instead of guessing:
   ```bash
   docker exec uptime-kuma curl -v http://172.17.0.1:8080/admin
   ```
   Output stuck at `Trying 172.17.0.1...` until `Connection timed out` — a real, reproducible network block.
3. **Root cause: UFW, not `DOCKER-USER`.** `172.17.0.1` is TITAN's own address on Docker's bridge. Traffic to an address that belongs to the host goes through the `INPUT` chain (UFW's territory), not `FORWARD`/`DOCKER-USER` (which only governs traffic heading to a container). Every UFW rule allowed only the LAN subnet as a source.
   ```bash
   sudo ufw allow from 172.17.0.0/16
   ```
   All monitors came up right away.

**Lesson — two different places can block Docker-related traffic:**
- traffic **to a container / published port** → `FORWARD` / `DOCKER-USER`
- traffic **from a container to the host's own bridge IP** → `INPUT` / **UFW**

**Persistence:** a rule added with `ufw allow` is saved by UFW and reloaded at boot. A raw `iptables -I ...` rule lives only in kernel memory, so it needs something to re-apply it (the `@reboot` cron line). In practice this UFW rule disappeared once after a reboot during the router change, so **re-check `sudo ufw status numbered` for `172.17.0.0/16` whenever Kuma monitors suddenly go down.**

---

## 3. Portainer — visual Docker management

### What it is
A web UI for Docker (container list, start/stop, logs, resource usage) instead of `docker ps` / `docker logs` / `docker stop` on the terminal.

### Deployment
```bash
docker volume create portainer_data
docker run -d --name portainer -p 9000:9000 -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:latest
docker update --restart unless-stopped portainer
sudo ufw allow from 192.168.10.0/24 to any port 9000
```
- `docker volume create` makes a **named volume** managed by Docker (under `/var/lib/docker/volumes/`), unlike the bind mounts used elsewhere. Still persistent.
- `-v /var/run/docker.sock:/var/run/docker.sock` mounts the **Docker socket**, the channel the `docker` CLI uses to talk to the engine. This gives Portainer full control of Docker on the host — a higher privilege than any other service here. That is the reason Homepage was deployed *without* the socket.

### Gotchas
- **Wrong protocol:** the container exposes 9000 (HTTP), 9443 (HTTPS, not published here) and 8000. `https://host:9000` fails with `ERR_SSL_PROTOCOL_ERROR`; use `http://host:9000`.
- **The first-run screen times out** after a few minutes for security ("instance timed out"). `docker restart portainer`, then finish setup immediately.
- **The setup token changes on every restart**, so an old token gives `403`. Take it from the newest log entry (`docker logs portainer | tail -15`) right before submitting.
- Minimum password length: 12 characters.
- A container without a `HEALTHCHECK` shows no `(healthy)` in `docker ps`. That is normal; `Up` is what matters.
