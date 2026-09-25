# 🌐 Module 11 — Network Migration Checklist (router/IP change)

> Status: ✅ Written after living through a real router migration (Xfinity `10.0.0.0/24` → personal router `192.168.10.0/24`)
> Purpose: everything that silently breaks when TITAN's IP or subnet changes, and in what order to fix it

---

## Why this happens

Every service deployment so far hardcoded the old subnet (`10.0.0.0/24`) or the old IP (`10.0.0.27`) into UFW rules, `iptables` rules, cron jobs, and client-side configs. None of that updates itself when the router changes — every single reference has to be found and corrected by hand.

---

## The checklist, in the order things actually broke today

### 1. Confirm the new IP/subnet first
```bash
ip a                          # confirm TITAN's new IP (e.g. 192.168.10.168)
ip route | grep default       # confirm the new gateway
```

### 2. UFW rules — every single one referencing the old subnet
```bash
sudo ufw status numbered
```
Delete old rules from **highest number to lowest** (so numbering doesn't shift under you mid-edit), then recreate each with the new subnet:
```bash
sudo ufw delete <N>            # repeat top-down
sudo ufw allow from 192.168.10.0/24 to any port <port>   # repeat per service
```

### 3. `DOCKER-USER` iptables rules (container ↔ host traffic)
```bash
sudo iptables -I DOCKER-USER -s 192.168.10.0/24 -j ACCEPT
```
The `172.17.0.0/16` (Docker-internal) rule usually doesn't need to change — that network is independent of the LAN subnet. But it's worth double-checking it's still there (see #7 below — it's easy to lose separately).

### 4. The `@reboot` cron job — update it to match, don't just add to it
```bash
sudo crontab -e
```
```
@reboot sleep 15 && iptables -I DOCKER-USER -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT && iptables -I DOCKER-USER -s 192.168.10.0/24 -j ACCEPT && iptables -I DOCKER-USER -s 172.17.0.0/16 -j ACCEPT
```

### 5. SSH config on every client device (`~/.ssh/config`)
```
Host titan
    HostName 192.168.10.168    # was 10.0.0.27
    User titan_admin
    IdentityFile ~/.ssh/titan_ed25519
```

### 6. DNS settings on every client device that was manually pointed at Pi-hole
On the Mac: System Settings → Wi-Fi → Details → DNS → update the primary entry from the old IP to the new one. **This is easy to forget** because internet still "works" via the fallback secondary DNS (e.g. `1.1.1.1`) — the symptom isn't "no internet," it's "ad blocking silently stopped working," which can go unnoticed for a while.

### 7. Router-level DNS (if the new router allows setting it, unlike Xfinity's locked gateway)
Point the router's DNS server field at TITAN's **new** IP, not the old one. If it was configured before the migration with the old IP, it's now pointing at nothing — the router silently falls back to its own default DNS.

### 8. Any bookmarked/saved network connections on clients (Finder favorites, mapped drives, etc.)
Old ones pointing at the previous IP won't auto-update and can cause confusing stale-connection errors — remove and recreate them rather than editing in place.

---

## A rule that got lost twice — worth extra attention after any reboot

`sudo ufw allow from 172.17.0.0/16` (needed for container-to-host-own-IP traffic — see the Uptime Kuma troubleshooting saga in `11-titan-services-samba-kuma-portainer.md`) is a **UFW** rule, so it should persist across reboots on its own. In practice it disappeared after a reboot during this migration anyway — worth treating as a rule to explicitly re-verify (`sudo ufw status numbered`, look for `172.17.0.0/16`) any time something that was working (especially Uptime Kuma monitors) suddenly isn't, rather than assuming it's still there.

---

## Fast diagnostic sequence when "something stopped working" after a network change

1. `ip a` — did TITAN's own IP change?
2. `sudo ufw status numbered` — do the rules match the current subnet?
3. `sudo iptables -L DOCKER-USER -n` — same check for the Docker-specific chain
4. On the client: is it even on the same network/subnet as TITAN now?
5. `dig <blocked-domain> @<titan-ip> +short` — confirm Pi-hole itself is resolving correctly, independent of any client DNS cache/config issue
