#!/usr/bin/env bash
# Reorganizes Project-TITAN documentation into the numbered folder structure.
# Run from the repo root (the folder that contains Knowledge-base/ and Journal/).
#   ./reorganize-titan-docs.sh --dry-run   -> only prints what would happen
#   ./reorganize-titan-docs.sh             -> does it (git mv / git rm, nothing is lost: it's all in git history)

set -u
DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

KB="Knowledge-base"

run() {
  if [ "$DRY" -eq 1 ]; then echo "[dry-run] $*"; else "$@" || echo "!! failed: $*"; fi
}

# git mv that skips quietly if the source doesn't exist (so re-running is safe)
mv_() {
  local src="$1" dst="$2"
  if [ ! -e "$src" ]; then echo "skip (not found): $src"; return; fi
  run mkdir -p "$(dirname "$dst")"
  if [ "$DRY" -eq 1 ]; then echo "[dry-run] move: $src -> $dst"; return; fi
  # git mv only works on files git already tracks; new/untracked files fall back to a plain mv
  git mv -f "$src" "$dst" 2>/dev/null || mv -f "$src" "$dst" || echo "!! failed: $src"
}

rm_() {
  local f="$1"
  if [ ! -e "$f" ]; then echo "skip (not found): $f"; return; fi
  if [ "$DRY" -eq 1 ]; then echo "[dry-run] delete: $f"; return; fi
  git rm -f -q "$f" 2>/dev/null || rm -f "$f" || echo "!! failed: $f"
}

[ -d "$KB" ] || { echo "Run this from the repo root (no $KB/ here)."; exit 1; }

echo "== 1. Networking / Security / Troubleshooting =="
mv_ "$KB/02 Networking/04-networking-fundamentals (1).md"  "$KB/02 Networking/04-networking-fundamentals.md"
mv_ "$KB/02 Networking/06-firewall-ufw (1).md"             "$KB/08 Security/06-firewall-ufw.md"
# the "(1)" checklist is the NEWER one (has the DHCP reservation section) -> replaces the old one
mv_ "$KB/12-network-migration-checklist (1).md"            "$KB/12 Troubleshooting/12-network-migration-checklist.md"
rm_ "$KB/12-network-migration-checklist.md"

echo "== 2. Journal entries that were filed in the wrong place =="
mv_ "$KB/02 Networking/2026-08-21-networking-firewall (1).md" "Journal/2026-08-21-networking-firewall.md"
rm_ "$KB/2026-09-18-samba-kuma-portainer.md"        # exact duplicate of Journal/2026-09-18-samba-kuma-portainer.md

echo "== 3. Docker + services (replaces the misspelled '04 Dorker' and the stray 'pi-hole' folder) =="
mv_ "$KB/pi-hole/11-titan-services-pihole (1).md"   "$KB/04 Docker/11-titan-services-pihole.md"   # newer version
rm_ "$KB/pi-hole/11-titan-services-pihole.md"
mv_ "$KB/11-titan-services-immich.md"               "$KB/04 Docker/11-titan-services-immich.md"
mv_ "$KB/11-titan-services-jellyfin.md"             "$KB/04 Docker/11-titan-services-jellyfin.md"
mv_ "$KB/11-titan-services-filebrowser.md"          "$KB/04 Docker/11-titan-services-filebrowser.md"

echo "== 4. Automation -> Linux =="
mv_ "$KB/Automation/08-automation.md"               "$KB/01 Linux/08-automation.md"

echo "== 5. Project folder cleanup =="
mv_ "$KB/0 Project/Current-Hardware copy.md"        "$KB/0 Project/Current-Hardware.md"
mv_ "$KB/01 Linux/ssh secure-ufw.jpg"               "$KB/0 Project/screenshots/ssh-secure-ufw.jpg"
mv_ "Journal/titan-infrastructure.jpg"              "$KB/0 Project/screenshots/titan-infrastructure.jpg"

echo "== 6. Junk =="
rm_ "$KB/empty.md"
rm_ "$KB/empty copy.md"

echo "== 7. Stop tracking .DS_Store (already in .gitignore, but were committed before that) =="
if [ "$DRY" -eq 1 ]; then
  git ls-files | grep '\.DS_Store$' | sed 's/^/[dry-run] git rm --cached /'
else
  git ls-files -z | grep -z '\.DS_Store$' | xargs -0 -r git rm --cached -q
fi

echo "== 8. Remove now-empty / misspelled folders (local only; git doesn't track empty dirs) =="
for d in "$KB/pi-hole" "$KB/Automation" "$KB/04 Dorker"; do
  [ -d "$d" ] && { find "$d" -name .DS_Store -delete 2>/dev/null; run rmdir "$d" 2>/dev/null || echo "kept (not empty): $d"; }
done

echo
echo "Done. Review with:  git status"
echo "Then commit with the message you prefer (suggestion in the chat)."
