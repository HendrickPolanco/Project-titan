# 🛡️ Module 9 — Advanced Security and Administration

> Status: ✅ Completed
> Related certifications: Security+

---

## 1. Account management and least privilege

Same principle already applied with UFW (`allow from local network` instead of opening to the whole internet), now applied to **user accounts**: every account/process should have only the permissions it needs for its task, no more.

Already in practice on TITAN without necessarily framing it this way:
- Daily use happens as `titan_admin`, not directly as `root` — and with `PermitRootLogin no`, direct root login over SSH isn't even possible.
- Elevated privileges are requested punctually with `sudo` for a specific command, not by running an entire session as root.

**Why this matters:** if a normal account is compromised (stolen password, hijacked session), the attacker only has that account's limited permissions — not full system control immediately. Using `sudo` per-command also leaves an audit trail (who, when, what command) that's absent when logged in as root the whole time.

---

## 2. Authentication logs — who tried to get in

Already used `journalctl -u ufw` to see what the firewall blocked. There's a specific log for **login attempts** (successful and failed):

```bash
sudo journalctl -u ssh
# or, on older systems:
sudo tail -f /var/log/auth.log
```

### Real distinction: hardened SSH changes what shows up in the log

Without `PasswordAuthentication no`, a brute-force attempt would show many "Failed password" lines. With it already active on TITAN, an attacker never even gets prompted for a password — the log instead shows something like:

```
Failed publickey for titan_admin from X.X.X.X
Connection closed by X.X.X.X port XXXXX [preauth]
```

**The real takeaway:** password brute-forcing against SSH becomes impossible by design, not just harder — there's no password mechanism left to attempt combinations against. The door isn't just guarded more closely, it's closed entirely. That's the actual value of the hardening done in Module 6.

---

## 3. Fail2ban

Monitors authentication logs and, when it detects a suspicious pattern (several failed attempts from the same IP in a short window), automatically adds a temporary block to the firewall (UFW).

### Fail2ban vs `ufw limit` — not redundant, complementary

- **`ufw limit`** — operates at the **connection** level: counts how many times an IP tries to *connect* to a port in a short time, regardless of whether the login attempt succeeded or failed.
- **Fail2ban** — operates at the **log/application** level: reads the actual content of authentication attempts and decides to ban based on more specific, configurable patterns (e.g. "5 failed attempts in 10 minutes = 1 hour ban").

They're normally used together, not as substitutes — complementary layers, same idea as host firewall + router NAT.

### Installation and basic config

```bash
sudo apt install fail2ban
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local   # never edit jail.conf directly
sudo nano /etc/fail2ban/jail.local
```

```
[sshd]
enabled = true
maxretry = 5
bantime = 3600
```

- `maxretry` — failed attempts allowed before banning
- `bantime` — ban duration in seconds

### ⚠️ Important nuance: does fail2ban still add value on TITAN's SSH specifically?

**No, not for SSH specifically, right now.** With `PasswordAuthentication no` already active, there's no password brute-force pattern left for fail2ban to detect on SSH — a rejected connection due to missing key isn't a variable, repeated authentication failure fail2ban can act on the same way.

**Where it does add real value:** future web-based services on TITAN (Nextcloud, Vaultwarden, Gitea, Portainer) that use username + password through a login form, unlike SSH's key-based auth. Those services *can* be brute-forced, and each would need its own fail2ban "jail" configured to read that service's specific log format.

---

## 4. Basic auditing

Systematically reviewing what's currently active, instead of only reacting when something breaks.

```bash
last                                  # who logged in, when, from where
sudo cat /etc/passwd                  # which user accounts exist
sudo grep -v nologin /etc/passwd      # filter to accounts that CAN log in
sudo ss -tuln                         # listening ports (already known)
sudo ufw status verbose               # active firewall rules (already known)
```

**Why this matters over time:** as more services get installed, test users get created, and ports get opened temporarily to test something, it's easy to forget to close those doors afterward. Periodic auditing is asking "is everything currently exposed/active still actually needed?" — applying least privilege not just at configuration time, but by reviewing that exposure hasn't quietly accumulated.

`last` output example:
```
titan_admin  pts/0   10.0.0.66   Fri Aug 21 20:57  still logged in
```
An unrecognized IP or a login time that doesn't match actual usage is the warning sign to look for.

---

## 5. Disaster recovery plan (backups that are actually reliable)

The technical piece (a `tar` + dynamic-date backup script run on a cron schedule) was already built in Module 8. What completes it is the **discipline** around it — an unverified backup isn't a recovery plan, it's a hope.

### The 3 elements of a real recovery plan

1. **The backup itself** — script + cron, already built
2. **Periodic verification** — occasionally confirming a backup can actually be restored (not just that the `.tar.gz` file exists, but that it opens and the data is intact)
3. **An off-site copy** — the classic **3-2-1 rule**: 3 copies of data, on 2 different types of media, with 1 copy off-site

### Why "more discs in the same machine" isn't enough

Two drives inside the same mini PC both protect against *mechanical/technical failure* of one specific disk — but not against events that affect the **entire physical unit** at once: a power surge that fries the motherboard and everything connected to it, a house fire, a burglary, flooding. In those cases, having two internal disks doesn't help, because the failure isn't "which disk broke," it's "the entire physical unit is gone or inaccessible."

**Applied to TITAN's plan:** the portable SSD earmarked for backups only provides real protection if it doesn't sit next to the mini PC all the time. If it lives in the same room, the same risk event (theft, fire, electrical surge affecting the whole house) reaches it too. Real off-site protection means a different physical location — with a family member, at work, in a safe deposit box, etc.
