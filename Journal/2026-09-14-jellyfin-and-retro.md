# 📓 2026-09-14 — 10-Day Retro + Jellyfin Deployment

## What happened today

Started with a diagnostic quiz to check retention after a 10-day gap, reviewed the two weakest spots found, confirmed a pending blocklist, and deployed the second real service on TITAN (Jellyfin) — this time cleanly, with no networking issues.

## Retro quiz results (5 questions)

| # | Topic | Result |
|---|---|---|
| 1 | Subnetting — block size + Network for a non-.0 IP | Block size correct; Network wrongly defaulted to `.0` (recurring past mistake) |
| 2 | UFW `allow` vs `limit` | Right idea, needed sharper contrast |
| 3 | Why UFW rules don't control Docker container traffic | Wrong — attributed it to "container has its own UFW," not the real INPUT vs FORWARD distinction |
| 4 | Static IP vs DHCP reservation | Solid |
| 5 | Real cause of the Pi-hole-blocked-but-still-loading issue | Wrong — guessed "ad domains rotate," missed the actual Chrome Secure DNS cause entirely |

**Weakest areas identified:** the Docker/iptables INPUT-vs-FORWARD distinction (question 3) and the "assume Network is always .0" subnetting habit (question 1) — both reviewed in depth today.

## Review sessions

- **Subnetting:** worked through 3 fresh exercises (10.20.5.90/27, 172.16.8.150/26, 192.168.50.200/28), all deliberately using non-`.0` IPs. Also clarified confusing "32 total bits" with "bits of host" (`32 - CIDR`), a distinct concept.
- **Docker/iptables:** rebuilt the INPUT vs FORWARD building analogy (front desk vs internal hallway) from scratch, then confirmed understanding by reasoning through whether the existing `DOCKER-USER` rule (`-s 10.0.0.0/24`, no port specified) automatically covers a hypothetical new service on a new port — correctly reasoned yes, since the rule has no port restriction.

## Confirmed: HaGeZi NSFW list was added

Verified via the Lists panel that the NSFW blocklist (`https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/nsfw.txt`) is active, separate from the individually-blocked `pornhub.com` entry.

## Jellyfin deployed

Second Docker service on TITAN, following the same storage split as Pi-hole (config on NVMe at `/opt/titan/jellyfin`, media library on HDD at `/mnt/titan-storage/media`). No port conflicts or networking issues this time — `docker run` → `docker update --restart unless-stopped` → UFW rule → working dashboard, straight through.

## Pending

- [ ] Transfer video files to `/mnt/titan-storage/media` (via `scp`, not yet covered)
- [ ] Make `DOCKER-USER` iptables rules persistent (still pending from the Pi-hole session)
- [ ] Configure DNS on other devices besides the Mac
- [ ] Build the personal custom ad-block list from Query Log findings
