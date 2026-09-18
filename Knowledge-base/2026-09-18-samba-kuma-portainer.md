# 📓 2026-09-18 — Samba, Uptime Kuma, Portainer + UFW vs Docker-internal traffic

## What happened today

Closed out the "Personal services" trio with Samba, then added Uptime Kuma (monitoring) and Portainer (visual Docker management) — 6 services now running on TITAN. Uptime Kuma setup turned into a real multi-step troubleshooting saga.

## Samba

Deployed with `ghcr.io/depau/docker-samba:main` (the original `dperson/samba` is abandoned/unmaintained). One share covering all of `/mnt/titan-storage`, connected successfully from the Mac Finder via `smb://10.0.0.27`.

## Uptime Kuma — the real story of today

1. Learned it does not auto-discover Docker containers — every monitor added by hand.
2. First monitor (Pi-hole) failed with `getaddrinfo ENOTFOUND http` — turned out the URL field's pre-filled `https://` got prefixed onto a pasted `http://` URL instead of being replaced, producing a broken double-protocol string. Fixed by clearing the field before pasting, and recreating the monitor from scratch since editing the corrupted one didn't fully reset its internal state.
3. Next failure: `timeout of 48000ms exceeded`, even though Pi-hole loaded fine from the Mac browser directly — meaning the problem was specific to Uptime Kuma → Pi-hole (container-to-host), not Pi-hole itself.
4. Switched URLs to use `host.docker.internal` (added via `--add-host=host.docker.internal:host-gateway`) instead of the real LAN IP, since container-to-host traffic behaves differently from Mac-to-host traffic.
5. Still timed out. First hypothesis: `DOCKER-USER` iptables chain didn't cover Docker's internal network (`172.17.0.0/16`) as a source. Added a rule for it — still failed.
6. Isolated the issue directly with `docker exec uptime-kuma curl -v http://172.17.0.1:8080/admin`, confirming a real, reproducible connection timeout — not a DNS or app issue.
7. **Actual root cause:** `172.17.0.1` is TITAN's own IP as seen from inside Docker's network — that traffic goes through the `INPUT` chain (UFW's territory), not `FORWARD`/`DOCKER-USER` (which only governs traffic aimed at a container). None of the existing UFW rules allowed `172.17.0.0/16` as a source — only `10.0.0.0/24`. Fixed with `sudo ufw allow from 172.17.0.0/16`. All 4 monitors came up immediately after.

**Key lesson documented:** there are two distinct places Docker-related traffic can get blocked — container-to-container/published-port (`DOCKER-USER`) and container-to-host-own-IP (`UFW`/`INPUT`) — and they're not interchangeable fixes. Also reinforced *why* the UFW rule needs no `@reboot` cron entry (UFW persists its own rules to disk and reloads at boot) while raw `iptables -I DOCKER-USER` rules do (they only live in kernel memory) — a distinction that had to be re-explained since a similar question was answered incorrectly on the first attempt.

## Portainer

Deployed with the Docker socket mounted (`/var/run/docker.sock`), giving it full control over Docker on the host — a higher privilege level than prior services. Two gotchas hit during setup:
- Tried `https://` on port 9000, which only serves plain HTTP (9443 would be HTTPS, not published) — `ERR_SSL_PROTOCOL_ERROR`.
- The initial admin-setup screen has a short timeout window, and its setup token regenerates on every `docker restart`, invalidating prior tokens (caused a 403 from using a stale one). Resolved by restarting and immediately grabbing the freshest token from `docker logs`.

## Pending

- [ ] None outstanding for this session — all 6 services healthy, monitored, and firewalled

## Overall service count

```
Pi-hole            ✅ running, monitored
Jellyfin           ✅ running, monitored
Immich (4 ctrs)    ✅ running, monitored
Samba              ✅ running, monitored
Uptime Kuma        ✅ running (monitors the above)
Portainer          ✅ running
```
