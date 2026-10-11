# 🌐 Module 11 — Network Migration Checklist (router/IP change)

> Status: ✅ Written after a real router migration (Xfinity `10.0.0.0/24` → personal Cudy router `192.168.10.0/24`)
> Purpose: everything that silently breaks when TITAN's IP or subnet changes, and in what order to fix it

---

## Why this happens

Every service deployment hardcoded the old subnet (`10.0.0.0/24`) or the old IP (`10.0.0.27`) into UFW rules, `iptables` rules, cron jobs, and client-side configs. None of that updates by itself when the router changes — every reference has to be found and corrected by hand.

---

## The checklist, in the order things actually broke

### 1. Confirm the new IP/subnet first
```bash
ip a                          # TITAN's new IP (e.g. 192.168.10.168)
ip route | grep default       # the new gateway
```

### 2. UFW rules — every one referencing the old subnet
```bash
sudo ufw status numbered
```
Delete the old rules from the **highest number to the lowest** (numbering shifts after each delete), then recreate each with the new subnet:
```bash
sudo ufw delete <N>
sudo ufw allow from 192.168.10.0/24 to any port <port>
```
Use the **network address** (`.0/24`), never a device address with a mask (`.168/24`).

### 3. `DOCKER-USER` iptables rules (traffic to containers)
```bash
sudo iptables -I DOCKER-USER -s 192.168.10.0/24 -j ACCEPT
```
The `172.17.0.0/16` (Docker-internal) rule normally doesn't change, but check it (see the note at the end).

### 4. The `@reboot` cron job — update it, don't just add to it
```bash
sudo crontab -e
```
```
@reboot sleep 15 && iptables -I DOCKER-USER -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT && iptables -I DOCKER-USER -s 192.168.10.0/24 -j ACCEPT && iptables -I DOCKER-USER -s 172.17.0.0/16 -j ACCEPT
```
(The `sleep 15` waits for Docker to create the `DOCKER-USER` chain; without it the rules were applied too early and silently lost.)

### 5. SSH config on every client (`~/.ssh/config`)
```
Host titan
    HostName 192.168.10.168    # was 10.0.0.27
    User titan_admin
    IdentityFile ~/.ssh/titan_ed25519
```

### 6. DNS set by hand on clients
macOS: System Settings → Wi-Fi → Details → DNS. macOS stores this **per Wi-Fi network**, so a setting made on the old router's network does not follow you to the new one. Internet keeps working through whatever DNS the router provides, so the symptom is not "no internet" but "ad blocking silently stopped".

### 7. Router-level DNS — and the trap of having several settings
Pointing the router at Pi-hole is **not one setting**. The Cudy router has three independent ones:
- *Custom DNS* — what the router itself uses to resolve names
- *DHCP Server → Preferred DNS* — what it gives clients over IPv4
- *IPv6 → LAN → IPv6 DNS Mode* — what it advertises over IPv6 (`WAN Connection` hands clients the ISP's DNS directly; `HGW Proxy` routes them through the router)

Setting only the first leaves clients receiving the ISP's DNS directly. Leave *Alternate DNS* **empty**: a fallback lets some devices skip Pi-hole.

**How to check what a client is really using:**
```bash
scutil --dns | head -40         # macOS only; look at the resolver bound to the Wi-Fi interface (en0)
dscacheutil -q host -a name <name>   # asks the same resolver the browser uses
```
and in Pi-hole's **Query Log**, load a name on the device: if it never shows up there, that device is not asking Pi-hole.

Other things that bypass the local DNS: Chrome's "Use secure DNS", iCloud Private Relay on iPhone.

### 8. Saved network connections on clients (Finder favorites, mapped drives)
Entries that point at the old IP don't update; remove and recreate them. A stale SMB mount (`mount | grep <name>`) can silently interfere with new attempts.

---

## Preventing it from happening again — DHCP reservation

Once the new subnet is settled, reserve TITAN's IP so it never drifts, which avoids repeating this checklist after every reboot.

**Cudy app:** Advanced Settings → Security → IP/MAC Binding → Add. Select TITAN's MAC address (or paste it) and enter the IP to reserve. Reusing the current IP avoids touching every rule again.

TITAN's MAC address (the physical identifier of the network card, unrelated to a "Mac" computer):
```bash
ip a | grep -A 1 wlo1      # look for the line starting with link/ether
```

**Verify it took effect** — don't trust that saving worked:
```bash
sudo reboot
# afterwards:
ip a | grep wlo1 -A 2      # the IP must be unchanged
```

---

## A rule that has disappeared more than once

`sudo ufw allow from 172.17.0.0/16` (needed for container → host-own-IP traffic, see the Uptime Kuma saga in `11-titan-services-samba-kuma-portainer.md`) is a UFW rule and should persist on its own. It vanished after a reboot during this migration anyway. Whenever something that worked (especially Uptime Kuma monitors) suddenly doesn't, **re-check** `sudo ufw status numbered` for it instead of assuming it is still there.

---

## Fast diagnostic sequence when "something stopped working" after a network change

1. `ip a` — did TITAN's own IP change?
2. `sudo ufw status numbered` — do the rules match the current subnet (and is `172.17.0.0/16` still there)?
3. `sudo iptables -L DOCKER-USER -n` — same check for the Docker chain
4. On the client: is it even on TITAN's subnet now?
5. `dig <name> @<titan-ip>` — does Pi-hole itself answer, independent of any client setting?
6. On the client: which DNS is it really using (`scutil --dns`), and does the name appear in Pi-hole's Query Log?
