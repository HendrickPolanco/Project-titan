# 📓 2026-09-24 — Router Migration Fallout + Samba → FileBrowser

## What happened today

Moved TITAN (physically, to relocate something) and connected it to a new personal router instead of the old Xfinity gateway. This changed TITAN's subnet from `10.0.0.0/24` to `192.168.10.0/24`, which broke nearly everything that had the old subnet/IP hardcoded — a full afternoon of real, layered troubleshooting.

## What broke, in the order discovered

1. **Immich** — `immich_server` stuck restart-looping after power-on. Turned out to be a cold-boot timing issue with Postgres; it self-stabilized after a few cycles. Confirmed healthy via `docker compose ps`.
2. **SSH from the Mac** — `~/.ssh/config` still pointed at `10.0.0.27` ("Network is unreachable"). Updated `HostName` to the new IP.
3. **All UFW rules** — every single rule (22, 53, 8080, 8096, 2283, 139, 445, 3001, 9000) still said `10.0.0.0/24` as source. Deleted all nine (highest rule number to lowest, to avoid renumbering confusion) and recreated with `192.168.10.0/24`.
4. **`DOCKER-USER` iptables rule** — same fix, added `-s 192.168.10.0/24`, and updated the `@reboot` cron line to match.
5. **Samba access from Mac and Windows** — extended troubleshooting (see below), eventually abandoned in favor of FileBrowser.
6. **Uptime Kuma showing 3/4 down** — traced to the `172.17.0.0/16` UFW rule (needed for container-to-host-own-IP traffic, from the earlier Pi-hole/Kuma saga) having disappeared — re-added it. This is the second time this specific rule has gone missing; noted as something to specifically re-check after any reboot going forward.
7. **Pi-hole no longer blocking anything** — root cause not fully pinned down in conversation (user resolved it independently), but the two live suspects were: the new router's DNS field still pointing at the old `10.0.0.27`, or the Mac's manual DNS setting not yet updated to the new IP. Confirmed fixed via `dig pornhub.com` returning `0.0.0.0` from `192.168.10.168`.

## Samba → FileBrowser

Samba was verified correct at every layer server-side (UFW, DOCKER-USER, Samba's own user database via `pdbedit -L`, and `smbutil view` from the Mac successfully listing shares) but the Finder kept failing with generic permission errors — traced partly to a stale leftover mount (`/Volumes/titan`) from an earlier successful connection silently conflicting with new attempts. Decided it wasn't worth continuing to fight SMB client behavior across Mac/Windows and replaced it with **FileBrowser**, a web-based file manager (`filebrowser/filebrowser`) — no client-side protocol involved, works identically from any browser.

FileBrowser then hit its own permission wall (403 on file read/write) because the container's internal UID didn't match the host folder's owner. Fixed properly with a shared Linux group (`titan-share`) instead of a blanket `chmod 777`:
```bash
sudo groupadd titan-share
sudo chown -R titan_admin:titan-share /mnt/titan-storage
sudo chmod -R 775 /mnt/titan-storage
sudo chmod -R g+s /mnt/titan-storage
docker run ... --group-add <GID of titan-share> ...
```
This pattern is now reusable for any future service needing write access to shared storage.

Samba container was fully removed (`docker stop` + `docker rm`) once FileBrowser was confirmed working — no data was lost, since Samba used a direct bind mount rather than its own storage.

## Key lesson of the day

A router/IP change touches far more than the obvious things (server IP) — it silently breaks client SSH configs, every firewall rule referencing the old subnet, cron jobs, and any manually-set client DNS. Wrote up a full checklist (`12-network-migration-checklist.md`) specifically so this doesn't have to be re-diagnosed from scratch next time.

## Pending

- [ ] Consider a DHCP reservation on the new router for TITAN, so the IP doesn't drift again on its own
- [ ] Keep an eye on FileBrowser's archived/unmaintained status long-term

## Overall service count

```
Pi-hole            ✅ running, blocking confirmed again
Jellyfin           ✅ running
Immich (4 ctrs)    ✅ running, healthy
FileBrowser        ✅ running (replaced Samba)
Uptime Kuma        ✅ running, all 4 monitors up
Portainer          ✅ running
```
