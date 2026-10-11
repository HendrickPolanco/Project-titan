# 🔥 Module 6 — Firewall and Linux Security

> Status: 🟡 UFW completed / SSH hardening pending execution
> Related certifications: Network+, Security+

---

## 1. What is a firewall?

Decides, port by port, who can get in and who can't on a device. Without a firewall, any port with a service listening (see `ss -tuln`) is potentially reachable from anywhere that can reach the server.

- **Inbound:** traffic arriving at the server
- **Outbound:** traffic leaving the server

Typical setup: strict on inbound, permissive on outbound.

---

## 2. UFW (Uncomplicated Firewall)

Simplified interface on top of `iptables`.

### ⚠️ Golden rule — avoid locking yourself out

**Always allow SSH BEFORE enabling UFW:**

```bash
sudo ufw allow 22    # 1st
sudo ufw enable       # 2nd — never the other way around
```

If you enable UFW without allowing 22 first while connected over SSH, the connection drops and you get locked out of the server (would require physical access to revert).

### Basic commands

```bash
sudo ufw status                              # check status
sudo ufw status verbose                      # status + default policies
sudo ufw status numbered                     # numbered rules (for deleting by number)
sudo ufw allow 22                            # allow a port
sudo ufw allow 22/tcp                        # allow port + specific protocol
sudo ufw deny 23                             # explicitly block a port
sudo ufw delete allow 22                     # remove a rule
sudo ufw delete 2                            # remove rule by number
```

### Restrict by source (ties into subnetting)

```bash
sudo ufw allow from 10.0.0.0/24 to any port 22
```
Allows SSH only from the local network — much safer than opening the port to the whole internet (least privilege in action).

### Default policies

```bash
sudo ufw default deny incoming     # block all inbound unless explicitly allowed
sudo ufw default allow outgoing    # allow all outbound
```

### Rule evaluation order

UFW uses the **first matching rule**, not the most specific one. Restrictive rules must come before broader rules, or the broad one "wins" first and the restrictive one never applies.

### Logging

```bash
sudo ufw logging on
sudo journalctl -u ufw       # review blocked/allowed attempts
```

### Rate limiting — brute-force protection

```bash
sudo ufw limit 22/tcp
```
Unlike `allow`, `limit` temporarily blocks an IP if it detects too many connection attempts in a short time (default: 6 attempts in 30s). Protects even against a compromised device **inside** the local network (e.g. infected IoT device, guest on the wifi) — something `allow from 10.0.0.0/24` alone doesn't cover.

**Combining both ideas:**
```bash
sudo ufw limit from 10.0.0.0/24 to any port 22
```

### Two independent layers of protection

1. **UFW on the server** — filters traffic within the local network
2. **Home router NAT/routing** — decides whether anything from the internet can even reach the private network (requires explicit port forwarding)

Disabling UFW does not by itself expose the server to the internet, if the router has no port forwarding configured.

---

## 3. Configuration applied on TITAN

```bash
sudo ufw allow from 10.0.0.0/24 to any port 22
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable
```

Verified result:
```
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)

To                         Action      From
22                         ALLOW IN    10.0.0.0/24
```

---

## 4. SSH Hardening (🔜 pending execution)

### Why, if SSH keys are already set up?

Ubuntu often leaves password login enabled as a fallback even when key-based authentication is already in use. Hardening closes that backup door.

### Procedure

**1. Backup before touching anything:**
```bash
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
```

**2. Edit:**
```bash
sudo nano /etc/ssh/sshd_config
```

Set:
```
PasswordAuthentication no      # forces key-only login
PubkeyAuthentication yes       # confirm it's enabled
PermitRootLogin no             # disable direct root login
```

**3. Restart the service:**
```bash
sudo systemctl restart sshd
```

**4. ⚠️ Safe verification — NEVER close the current session before confirming:**

With the current SSH session still open, open a **second, new terminal** and test:
```bash
ssh titan
```

If the second connection fails, the first session is still alive to fix the error and retry — no physical access needed. Only close the original session once the new connection is confirmed working.

If something goes wrong and both sessions are lost: physical access to the mini PC and `sudo cp /etc/ssh/sshd_config.backup /etc/ssh/sshd_config`.
