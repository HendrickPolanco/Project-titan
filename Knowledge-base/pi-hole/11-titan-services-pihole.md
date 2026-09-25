# 🕳️ Module 11 — Deploying Pi-hole on TITAN

> Status: ✅ Deployed and working
> Related certifications: Network+, Security+ (real-world layered troubleshooting)

---

## 1. Deployment

### Directory structure decision

Config lives on the NVMe (fast, small, frequently read/written), not the HDD (reserved for bulk data like media/photos/backups):

```bash
mkdir -p /opt/titan/pihole
```

### Running the container

```bash
docker run -d --name pihole \
  -p 8080:80 \
  -p 53:53/tcp -p 53:53/udp \
  -v /opt/titan/pihole:/etc/pihole \
  -e TZ="America/New_York" \
  pihole/pihole
```

Note: when copy-pasting multi-line commands with `\` continuations into a terminal, line breaks can sometimes get mangled and corrupt the command (`docker: invalid reference format`). Safer to paste as a single line when in doubt.

### Setting the admin password after first run

```bash
docker exec -it pihole pihole setpassword
```

### Making the container survive reboots

By default, `docker run` without a restart policy means the container stays stopped if it exits (e.g. during a host reboot) — it does NOT come back on its own.

```bash
docker update --restart unless-stopped pihole
```

---

## 2. Conflict: port 53 already in use

```
docker: Error response from daemon: failed to set up container networking:
failed to bind host port 0.0.0.0:53/tcp: address already in use
```

**Cause:** Ubuntu's built-in local DNS resolver, `systemd-resolved`, listens on port 53 by default (`127.0.0.53`, `127.0.0.54`) via its "stub listener." Pi-hole needs the whole port 53 for itself.

**Fix — disable systemd-resolved's stub listener (not the whole service):**

```bash
sudo nano /etc/systemd/resolved.conf
```
Change:
```
DNSStubListener=no
```
(Must actually remove the `#` — a commented-out line has no effect even if the value looks right.)

```bash
sudo systemctl restart systemd-resolved
```

Verify:
```bash
sudo ss -tulnp | grep :53
```

---

## 3. UFW rules for the new service

Same least-privilege pattern as SSH — restrict to the local network, not the whole internet:

```bash
sudo ufw allow from 10.0.0.0/24 to any port 53
sudo ufw allow from 10.0.0.0/24 to any port 8080
```

---

## 4. The real saga: DNS queries reaching Pi-hole but timing out

Symptom: `dig google.com @10.0.0.27 +short` from the Mac always resulted in `connection timed out`, even after fixing port 53 and UFW.

### Step 1 — Verify Pi-hole itself is healthy

```bash
dig google.com @127.0.0.1 +short
```
(Must be run **on TITAN**, not the Mac — `127.0.0.1` always means "this machine," never another host.)

If this works, Pi-hole/FTL itself is fine — the problem is somewhere between the Mac and the container.

### Step 2 — Understand why UFW's normal rules don't apply here

Docker publishes ports using NAT: traffic destined for a container doesn't pass through the `INPUT` chain (traffic to the host itself) — it passes through the `FORWARD` chain (traffic the host is relaying elsewhere). UFW's rules (`ufw-user-input`) only govern `INPUT`. For container traffic, the chain that actually matters is `DOCKER-USER`, a chain Docker leaves empty specifically for the user to add rules to (Docker won't overwrite it).

```bash
sudo iptables -L FORWARD -n --line-numbers
sudo iptables -L DOCKER-USER -n --line-numbers
```

If `FORWARD`'s default policy is `DROP` and `DOCKER-USER` is empty, container traffic gets silently dropped regardless of what UFW's own tables say.

### Step 3 — Add rules directly to DOCKER-USER

```bash
sudo iptables -I DOCKER-USER -s 10.0.0.0/24 -j ACCEPT
sudo iptables -I DOCKER-USER -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
```

- The first rule allows new connections **from** the local network (the outbound leg of a query).
- The second is critical and easy to miss: DNS traffic is a two-way trip (query in, response out). The response's source is the *container's* IP (e.g. `172.17.0.2`), not `10.0.0.0/24` — so a source-only rule only covers the query, never the reply. `conntrack --ctstate ESTABLISHED,RELATED` tells the firewall "if this packet belongs to a connection I already approved, let it through automatically, regardless of source IP" — this is a **stateful firewall** concept.

⚠️ **These `-I` rules do NOT persist across a reboot** (unlike UFW's, which are saved automatically). If TITAN reboots, `DOCKER-USER` goes back to empty and this has to be redone (or made permanent with `iptables-persistent` — pending task).

### Step 4 — Confirm traffic with tcpdump instead of guessing

```bash
sudo timeout 15 tcpdump -ni any port 53 -vv
```
(Run on TITAN; trigger a `dig` from the Mac during the 15-second window.)

Seeing the query arrive (`wlo1 In` → `docker0 Out` → `veth... Out`) but **no response packet coming back** confirmed the container received the query but the reply never made it back — pointing away from the network layer and toward Pi-hole's own application logic.

### Step 5 — The actual root cause: Pi-hole's own listening mode

Buried in `docker logs pihole`:
```
WARNING: dnsmasq: ignoring query from non-local network 10.0.0.76 (logged only once)
```

Pi-hole's DNS engine (FTL) has a setting, `dns.listeningMode`, that by default (`LOCAL`) intentionally ignores queries that don't appear to come from a "local" interface — and traffic arriving through Docker's NAT looks foreign to it, even though it's coming from the actual home network. This setting used to be a simple toggle in the Pi-hole v5 web UI ("Interface listening behavior") but was **removed from the web UI entirely in Pi-hole v6** — it now has to be set via the CLI or the config file.

```bash
docker exec pihole pihole-FTL --config dns.listeningMode
# returns: LOCAL

docker exec pihole pihole-FTL --config dns.listeningMode ALL
docker restart pihole
```

After this, `dig google.com @10.0.0.27 +short` from the Mac finally worked.

### Lesson: layered troubleshooting

This is a textbook example of the OSI-style layered debugging already covered in Networking:
1. Confirmed the app itself was healthy (`@127.0.0.1`)
2. Checked network-level filtering (UFW → discovered irrelevant for Docker traffic → `FORWARD`/`DOCKER-USER`)
3. Confirmed packets with `tcpdump` instead of continuing to guess
4. Found the actual cause one layer higher: the application's own internal filtering, not the network at all

Each layer that got ruled out with real evidence narrowed the search — none of the iptables work was wasted, since it was a genuine intermediate finding (traffic was in fact reaching the container), even though the final fix lived elsewhere.

---

## 5. Router-level DNS (Xfinity limitation)

Xfinity's rented gateway (xFi) **locks the DNS Server field** at the network/DHCP level — it's visible in the app (`WiFi → LAN & WAN → DNS Server`) but shows "Primary DNS: 75.75.75.75 / Secondary: 75.75.76.76" as **read-only**, with no way to point the whole network at Pi-hole automatically.

**Workaround used: per-device manual DNS.** On the Mac: `System Settings → Wi-Fi → Details → DNS`, remove existing entries, add:
```
10.0.0.27   (Pi-hole)
1.1.1.1     (fallback if Pi-hole is down)
```

**Longer-term alternative (not done yet):** put the Xfinity gateway in Bridge Mode and use a personal router behind it, which would allow setting Pi-hole as the DHCP-distributed DNS for the whole network automatically.

---

## 6. DNS-level ad blocking — what it can and can't do

**Works well:** ads served from third-party domains distinct from the page's own content (most banner ads, ad networks like `doubleclick.net`, `googlesyndication.com`, etc.) — Pi-hole simply refuses to resolve those domains.

**Doesn't work: YouTube.** Google serves YouTube's ads from the *same* domains as the video content itself (`googlevideo.com`, `youtube.com`). Blocking those domains would break video playback entirely, not just the ads — DNS-level blocking can't distinguish content from ads *within* the same domain. A browser extension (uBlock Origin) is needed for that, since it can inspect the page itself, not just the domain being requested.

**Verifying blocking is working:** the Query Log (Pi-hole → Query Log) shows exactly what happened to every domain a device requested, and whether it was blocked or allowed — the most reliable way to confirm real behavior instead of guessing.

**Test page for ad blocking:** `https://canyoublockit.com/extreme-test/` — built specifically to test DNS-level blockers like Pi-hole, includes banners and pop-under ads from real third-party ad networks.

---

## 7. Blocklists in use

| List | URL | Purpose |
|---|---|---|
| StevenBlack (default) | (bundled) | Baseline ads + malware |
| anudeepND | `https://raw.githubusercontent.com/anudeepND/blacklist/master/adservers.txt` | Additional ad servers |
| HaGeZi Normal | `https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/multi.txt` | Balanced, low false-positive coverage |
| HaGeZi Ultimate | `https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/ultimate.txt` | Maximum blocking, higher risk of breakage |
| HaGeZi Pop-Up Ads | `https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/popupads.txt` | Specifically targets pop-up/pop-under ads |

**Not yet added, under consideration:**
- HaGeZi Threat Intelligence Feeds (TIF) — pure security (malware/phishing), not ad-related: `https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/tif.txt` (or `tif.medium.txt` for lower RAM use)
- Content-restriction lists (Gambling, NSFW, Social Networks, Anti-Piracy) — optional, personal-preference only, not added by default

**Process for adding a new list:** Pi-hole → Lists → paste URL in the "Add" field (NOT the "Find Domains In Lists" search tool, which only searches existing lists) → Tools → Update Gravity.

---

## 8. Pending / next steps

- [ ] Make the two `DOCKER-USER` iptables rules persistent across reboots (`iptables-persistent`)
- [ ] Configure DNS manually on other devices (phone, etc.) — currently only the Mac uses Pi-hole
- [ ] Build a personal custom blocklist (site-specific ad domains found via Query Log) hosted on the TITAN GitHub repo
- [ ] Consider Xfinity Bridge Mode + personal router for network-wide automatic DNS distribution
