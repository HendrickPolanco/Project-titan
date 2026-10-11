# 📓 2026-08-21 — Full Networking + Firewall (UFW)

## What was covered today

- Basic binary (decimal ↔ binary), the foundation for everything else
- Full CIDR and subnetting: host bits, block size, Network/Broadcast/first-last host, including cases where the given IP doesn't fall exactly on a multiple
- Decimal subnet mask, in any octet (not just the fourth)
- Private vs public IP (corrected an initial misconception with streaming geo-restriction)
- DHCP: DORA process, pool, static IP vs DHCP reservation (TITAN uses reservation)
- DNS: resolution process, record types, the difference between a DNS block (Pi-hole) and a 404 error, hands-on practice with `dig`/`nslookup` on TITAN
- Gateway and routing: reading `ip route`, `scope link` vs `default`, `metric`
- Ports, TCP vs UDP, `ss -tuln`
- Network troubleshooting: logical diagnostic sequence
- Firewall (UFW): default policies, rule order, logging, rate limiting (`limit`), layers of protection (firewall vs router NAT)
- SSH hardening: full procedure explained (execution still pending)

## Applied live on TITAN

```bash
# Network verification
ip a
ip route
dig google.com +short
dig google.com @10.0.0.1

# Firewall configured and active
sudo ufw allow from 10.0.0.0/24 to any port 22
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable
```

TITAN ended up with IP `10.0.0.27/24` (DHCP reservation), gateway `10.0.0.1`, and UFW active, allowing SSH only from the local network.

## Common mistakes identified and corrected (worth remembering)

1. Treating "first 3 octets = network" as a universal rule (only applies to /8, /16, /24)
2. Calculating block size as `2^(bits-1)` instead of `2^bits`
3. Assuming the Network always ends in `.0`
4. When finding the block, using the upper multiple instead of subtracting 1 for the Broadcast
5. Confusing "block size" (a single number) with "a multiple from the list" (a full address)
6. Private/public IP confused with content geo-restriction

## Pending for next session

- [ ] Execute SSH hardening (`sshd_config`) when there's time to do it calmly
- [ ] Module 7 — Linux Storage (partitions, filesystems, mount/fstab, RAID, backups)
- [ ] Module 8 — Automation (bash scripting, cron)

## Overall progress

```
Linux fundamentals       ██████████ 100%
Networking                ██████████ 100%
Firewall/Linux Security   ████████░░  80%
Storage                   █░░░░░░░░░  10%
Automation                 ░░░░░░░░░░   0%
Docker/Virtualization      ░░░░░░░░░░   0%
```
