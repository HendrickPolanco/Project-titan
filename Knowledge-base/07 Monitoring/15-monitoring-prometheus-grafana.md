# 📈 Module 15 — Monitoring: Prometheus + Grafana

> Status: ✅ Deployed (reported working by the owner; the `up` query output and dashboards were not independently verified)
> Related certifications: Network+ (monitoring and troubleshooting), Security+ (logging and monitoring)

---

## 1. Why add monitoring if Uptime Kuma already exists?

| Tool | Answers the question | Analogy |
|------|----------------------|---------|
| Uptime Kuma | "Is the service up right now?" | A doorbell test: does someone answer? |
| Portainer | "What containers exist and how do I manage them?" | The control panel |
| Prometheus | "What were the numbers at 03:12 last night?" | A flight recorder: stores metrics over time |
| Grafana | "Show me those numbers as graphs" | The dashboard screen reading the recorder |

Kuma says *that* something failed. Prometheus + Grafana help show *why* (RAM, CPU, disk, per-container usage at the moment of failure).

## 2. Components

- **Prometheus** — time-series database that *scrapes* (pulls) metrics over HTTP every 15 s. Name: Prometheus, the Titan who brought fire; here, "brings" data.
- **node_exporter** — exposes host (TITAN) metrics: CPU, RAM, disks, network. "Exporter" = translates a system's stats into Prometheus format.
- **cAdvisor** (Container Advisor, by Google) — exposes per-container metrics.
- **Grafana** — visualization; reads Prometheus as a data source.

Flow: `node_exporter / cAdvisor  <--scrape--  Prometheus  <--query--  Grafana  -->  browser`

## 3. Files (`/opt/titan/monitoring/`)

### `prometheus.yml`
```yaml
global:
  scrape_interval: 15s
scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets: ['localhost:9090']
  - job_name: node
    static_configs:
      - targets: ['node-exporter:9100']
  - job_name: cadvisor
    static_configs:
      - targets: ['cadvisor:8080']
```

### `docker-compose.yml` (summary of the choices)
- `prometheus` — `prom/prometheus:latest`, retention `30d` **and** `5GB` (whichever hits first, so metrics can never fill the disk), config bind-mounted, data in named volume `prometheus_data`.
- `node-exporter` — `prom/node-exporter:latest`, `pid: host`, `--path.rootfs=/host`, host `/` mounted read-only at `/host`.
- `cadvisor` — `ghcr.io/google/cadvisor:0.56.1`, `privileged: true`, device `/dev/kmsg`, read-only mounts of `/`, `/var/run`, `/sys`, `/var/lib/docker/`, `/dev/disk/`.
- `grafana` — `grafana/grafana-oss:latest`, published as `3002:3000` (3000 is already Homepage), data in named volume `grafana_data`.

Validate and run:
```bash
docker compose config -q     # config = print resolved file; -q = quiet, only errors
docker compose pull          # download images
docker compose up -d         # up = create+start; -d = detached (background)
docker compose ps            # ps = process status of this stack's containers
```

## 4. Design decisions

1. **Services talk by name inside the Compose network** (`prometheus:9090`, `node-exporter:9100`). Docker's internal DNS resolves them, so no UFW rule is needed for scraping.
2. **Prometheus port 9090 is not published.** Prometheus has no login; publishing it would expose all metrics to the LAN. Grafana (which has a login) is the only door. If needed temporarily for the Status → Targets page, add `ports: - "9090:9090"` and remove it afterwards.
3. **Why a new Compose network matters for UFW:** each Compose project gets its own `172.x` subnet. UFW only allows `172.17.0.0/16` for container → host traffic, so a container in a new network trying to reach the host (not another container) would be blocked.
4. **cAdvisor is `privileged`** — needed to read container stats; treat it as a trusted-image-only exception (least privilege trade-off).
5. **Pinned cAdvisor version, `latest` for the others** — acceptable for a lab; for stability, pin versions later.

## 5. Firewall

```bash
sudo ufw allow from 192.168.10.0/24 to any port 3002
```
Only the LAN can reach Grafana (port 3002). Remote access goes through Tailscale.

## 6. Grafana setup

1. First login `admin` / `admin` → forced password change. Store the new one in a password manager, never in the repo.
   Reset if lost: `docker exec -it grafana grafana cli admin reset-admin-password --password-from-stdin`
2. **Connections → Data sources → Add → Prometheus**, URL `http://prometheus:9090` → *Save & test*.
3. **Verify:** Explore → Code tab → query `up`. Expected 3 rows with value `1`: `prometheus`, `node`, `cadvisor`. (`up` = 1 means the last scrape succeeded, 0 means failed.)
4. **Dashboards → New → Import** → ID `1860` (Node Exporter Full) → Load; repeat with `14282` (cAdvisor / Docker containers).
5. Added Grafana to Homepage (`services.yaml`).

## 7. Resource footprint

Before: 11 containers ≈ 1.8 GiB RAM, CPU ≈ 0.2 % of 12 cores (`docker stats --no-stream`).
Largest: immich_server ~806 MiB, jellyfin ~261, immich_postgres ~229, immich_machine_learning ~162.

Estimate for this stack (estimate, not measured): +0.3–0.8 GiB RAM, 1.5–3 GB disk (capped by the 5 GB retention limit). Re-measure with `docker stats --no-stream` and record the real figure here.

## 8. Known gaps / observations

- Homepage's disk widget measures the **NVMe root volume**, not the photo HDD. Fix: one widget per disk.
- A Netdata tab was seen open in the browser, but no Netdata container exists on TITAN — unexplained, to investigate.
- Not yet done: alerting (e.g. Uptime Kuma push + Telegram/Discord for backup failures), pinned image versions.

## 9. Verification checklist

- [ ] `docker compose ps` shows 4 containers `Up`
- [ ] `up` query returns 3 rows = 1
- [ ] Dashboard 1860 shows live CPU/RAM
- [ ] Dashboard 14282 lists the containers
- [ ] Real RAM/disk numbers recorded in section 7
