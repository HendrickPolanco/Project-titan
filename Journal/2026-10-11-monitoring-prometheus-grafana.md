# 📓 2026-10-11 — Monitoring Stack: Prometheus + Grafana

## What happened today

- Clarified the role of each tool: Uptime Kuma (is it up), Portainer (manage containers), Prometheus (stores metrics over time), Grafana (graphs them).
- Measured the existing footprint with `docker stats --no-stream`: 11 containers, about 1.8 GiB RAM, CPU about 0.2 % — plenty of headroom before adding the stack.
- Deployed Prometheus, node_exporter, cAdvisor and Grafana with one Compose file in `/opt/titan/monitoring`.
- Opened port 3002 to the LAN only; Prometheus (9090) left unpublished on purpose.
- Connected Grafana to Prometheus (`http://prometheus:9090`), imported dashboards 1860 and 14282, added Grafana to Homepage.

## Lessons

- Containers in the same Compose network reach each other by service name; UFW is not involved.
- Retention limits (time and size) keep a metrics database from silently filling a disk.
- Mistake caught: an earlier RAM estimate (3.7 GiB) was wrong; the measured figure was about 1.8 GiB. Measure before estimating.

## Status

Reported working by the owner. The `up` query result and dashboards were not independently verified.

## Pending

- [ ] Record real RAM/disk use of the new stack
- [ ] Homepage disk widget: one per disk (NVMe vs HDD)
- [ ] Find out where the Netdata tab came from
- [ ] Alerting (Kuma push + Telegram/Discord)
- [ ] Router DNS fix so `*.titan.home.arpa` works on all devices
