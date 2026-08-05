#!/bin/sh
# ---------------------------------------------------------------------------
# Push the current checkout to the live lobby server. Run it from the project
# root, on any machine that has the SSH key.
#
#     ./tools/server/deploy.sh
#     ./tools/server/deploy.sh 139.180.212.110 ~/.ssh/tumbang-preso
#
# ⚠️⚠️ WHY THIS FILE EXISTS. For two days the deploy lived in one person's
# terminal history, which meant a change that NEEDED a redeploy could sit
# undeployed until that person was free. It cost real time: the reported
# LAN/online skin failure could not be reproduced for days, and the cause was
# the server running older code than every client -- the team's own handoff had
# already guessed "a dedicated server process still running old code" and could
# not act on it. Anyone on the team must be able to do this.
#
# ⚠️ WHEN YOU NEED IT. The server has no screen, so UI, menus, HUD, art and
# audio changes never require a redeploy. These do:
#
#     · adding, removing or renaming an @rpc method  -> URGENT. Godot hashes a
#       node's RPC method names; a mismatch makes clients fail to connect at all
#       with "The rpc node checksum failed", which blames your code rather than
#       your deploy.
#     · host-side rules -- who may join, seating, scoring, round flow
#     · anything in _build_spawn_data, which the host builds
#
#   Rule of thumb: if the change touches network_manager.gd, main.gd,
#   round_manager.gd or character_base.gd, redeploy. Otherwise do not bother.
#
# ⚠️ THE DANGEROUS CASE IS THE ONE THAT LOOKS FINE. A server on old code keeps
# answering, keeps hosting, and keeps broadcasting its OWN stale decisions --
# so the game half-works and the bug looks like it is in the client. Nothing
# warns you. That is why this script prints and compares checksums at the end:
# matching hashes are the only proof the deploy actually landed.
# ---------------------------------------------------------------------------
set -eu

HOST="${1:-139.180.212.110}"
KEY="${2:-$HOME/.ssh/tumbang-preso}"
USER_NAME="${DEPLOY_USER:-root}"
REMOTE="$USER_NAME@$HOST"

[ -f project.godot ] || { echo "deploy.sh: run me from the project root"; exit 1; }
[ -f "$KEY" ] || { echo "deploy.sh: no SSH key at $KEY -- pass one as arg 2"; exit 1; }

# ⚠️ .godot IS EXCLUDED ON PURPOSE. It is a per-platform import cache built for
# THIS machine; shipping it is worse than shipping nothing. The server rebuilds
# it below, which is the slow step and why this takes a couple of minutes.
echo "== packing (excluding .git, .godot, build, kit)"
TARBALL="$(mktemp -t tp-deploy-XXXXXX.tar.gz)"
tar --exclude=.git --exclude=.godot --exclude=build --exclude=kit -czf "$TARBALL" .
echo "   $(du -h "$TARBALL" | cut -f1)"

echo "== uploading to $REMOTE"
scp -i "$KEY" -o StrictHostKeyChecking=accept-new "$TARBALL" "$REMOTE:/root/deploy.tar.gz"
rm -f "$TARBALL"

echo "== installing"
ssh -i "$KEY" "$REMOTE" 'bash -s' <<'REMOTE_SCRIPT'
set -e
# ⚠️ STOP THE LOBBIES FIRST. Replacing the project under a running server leaves
# it executing code that no longer exists on disk, and the next scene load fails
# in a way that reads as a game bug.
systemctl stop 'tumbang-preso-lobby@*' 2>/dev/null || true
rm -rf /root/newgame && mkdir -p /root/newgame
tar -xzf /root/deploy.tar.gz -C /root/newgame
# Carry the import cache across so the reimport below is incremental, not a
# full rebuild of every asset.
[ -d /opt/tumbang-preso/game/.godot ] && cp -a /opt/tumbang-preso/game/.godot /root/newgame/.godot
rm -rf /opt/tumbang-preso/game && mv /root/newgame /opt/tumbang-preso/game
chown -R gameserver:gameserver /opt/tumbang-preso/game
runuser -u gameserver -- env HOME=/var/lib/gameserver /opt/tumbang-preso/godot \
  --headless --path /opt/tumbang-preso/game --import >/dev/null 2>&1 || true
chown -R gameserver:gameserver /opt/tumbang-preso/game
echo "   deployed:"
for f in scripts/systems/network_manager.gd scripts/main.gd scripts/characters/character_base.gd; do
  printf "     %s  %s\n" "$(md5sum "/opt/tumbang-preso/game/$f" | cut -c1-12)" "$f"
done
# Nothing is started here on purpose: lobbies are on-demand (see spawn/spawner.py).
echo "   lobbies running: $(systemctl list-units 'tumbang-preso-lobby@*' --no-legend --no-pager | wc -l) (0 is correct -- they start when a player hosts)"
REMOTE_SCRIPT

echo "== local, for comparison:"
for f in scripts/systems/network_manager.gd scripts/main.gd scripts/characters/character_base.gd; do
  if command -v md5sum >/dev/null 2>&1; then
    printf "     %s  %s\n" "$(md5sum "$f" | cut -c1-12)" "$f"
  else
    printf "     %s  %s\n" "$(md5 -q "$f" | cut -c1-12)" "$f"
  fi
done
echo
echo "⚠️ THE HASHES ABOVE MUST MATCH. If they do not, the deploy did not land and"
echo "   the server is still refereeing with old rules -- which looks like a"
echo "   client bug and is not."
