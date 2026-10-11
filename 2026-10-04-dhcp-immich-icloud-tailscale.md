# 📓 2026-10-04 — DHCP reservation, iCloud → Immich, Tailscale

## What got done

1. **DHCP reservation on the new router (Cudy app)** — Advanced Settings → Security → IP/MAC Binding, reserved the current IP for TITAN's MAC address. Verified with a real reboot: same IP and MAC afterwards. This removes the root cause of the previous migration pain (an IP that can drift).
2. **Retro quiz on the previous session** — three short questions on UFW rules vs. subnet changes, the vanishing `172.17.0.0/16` rule, and `775` vs `777`. Corrections: the Docker-internal UFW rule *disappeared* (not "was never added"), and the point of `775` is limiting what *processes on the host* can write, not just outside attackers.
3. **Data transfer finished** — the second 2TB drive's contents and other disks were moved onto the HDD; phone backup to Immich configured.
4. **iCloud → Immich migration started via the Immich phone app.** First attempt produced thousands of upload errors (1,966, later 6,568) with nothing suspicious in the server logs. Root cause, found by the user: the **phone ran out of storage** — iCloud "optimized" photos only keep a small local copy, so the phone has to download each original before it can upload it, and that temporary download needs free space. Failures happened on the phone side, before anything reached TITAN, which is why the server logs looked clean. Lesson: when server logs show nothing, the failure is probably upstream of the server.
5. **Tailscale installed** on TITAN, phone, and Mac for remote access without exposing ports.
6. **Second SSH key for remote access** created and authorized, plus an extra phone-app public key authorized.

## Lessons

- Server logs only tell you about requests that *reached* the server. "Nothing in the logs" is itself information.
- `PasswordAuthentication no` also blocks `ssh-copy-id`'s password step — new keys must be added using an already-authorized key.
- Read the shell prompt before running a command: several errors today came from running Mac commands inside the TITAN session.
- Verify a config edit with `cat` instead of assuming it saved.

## Pending

- [ ] Verify the `tailscale0` UFW rule and test Immich/SSH from mobile data
- [ ] Check Tailscale key expiry for TITAN
- [ ] **Backups:** the photo library now lives on a single HDD with no second copy — set up the 3-2-1 plan (portable SSD + off-site copy) before relying on it
