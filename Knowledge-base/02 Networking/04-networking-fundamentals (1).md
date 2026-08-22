# 🌐 Module 4-5 — Networking Fundamentals

> Status: ✅ Completed
> Related certifications: Network+

---

## 1. Basic Binary

Each octet of an IPv4 address is 8 bits, with position values:

```
128  64  32  16  8  4  2  1
```

Sum of all: `128+64+32+16+8+4+2+1 = 255` → maximum value of an octet.

**Method to convert decimal → binary:** go through the positions left to right, asking "does it fit?", subtracting when it does.

Example — `192`:
```
128  64  32  16  8  4  2  1
 1    1   0   0  0  0  0  0
```

**Key rule:** with `n` bits, possible values range from `0` to `2ⁿ - 1`, and the total count of distinct values is `2ⁿ` (counting starts at 0, not 1).

---

## 2. CIDR and Subnetting

**CIDR** (Classless Inter-Domain Routing) is the `/N` notation that indicates how many of the 32 total bits of an IPv4 address are "network" bits (fixed). The rest are "host" bits (variable).

Before CIDR, networks were divided into fixed classes (A/B/C) with rigid sizes, wasting addresses. CIDR allows cutting the network to the exact size needed — and that cut can fall **inside** an octet, not just on octet boundaries (that's why `/24` = "first 3 octets" works, but `/26`, `/27`, etc. don't).

### The complete procedure (8 steps)

Given an address `IP/CIDR`:

1. **Host bits:** `32 - CIDR`
2. **Block size:** `2^(host bits)`
3. **Multiples of the block size**, counting from 0: `0, size, 2×size, 3×size...` until you pass the given number (or reach 256, the octet limit)
4. **Locate the block:** find the multiple equal to or less than the given number (round down)
5. **Network** = the multiple found (start of the block)
6. **Broadcast** = (start of the next block) - 1
7. **First host** = Network + 1
8. **Last host** = Broadcast - 1

### Worked example — `192.168.5.64/28`

| Step | Calculation | Result |
|---|---|---|
| Host bits | `32-28` | 4 |
| Block size | `2⁴` | 16 |
| Multiples of 16 | `0,16,32,48,64,80...` | 64 is exact |
| Network | — | `192.168.5.64` |
| Broadcast | `80-1` | `192.168.5.79` |
| First host | `64+1` | `192.168.5.65` |
| Last host | `79-1` | `192.168.5.78` |

**Special case — a number that does NOT fall exactly on the list of multiples:**
E.g. `192.168.4.100/26` (block of 64: `0, 64, 128...`). `100` falls between `64` and `128` → round down → Network = `192.168.4.64` (not `.100`).

---

## 3. Subnet Mask (decimal)

Same information as the CIDR, written as a 4-octet IP. Each network bit = `1`, each host bit = `0`, converted to decimal per octet.

**Quick formula per octet:**
```
256 - block size = mask octet
```

**Locate which octet the cut falls in:**
- Octet 1: bits 1-8
- Octet 2: bits 9-16
- Octet 3: bits 17-24
- Octet 4: bits 25-32

### Reference table (CIDR → mask)

| CIDR | Mask | CIDR | Mask |
|---|---|---|---|
| /8 | 255.0.0.0 | /21 | 255.255.248.0 |
| /12 | 255.240.0.0 | /22 | 255.255.252.0 |
| /13 | 255.248.0.0 | /23 | 255.255.254.0 |
| /16 | 255.255.0.0 | /24 | 255.255.255.0 |
| /18 | 255.255.192.0 | /25 | 255.255.255.128 |
| /19 | 255.255.224.0 | /26 | 255.255.255.192 |
| /20 | 255.255.240.0 | /27 | 255.255.255.224 |
| | | /28 | 255.255.255.240 |
| | | /29 | 255.255.255.248 |
| | | /30 | 255.255.255.252 |

---

## 4. Private vs Public IP

- **Private IP** — only valid inside a LAN, not routable on the internet. Ranges: `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`.
- **Public IP** — assigned by the ISP to the router, visible from the internet.

A device outside your network (e.g. a neighbor from their own house) **cannot reach** a private IP like `10.0.0.27` directly, regardless of the server's firewall — it would need **port forwarding** configured on the router (NAT). Two independent layers of protection: host firewall + router NAT/routing.

---

## 5. DHCP (Dynamic Host Configuration Protocol)

Service that automatically assigns IPs, without manual configuration.

### DORA process

1. **Discover** — the device asks if there's a DHCP server around
2. **Offer** — the server offers an IP
3. **Request** — the device accepts it
4. **Acknowledge** — the server confirms, with a time limit (*lease*)

### Key concepts

- **DHCP pool** — range of IPs the server can hand out (e.g. `.20` to `.200`, leaving the rest free for manual assignment)
- **Lease** — the IP is a loan with a time limit, automatically renewed while the device stays connected

### Static IP vs DHCP Reservation

For servers (like TITAN), a fixed IP is preferred, so that services/configurations depending on that IP don't break if the lease isn't renewed identically.

| Option | How it works | Advantage |
|---|---|---|
| Static IP | Configured directly on the device (Netplan on Ubuntu) | Doesn't depend on the router |
| DHCP Reservation | Router always gives the same IP to that MAC address, device still "speaks" DHCP | More flexible if it changes networks |

**TITAN uses: DHCP Reservation** → `10.0.0.27`

---

## 6. DNS (Domain Name System)

Translates names (`google.com`) into IPs (`142.250.80.46`). Without DNS, we'd have to memorize IPs.

### Process

1. The device asks a **DNS resolver** (can be local — `systemd-resolved` on Ubuntu — or the router's/ISP's)
2. The resolver responds with the IP (from cache, or by asking other DNS servers in a chain)
3. The browser/app connects directly to that IP

### Record types

| Type | Function |
|---|---|
| A | Name → IPv4 |
| AAAA | Name → IPv6 |
| CNAME | Alias: name → another name |
| MX | Where to send the domain's email |
| NS | Which servers are authoritative for the domain |
| TXT | Free text (verification, SPF/DKIM) |

### Practical commands

```bash
dig google.com +short              # just the IP
dig google.com                     # full detail
dig google.com @10.0.0.1           # ask a specific DNS server
nslookup google.com                # older alternative
```

**Pi-hole and DNS:** Pi-hole intercepts DNS queries and responds with no real IP (`0.0.0.0`) for domains on its blocklist. This happens **before** any connection is made — that's why the result is a DNS resolution error (`DNS_PROBE_FINISHED_NXDOMAIN`), not a 404 (a 404 requires a successful connection to a server first).

**GeoDNS:** large companies (Google) return different IPs depending on which resolver you ask — each resolver directs you to the server closest/most optimal for you.

---

## 7. Gateway and Routing

### How Linux decides where to send a packet

1. Is the destination in my local network? (`scope link` in the routing table) → deliver directly, no gateway needed
2. If not → use the `default` route (the gateway)

### Reading `ip route`

```
10.0.0.0/24 dev wlo1 proto kernel scope link src 10.0.0.27 metric 600
default via 10.0.0.1 dev wlo1 proto dhcp src 10.0.0.27 metric 600
```

- `scope link` = local network, no gateway needed
- `default via X` = gateway for everything else
- `metric` = priority when there are duplicate routes — **the lowest metric wins**

---

## 8. Ports, TCP and UDP

**Port** = identifies which specific service (within a device) traffic is directed to. `IP:port` (e.g. `10.0.0.27:22`).

### Well-known ports

| Port | Service |
|---|---|
| 22 | SSH |
| 53 | DNS |
| 80 | HTTP |
| 443 | HTTPS |

### TCP vs UDP

| | TCP | UDP |
|---|---|---|
| Connection | Establishes a connection (3-way handshake) | No prior connection |
| Guarantee | Guarantees complete, in-order delivery | No guarantee at all |
| Speed | Slower (verification overhead) | Faster |
| Typical use | SSH, web, file transfer | Live streaming, video calls, DNS |

### Checking what's listening

```bash
ss -tuln
# -t TCP, -u UDP, -l listening only, -n show port numbers
```

---

## 9. Network Troubleshooting — logical sequence

From the most basic to the most specific:

1. `ip a` → do I have an IP assigned?
2. `ping 10.0.0.1` (gateway) → can I reach my local network/router?
3. `ping 8.8.8.8` → do I have internet connectivity by IP?
4. `dig google.com` / `ping google.com` → does name resolution work?
5. `curl -I http://site.com` / `ss -tuln` → does the specific service respond?

`traceroute` shows each hop (router) the packet passes through — useful to pinpoint where the connection drops.
