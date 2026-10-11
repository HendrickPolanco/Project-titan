# 📸 Module 11 — Deploying Immich on TITAN

> Status: ✅ Deployed and working
> First multi-container service on TITAN (uses Docker Compose for real, not a single `docker run`)

---

## 1. What Immich is

A self-hosted photo/video library, similar to Google Photos or iCloud Photos. A mobile app auto-uploads photos in the background, and the server does image recognition (faces, objects) for content-based search.

---

## 2. Why it needs 4 containers instead of 1

Unlike Pi-hole or Jellyfin (single container each), Immich is split into specialized services:

- **`immich-server`** — the API/backend, what the app and browser talk to
- **`immich-machine-learning`** — image recognition (faces, objects, search), isolated because it's CPU/RAM-heavy and spikes hard during uploads
- **`postgres`** — structured data: users, albums, who uploaded what
- **`redis`** — fast in-memory cache for repeated operations

Coordinating 4 separate `docker run` commands by hand would be painful — this is exactly the real-world case for **Docker Compose**: one file describes all 4 services, one command (`docker compose up -d`) starts them all, already networked together automatically.

---

## 3. Hardware requirements (checked before deploying)

| Resource | Minimum | Recommended |
|---|---|---|
| RAM | 4 GB | 6-8 GB |
| CPU | 2 cores | 4+ cores |

TITAN has 30GB RAM / 12 cores — comfortably enough, even accounting for CPU spikes during initial photo library upload (machine-learning processes every image for recognition).

---

## 4. Storage layout

- **App config + compose files** → NVMe: `/opt/titan/immich`
- **Postgres database data** → also NVMe (`/opt/titan/immich/postgres`) — small, structured, read/written constantly, benefits from SSD speed (unlike bulk photo files)
- **Actual photos/videos** → HDD: `/mnt/titan-storage/photos`

```bash
sudo mkdir -p /opt/titan/immich
sudo mkdir -p /mnt/titan-storage/photos
sudo chown -R titan_admin:titan_admin /opt/titan/immich /mnt/titan-storage/photos
```

---

## 5. Deployment — official Compose files

```bash
cd /opt/titan/immich
curl -L https://github.com/immich-app/immich/releases/latest/download/docker-compose.yml -o docker-compose.yml
curl -L https://github.com/immich-app/immich/releases/latest/download/example.env -o .env
```

- `curl -L` — fetches a URL; `-L` follows redirects, `-o` saves with a given filename.

### Editing `.env` before starting

```
UPLOAD_LOCATION=/mnt/titan-storage/photos
DB_DATA_LOCATION=/opt/titan/immich/postgres
TZ=America/New_York          # remember to remove the leading # to uncomment
DB_PASSWORD=<something 12+ chars, alphanumeric only>
```

### The Docker Compose plugin may not be installed by default

`docker.io` (the Ubuntu repo package used to install Docker originally) does **not** always include the `docker compose` plugin. If `docker compose up -d` fails with `unknown shorthand flag: 'd'` or `unknown command: docker compose`, install it separately:

```bash
sudo apt update
sudo apt install docker-compose-v2
docker compose version    # should now return a version number
```

### Starting the stack

```bash
docker compose up -d
```
Creates a private Docker network (`immich_default`) so the 4 containers can talk to each other automatically, then starts all of them.

```bash
docker compose ps          # shows only this project's containers, unlike `docker ps`
```

`restart: always` is already built into the official compose file for all 4 services — no need to manually add `--restart unless-stopped` like with single-container services.

---

## 6. Firewall

Same pattern as every other service — but note: the `DOCKER-USER` rule for `10.0.0.0/24` (with no port specified) already covers any new Docker service automatically, since it doesn't restrict by port. Adding an explicit UFW rule for Immich's port is redundant but harmless:

```bash
sudo ufw allow from 10.0.0.0/24 to any port 2283
```

Access: `http://10.0.0.27:2283`

---

## 7. Storage Template (first-run wizard)

An optional feature that auto-organizes uploaded files into folders using a template with variables (year, month, album, filename, etc.).

**Key finding: there is no `{{username}}` variable.** Immich already separates each user's files into their own folder automatically (`/library/<storage-label>/...`), independent of whatever template is set — this happens before the template is applied, not because of it.

So the Storage Template only controls organization **within** each user's folder (e.g. by year), not whether users are separated — that separation is automatic and unconditional. A reasonable template, if enabling this: `{{y}}/{{filename}}`. Leaving the feature disabled is also fine — per-user separation still happens either way.

---

## 8. Pending

- [ ] None outstanding — mobile app installed, photo backup running
