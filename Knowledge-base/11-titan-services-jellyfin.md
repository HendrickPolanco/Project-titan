# 🎬 Module 11 — Deploying Jellyfin on TITAN

> Status: ✅ Deployed and working
> Second real Docker service on TITAN, after Pi-hole

---

## 1. What Jellyfin is

A self-hosted media streaming server — a personal Netflix-equivalent, serving your own movies/shows/music instead of licensed catalog content, accessible from any device on the network (or externally, if configured) through a browser or dedicated app.

---

## 2. Storage layout — same NVMe/HDD split as Pi-hole

- **Config** (settings, watch history, user accounts) → NVMe, small and frequently accessed: `/opt/titan/jellyfin`
- **Media files** (the actual video files, potentially hundreds of GB) → HDD, bulk storage: `/mnt/titan-storage/media`

```bash
sudo mkdir -p /opt/titan/jellyfin
sudo mkdir -p /mnt/titan-storage/media
```

---

## 3. Deployment

```bash
docker run -d --name jellyfin -p 8096:8096 -v /opt/titan/jellyfin:/config -v /mnt/titan-storage/media:/media jellyfin/jellyfin
```

- `-d` — detached, runs in the background
- `--name jellyfin` — readable identifier for later commands (`docker logs jellyfin`, etc.)
- `-p 8096:8096` — Jellyfin's default port, both inside and outside the container (unlike Pi-hole, which used different host/container ports — this is just Jellyfin's own convention, not a Docker rule)
- `-v /opt/titan/jellyfin:/config` — bind mount for settings/database
- `-v /mnt/titan-storage/media:/media` — bind mount for the actual video library
- `jellyfin/jellyfin` — the Docker Hub image

Unlike Pi-hole, this deployment had **no port conflicts and no networking issues** — went straight from `docker run` to a working dashboard.

---

## 4. Post-deployment steps (same pattern as every service going forward)

```bash
docker update --restart unless-stopped jellyfin   # survive host reboots
sudo ufw allow from 10.0.0.0/24 to any port 8096  # local-network-only access
```

Access: `http://10.0.0.27:8096` → runs the first-time setup wizard (language, admin user, media library).

When adding a media library in the wizard, point it at the container's internal `/media` path — that's the one bind-mounted to the real HDD folder. The folder starts empty until video files are actually copied there.

---

## 5. Pending

- [ ] Transfer video files from the Mac to `/mnt/titan-storage/media` (via `scp` or similar)
