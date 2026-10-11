# 🧭 Module 11 — Nginx Proxy Manager, Homepage, and local DNS names

> Status: Homepage ✅ working. Nginx Proxy Manager ✅ installed and proven to work (from TITAN). **Friendly names (`jellyfin.titan.home.arpa`) are NOT working from other devices yet** — root cause identified but the router-side fix is deliberately postponed.

---

## 1. Nginx Proxy Manager (NPM)

### What it is
A **reverse proxy** with a web UI. Analogy: a receptionist at the building's single front door. Every visitor arrives at the same place (ports 80/443), she reads *which name they asked for* and sends them to the right office. The browser asks for `jellyfin.<something>`, NPM forwards it to `192.168.10.168:8096`.

Honest assessment: it is **convenience, not necessity**. Everything works by IP and port without it. It is also the usual prerequisite for HTTPS and for apps that insist on it.

### Deployment
```bash
sudo ss -tulnp | grep -E ':(80|81|443) '      # BEFORE starting: ports must be free
sudo mkdir -p /opt/titan/npm/data /opt/titan/npm/letsencrypt
sudo chown -R titan_admin:titan_admin /opt/titan/npm
docker run -d --name npm --restart unless-stopped -p 80:80 -p 81:81 -p 443:443 -v /opt/titan/npm/data:/data -v /opt/titan/npm/letsencrypt:/etc/letsencrypt jc21/nginx-proxy-manager:latest
sudo ufw allow from 192.168.10.0/24 to any port 80
sudo ufw allow from 192.168.10.0/24 to any port 81
sudo ufw allow from 192.168.10.0/24 to any port 443
```
- `ss` = *socket statistics*: `-t` TCP, `-u` UDP, `-l` listening only, `-n` numeric ports, `-p` show the program. Run **after** starting NPM it shows `docker-proxy` on all three ports, which is the confirmation that NPM is up.
- Port **81** is NPM's admin panel (`http://192.168.10.168:81`). Port 80 is free because Pi-hole's panel is on 8080.
- `/data` = NPM's configuration and database; `/etc/letsencrypt` = certificates it obtains later.
- First login per the project's docs: `admin@example.com` / `changeme`, forced to change on first use. Defaults change between versions (FileBrowser's did), so check `docker logs npm` if it fails. Use a 12+ character password from the password manager.

### Creating a proxy host (Hosts → Proxy Hosts → Add)
| Field | Value |
|---|---|
| Domain Names | `jellyfin.titan.home.arpa` — **press Enter** so it becomes a tag, otherwise the form says "This is required" |
| Scheme | `http` (how NPM talks to Jellyfin *internally*, not how you reach NPM) |
| Forward Hostname / IP | `192.168.10.168` — **the LAN IP, not the Tailscale one** (`100.x`), which only works while Tailscale is up |
| Forward Port | `8096` |
| Cache Assets | off (it caches static files; it only causes trouble with streaming) |
| Block Common Exploits | on |
| Websockets Support | on (Jellyfin needs it) |

**Custom Locations tab:** this is for routing different **URL paths** of the *same* name to different backends (e.g. `/api` → one place). It does **not** create names and does not fix DNS. Adding a location called `titan` was a mistake; delete it.

### Proving the proxy works, independent of DNS
`curl` can send the name by hand in the `Host` header, which is exactly what NPM reads to decide where to send the request:
```bash
curl -sI -H "Host: jellyfin.titan.home.arpa" http://192.168.10.168 | head -5
```
Result obtained: `HTTP/1.1 302 Found`, `Server: openresty`, `Location: web/`. `openresty` is NPM's engine, and `302 → web/` is Jellyfin's own redirect, so the request traveled browser-side → NPM → Jellyfin correctly.

| Response | Meaning |
|---|---|
| `302` + `Location: web/` | NPM and Jellyfin work; the problem is in the client |
| `404` | NPM has no proxy host with that exact name (typo in Domain Names) |
| `502` / `504` | NPM found the host but cannot reach the backend (check IP/port) |

Method: **test one link of the chain at a time** (name → Pi-hole → NPM → service), instead of changing things and retrying.

---

## 2. Pi-hole local DNS records

Pi-hole v6 keeps local records in the `dns.hosts` setting, in the same format as `/etc/hosts` (`IP name`).

```bash
docker exec pihole pihole-FTL --config dns.hosts                  # show current list ([] = empty)
docker exec pihole pihole-FTL --config dns.hosts '["192.168.10.168 jellyfin.titan.home.arpa", "192.168.10.168 immich.titan.home.arpa"]'
dig jellyfin.titan.home.arpa @192.168.10.168 +short               # must print 192.168.10.168
```
- **The set command replaces the whole list**, it does not append. Always include every name each time.
- The outer single quotes stop the shell from eating the inner double quotes.
- The list was empty (`[]`) at first, which is why `dig` printed nothing: the record had never been created. NPM and the name format were fine.
- `dig +short` hides the diagnosis. Without it, the header `status: NXDOMAIN` means "this server doesn't know the name".

### Naming convention
DNS names are read **right to left, general → specific**: `jellyfin . titan . home.arpa`. Put what changes between services on the **left** and what repeats on the **right**:
- one wildcard can cover every service (`*.titan.home.arpa`)
- a branch can be delegated (e.g. a future second node gets its own `*.lab.home.arpa`)
- a client can be given a search domain so the short name `jellyfin` completes automatically

The reversed order (`titan.jellyfin.home.arpa`) works, but each service ends differently, so none of that applies.

Suffix choices: `.home.arpa` is the one reserved for home networks (RFC 8375); `.internal` is also reserved for private use; **avoid `.local`** (reserved for Apple's Bonjour/mDNS, causes odd failures) and any real TLD you don't own. Private suffixes cannot get a publicly trusted HTTPS certificate (Let's Encrypt only issues for domains you own).

Pi-hole's record list takes no wildcards. A wildcard is a dnsmasq line (Settings → All settings → `misc.dnsmasq_lines`): `address=/titan.home.arpa/192.168.10.168`.

---

## 3. Why the names do not work from other devices (open item)

Names resolve from TITAN but not from the Mac, iPhone, or Windows PC.

**Evidence (macOS):**
```bash
scutil --dns | head -40
```
The resolver attached to the Wi-Fi interface (`en0`) listed the ISP's DNS (`75.75.75.75`, `75.75.76.76`, and IPv6 `2001:558:feed::1`), **not Pi-hole**. `scutil` is macOS-only (on Linux it doesn't exist; a mistyped near-match `secutil` pulled in the whole Mono framework, which was then removed). Tailscale's resolvers (`100.100.100.100`) were marked `Supplemental` and tied to the `*.ts.net` domain, so they were not the cause.

**Likely cause:** the Cudy router hands out its DNS through **three independent settings**, and setting one does not change the others:
- *Custom DNS* — what the router itself uses to resolve
- *DHCP Server → Preferred DNS* — what it gives clients over IPv4
- *IPv6 → LAN → IPv6 DNS Mode* — what it advertises over IPv6 (`WAN Connection` passes the ISP's DNS straight to clients; `HGW Proxy` routes it through the router)

If only the first points at Pi-hole, devices still receive the ISP's DNS directly. Also: macOS stores manual DNS **per Wi-Fi network**, so a setting made on the old router's network does not carry over.

**How to confirm without guessing:** open Pi-hole's **Query Log**, load the name on the device, and look for it. If it never appears, that device is not asking Pi-hole.

**Test that bypasses DNS on one machine:** `echo "192.168.10.168 jellyfin.titan.home.arpa" | sudo tee -a /etc/hosts` (the hosts file is consulted before any DNS server). Remove afterwards with `sudo sed -i '' '/jellyfin.titan.home.arpa/d' /etc/hosts`.

**Other things that bypass the local DNS:** Chrome's "Use secure DNS", and iCloud Private Relay on iPhone.

**Planned fix (postponed):** Cudy app → Advanced Settings → Network → DHCP Server: Preferred DNS `192.168.10.168`, Alternate empty (a fallback lets some devices skip Pi-hole); IPv6 → LAN → IPv6 DNS Mode `HGW Proxy`. Trade-off to remember: once the router hands out Pi-hole to everyone, **TITAN being off means nobody on the network can resolve names.**

---

## 4. Homepage — dashboard

### What it is
One page with a button per service. Works by IP and port, so it does not depend on DNS or NPM.

### Deployment
```bash
sudo mkdir -p /opt/titan/homepage/config
sudo chown -R titan_admin:titan_admin /opt/titan/homepage
docker run -d --name homepage --restart unless-stopped -p 3000:3000 -e HOMEPAGE_ALLOWED_HOSTS=192.168.10.168:3000,100.80.250.36:3000 -v /opt/titan/homepage/config:/app/config ghcr.io/gethomepage/homepage:latest
sudo ufw allow from 192.168.10.0/24 to any port 3000
```
- **`HOMEPAGE_ALLOWED_HOSTS` is mandatory** since v1.0: the list of `host:port` values it accepts (comma-separated, no spaces, port included). Missing entries produce a blank page and `Host validation failed` in `docker logs homepage`.
- An environment variable only changes by **recreating** the container (`docker rm -f homepage`, then `docker run` again). `docker restart` does not re-read it. The config survives because it lives in `/opt/titan/homepage/config`.
- The Docker socket is intentionally **not** mounted (it would give a second service full control of Docker; Portainer already has that).
- Network typo to avoid: `192.168.10.168/24` mixes a device address with a mask; the network address is `192.168.10.0/24`.
- Files the container creates are owned by `root`, hence `sudo nano` to edit them.

### `services.yaml`
```yaml
- Photos and Media:
    - Immich:
        href: http://192.168.10.168:2283
        description: Photos
    - Jellyfin:
        href: http://192.168.10.168:8096
        description: Videos
```
YAML is whitespace-sensitive: **indentation means nesting** and `-` starts a list item. One space off breaks the file. Homepage reloads config changes on its own.

Later widgets (live stats from Pi-hole, Jellyfin, etc.) need API keys: keep those out of the repo, the same lesson as the leaked `.env`.

---

## 5. Pending
- [ ] Router DNS fix (section 3) and confirmation through the Pi-hole Query Log
- [ ] Remove the mistaken Custom Location from the NPM proxy host and point Forward IP to the LAN address
- [ ] Add a record per service once names work
