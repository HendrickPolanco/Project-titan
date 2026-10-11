# 🔐 Module 11 — Tailscale (secure remote access to TITAN)

> Status: ✅ Installed, devices connected (TITAN, phone, Mac)
> Goal: reach TITAN's services (Immich, Jellyfin, SSH, etc.) from outside the house without opening any ports on the router

---

## 1. What Tailscale is

A **mesh VPN** built on WireGuard. It creates a private virtual network between your own authenticated devices, so they behave as if they were on the same LAN regardless of where they physically are (home Wi-Fi, mobile data, a café). No port forwarding on the router, so nothing new is exposed to the public internet.

Key mental model: **Tailscale is a network, not a service.** It adds one extra virtual network interface to TITAN (`tailscale0`, similar in spirit to `docker0`) with a second IP (`100.x.x.x`). Every service already running (SSH, Immich, Jellyfin...) is the *same* service — it just becomes reachable through one more network path.

---

## 2. Installation on TITAN

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

- `curl -fsSL <url> | sh` — downloads the official install script and pipes it straight into the shell to execute it (the vendor's recommended method; worth reading the script first if being cautious about piping unknown scripts into a shell).
- `sudo tailscale up` — prints a one-time authentication link; open it in a browser and log in with a Tailscale account (Google/GitHub/Microsoft) to authorize the device.

Install the Tailscale app on the phone and Mac, log in with the **same account** — they join the same private network automatically.

### Useful commands
```bash
tailscale status        # list connected devices and their 100.x.x.x IPs
tailscale ip -4         # TITAN's own Tailscale IPv4 address
```

**Which IP do you connect to?** TITAN's Tailscale IP (the server's), never the client's — same logic as always: you address the machine running the service.

---

## 3. Firewall (UFW)

Tailscale traffic arrives on its own interface, which the existing LAN-based rules (`192.168.10.0/24`) don't cover. Allowing the interface itself is the clean way, since Tailscale already restricts that network to your own authenticated devices:

```bash
sudo ufw allow in on tailscale0
```

A rule with no port specified covers every service (including SSH on 22) — same reasoning as the portless `DOCKER-USER` rule.

---

## 4. SSH over Tailscale

Same `sshd`, same authorized keys, same `PasswordAuthentication no` hardening — only the network path (and therefore the IP) changes.

### Gotcha: typing the IP directly doesn't pick the right key

The `Host titan` alias in `~/.ssh/config` tells SSH which key to use. Connecting with `ssh titan_admin@100.x.x.x` bypasses that alias, so SSH tries default keys and fails with `Permission denied (publickey)`. Fix with an explicit key (`ssh -i ~/.ssh/<key> ...`) or, better, a second alias:

```
Host titan
    HostName 192.168.10.168
    User titan_admin
    IdentityFile ~/.ssh/titan_ed25519

Host titan-remote
    HostName 100.x.x.x
    User titan_admin
    IdentityFile ~/.ssh/titan_remote_ed25519
```

Then `ssh titan` on the home LAN and `ssh titan-remote` from anywhere.

---

## 5. Adding a separate key for remote access

A dedicated key for remote access limits the blast radius: if it's ever compromised, the local key isn't affected, and either can be revoked independently.

```bash
ssh-keygen -t ed25519 -f ~/.ssh/titan_remote_ed25519      # creates a NEW pair; the existing key is untouched
```
- private key stays on the client; **only the `.pub` file ever gets copied to the server**.

### Authorizing the new public key on the server — the hardened-server catch

`ssh-copy-id` normally logs in with a password to install the key. With `PasswordAuthentication no`, that first login is impossible, so `ssh-copy-id` fails with `Permission denied (publickey)`. You must authenticate with a key that is **already authorized** to add the new one:

```bash
# from the Mac, using the existing, already-working alias:
ssh titan
nano ~/.ssh/authorized_keys     # paste the new public key on its own line, save
cat ~/.ssh/authorized_keys      # verify: one key per line, none cut off
```

Appending to `authorized_keys` adds a key without removing the ones already there.

### Mistakes made along the way (worth remembering)

1. **Running a command inside the wrong machine.** Several commands failed because they were typed in a shell already connected to TITAN (prompt `titan_admin@titan`) when they were meant for the Mac (prompt `firewood@Hendricks-MacBook-Air`). Habit: **read the prompt before running anything** — it tells you which machine you're on.
2. **`cat key.pub | ssh titan "cat >> ..."` hangs when the key has a passphrase.** The pipe occupies the input channel SSH would use to ask for the passphrase, so it waits forever. Connect interactively first, then paste the key in an editor.
3. **A config block that "was added" but wasn't.** `cat ~/.ssh/config` showed only the original block — the edit had never been saved. Always verify with `cat` after editing instead of assuming.

### Other public keys (e.g. a phone SSH app)

Any other device's public key (e.g. an `ecdsa-sha2-nistp256 ...` key from a mobile SSH client) can be authorized the same way — one line appended to `authorized_keys`. Public keys are not secret; private keys never leave the device that generated them.

---

## 6. Pending

- [ ] Confirm `sudo ufw allow in on tailscale0` is in place (`sudo ufw status numbered`)
- [ ] Test a service from outside the house on mobile data: `http://<TITAN Tailscale IP>:2283`
- [ ] Decide whether to disable key expiry for TITAN in the Tailscale admin console (by default, devices must re-authenticate periodically, which would silently cut off remote access)
