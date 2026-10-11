# 📓 2026-10-11 — NPM, Homepage, the DNS names investigation, status review

## What got done

1. **Backups confirmed:** the nightly restic job (03:30) has been running on its own every day; the log shows a snapshot each night.
2. **Nginx Proxy Manager installed** (ports 80/81/443). Proven to work with `curl -H "Host: ..."` from TITAN: `302` from `openresty` (NPM) forwarding to Jellyfin.
3. **Pi-hole local DNS records created** through `dns.hosts` (the list was empty, which is why the name didn't resolve at first). The set command replaces the whole list.
4. **Naming discussion:** `<service>.titan.home.arpa` chosen as the convention (general → specific, right to left in DNS), `.local` avoided because of Bonjour/mDNS.
5. **Names don't resolve on the Mac, iPhone or Windows PC.** Investigated by checking one link at a time. Evidence from `scutil --dns` on the Mac: the Wi-Fi resolver listed the ISP's DNS (IPv4 and IPv6), not Pi-hole. Likely cause: the router's DNS is set in three separate places and only one points at Pi-hole. Fix known but **deliberately postponed**.
6. **Homepage deployed** (port 3000) as a dashboard of links by IP, independent of DNS and NPM. `HOMEPAGE_ALLOWED_HOSTS` is mandatory; the Docker socket was left unmounted on purpose.
7. **Mono packages** pulled in by a mistyped command (`secutil` instead of macOS-only `scutil`) were removed after simulating the removal with `apt remove -s`.
8. **Passwords rotated** after the credential found in the repo history; no remaining reuse.
9. **Docs repo** reorganised with the `git mv` script.

## Decisions

- **Vaultwarden deprioritised.** Honest assessment: HTTPS through Tailscale only satisfies the apps' HTTPS requirement (traffic is already encrypted by WireGuard) and puts the tailnet's names in a public certificate log. A self-hosted password manager makes the server's availability and backups critical, and the backup still has no failure alert or off-site copy. Reasonable only as practice with test data for now.
- **Parked on purpose:** Uptime Kuma push alert for backups, off-site copy (the portable SSD is used for other things), the router DNS change, working names, NPM proxy cleanup.

## Lessons

- One link at a time: name → Pi-hole → proxy → service. Each test isolates one layer, and a change made while not knowing which layer fails mixes variables.
- A setting that exists in several places (router DNS, port numbers, IPs) fails when one copy changes and the others don't.
- Some file attachments arrived empty during the session; plain text pasted into the message body always worked.
- A client's DNS is a fact you can read (`scutil --dns`, Pi-hole's Query Log), not something to assume from what the router "should" be handing out.

## Pending

- [ ] Finish the restore comparison with `sudo diff` (config file)
- [ ] Remaining Documentation items are covered by this commit
- [ ] Vaultwarden (practice only), other services (Paperless-ngx, Gitea, Grafana + Prometheus, n8n)
- [ ] Second mini PC as a lab node
- [ ] Quiz-app questions for Pi-hole, Docker Compose, restic, Tailscale
- [ ] Parked items above
