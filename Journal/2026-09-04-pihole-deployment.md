# 📓 2026-09-04 — First Real Service on TITAN: Pi-hole

## What happened today

Deployed the first real Docker service on TITAN — Pi-hole — closing out Module 10 (Docker) with an actual applied case, and getting a real, multi-layer troubleshooting session in the process.

## Timeline

1. Installed Docker (`apt install docker.io`), enabled it, added user to the `docker` group
2. Organized storage decision: service configs go on the NVMe (`/opt/titan/`), bulk data stays on the HDD (`/mnt/titan-storage/`)
3. First `docker run` attempt failed — port 53 already in use by `systemd-resolved`'s stub listener. Fixed by setting `DNSStubListener=no` in `/etc/systemd/resolved.conf` (first attempt failed silently because the `#` comment marker wasn't actually removed)
4. Container ran successfully, set admin password via `docker exec pihole pihole setpassword`
5. Opened the dashboard — confirmed running, but DNS queries from the Mac weren't reaching it (kept falling back to secondary DNS)
6. Found UFW had no rule for port 53/8080 yet — added them
7. Still timing out — extended troubleshooting session:
   - Confirmed Pi-hole itself was healthy (`dig @127.0.0.1` from TITAN worked)
   - Discovered Docker's container traffic bypasses UFW's `INPUT` rules entirely, going through `FORWARD` → `DOCKER-USER` instead
   - Added `iptables` rules directly to `DOCKER-USER` (source rule + a `conntrack ESTABLISHED,RELATED` rule for return traffic)
   - Still timing out — turned out the container had actually been stopped for ~44 hours (from TITAN's earlier reboot during the HDD emergency-mode incident) and never had a restart policy set
   - Restarted the container, added `--restart unless-stopped`
   - Still timing out — used `tcpdump` to confirm queries were reaching the container but never getting a response
   - Root cause: Pi-hole's own `dns.listeningMode` was set to `LOCAL` by default, causing it to silently ignore queries arriving through Docker's NAT (this option existed as a simple toggle in Pi-hole v5's web UI but was removed from v6's UI, now CLI-only)
   - Fixed with `docker exec pihole pihole-FTL --config dns.listeningMode ALL` + restart
8. Confirmed working end-to-end from the Mac
9. Discovered Xfinity's rented gateway locks the DNS field (can view but not edit `75.75.75.75` / `75.75.76.76`) — worked around by manually setting DNS on the Mac (`10.0.0.27` primary, `1.1.1.1` fallback) instead of network-wide
10. Tested ad blocking — works well on normal ad-heavy sites, does NOT block YouTube ads (same domain as content, DNS can't distinguish)
11. Added additional blocklists: HaGeZi Normal, then Ultimate + Pop-Up Ads for a more aggressive test against `canyoublockit.com/extreme-test/`
12. Started planning a personal custom blocklist for site-specific ad domains, hosted on the GitHub repo — paused mid-way to continue later

## Key lesson of the day

A calm, layered troubleshooting process (app health → network/firewall → packet capture → application config) found the real root cause even though it lived in a place (Pi-hole's own internal setting) that had nothing to do with the two hours spent on `iptables`. That `iptables` work wasn't wasted — it correctly ruled out the network layer as the cause, which is exactly what layered troubleshooting is for.

## Pending

- [ ] Make `DOCKER-USER` iptables rules persistent (`iptables-persistent`) — they don't survive reboots
- [ ] Configure DNS on other devices (phone) to also use Pi-hole
- [ ] Build the personal custom ad-block list from Query Log findings
- [ ] Consider Xfinity Bridge Mode + personal router for automatic network-wide DNS

## Overall progress

```
Linux fundamentals       ██████████ 100%
SSH                       ██████████ 100%
Networking                ██████████ 100%
Firewall/Linux Security   ██████████ 100%
Storage                   ████████░░  80%
Automation                ██████████ 100%
Advanced Security         ██████████ 100%
Docker/Virtualization     ██████████ 100%
Real deployment (Mod. 11) ███░░░░░░░  30%  ← Pi-hole live, more services to come
```
