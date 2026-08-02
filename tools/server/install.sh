#!/bin/sh
# ---------------------------------------------------------------------------
# One-shot bootstrap for a fresh cloud VM: fetches the right Godot binary for
# THIS machine's architecture, creates the service account, installs the
# systemd units and starts the pool.
#
#   sudo ./install.sh                 # 8 lobbies on 8910-8917
#   sudo POOL_SIZE=3 ./install.sh     # 3 lobbies on 8910-8912 (1 GB boxes)
#
# Run it FROM the project directory you want served, or set GAME_SRC. It copies
# the project to /opt/tumbang-preso/game rather than serving it in place, so the
# service does not depend on your home directory or your checkout.
#
# Idempotent: re-running upgrades the binary and the units and restarts the
# pool. Safe to run again after `git pull`.
#
# POSIX sh, same reasoning as lobby-pool.sh: a fresh VM is guaranteed /bin/sh
# and not much else. Uses curl or wget, whichever exists.
#
# ⚠️ THIS SCRIPT DOES NOT TOUCH THE FIREWALL. Two firewalls have to allow UDP
# 8910-8927 (game ports AND status ports) and both are provider-specific and
# destructive to get wrong — on Oracle's Ubuntu images `ufw` can stop the
# instance booting. See §5 of docs/Dedicated_Server_Deployment.md and do that
# part deliberately, by hand.
#
# ⚠️ AND IT DOES NOT POINT THE GAME AT THIS BOX. `POOL_ADDRESS` in
# scripts/systems/server_query.gd is compiled into the PLAYERS' build, not read
# from the server. Until it names this VM, HOST ONLINE and join codes are off in
# every copy of the game however healthy this pool is. See §2b.
# ---------------------------------------------------------------------------
set -eu

GODOT_VERSION="${GODOT_VERSION:-4.7.1}"
PREFIX="${PREFIX:-/opt/tumbang-preso}"
SERVICE_USER="${SERVICE_USER:-gameserver}"
BASE_PORT="${BASE_PORT:-8910}"
POOL_SIZE="${POOL_SIZE:-8}"
GAME_SRC="${GAME_SRC:-$(pwd)}"

say() { printf '\n== %s\n' "$1"; }
die() { printf 'install.sh: %s\n' "$1" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "run as root (sudo ./install.sh)"
[ -f "$GAME_SRC/project.godot" ] || die "no project.godot in $GAME_SRC -- cd to the project, or set GAME_SRC"

# --- architecture ----------------------------------------------------------
# ⚠️ THE MISTAKE THIS EXISTS TO PREVENT. Oracle's Always Free capacity is Ampere
# A1, which is aarch64; a Godot binary for x86_64 does not execute there at all,
# and the failure ("cannot execute binary file") arrives long after you have
# provisioned. Detected rather than configured, because nobody gets this wrong
# on purpose -- they get it wrong by copying a command from a doc.
case "$(uname -m)" in
	aarch64|arm64)  GODOT_ARCH="linux.arm64" ;;
	x86_64|amd64)   GODOT_ARCH="linux.x86_64" ;;
	armv7l|armv7)   GODOT_ARCH="linux.arm32" ;;
	i686|i386)      GODOT_ARCH="linux.x86_32" ;;
	*) die "unsupported architecture $(uname -m) -- no official Godot build for it" ;;
esac
ZIP="Godot_v${GODOT_VERSION}-stable_${GODOT_ARCH}.zip"
URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/${ZIP}"
say "architecture $(uname -m) -> $GODOT_ARCH"

# --- deps ------------------------------------------------------------------
# unzip is not on every minimal image. Everything else here is coreutils.
if ! command -v unzip >/dev/null 2>&1; then
	say "installing unzip"
	if command -v apt-get >/dev/null 2>&1; then
		apt-get update -qq && apt-get install -y -qq unzip
	elif command -v dnf >/dev/null 2>&1; then
		dnf install -y -q unzip
	elif command -v yum >/dev/null 2>&1; then
		yum install -y -q unzip
	else
		die "no unzip and no known package manager -- install unzip and re-run"
	fi
fi

fetch() { # url dest
	if command -v curl >/dev/null 2>&1; then curl -fsSL "$1" -o "$2"
	elif command -v wget >/dev/null 2>&1; then wget -qO "$2" "$1"
	else die "neither curl nor wget is installed"; fi
}

# --- account ---------------------------------------------------------------
if ! id "$SERVICE_USER" >/dev/null 2>&1; then
	say "creating $SERVICE_USER"
	useradd -r -m -d "/var/lib/$SERVICE_USER" -s /usr/sbin/nologin "$SERVICE_USER" 2>/dev/null \
		|| useradd -r -m -d "/var/lib/$SERVICE_USER" -s /sbin/nologin "$SERVICE_USER"
fi

# --- binary ----------------------------------------------------------------
mkdir -p "$PREFIX"
say "fetching Godot $GODOT_VERSION ($GODOT_ARCH)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fetch "$URL" "$TMP/godot.zip" || die "download failed: $URL"
unzip -qo "$TMP/godot.zip" -d "$TMP"
# The archive holds one executable whose name carries the version and arch.
BIN="$(find "$TMP" -maxdepth 1 -type f -name 'Godot_v*' | head -n 1)"
[ -n "$BIN" ] || die "no Godot binary inside $ZIP"
install -m 0755 "$BIN" "$PREFIX/godot"

# ⚠️ PROVE IT RUNS BEFORE ANYTHING DEPENDS ON IT. A wrong-architecture binary
# dies here, on the line that says why, instead of inside a systemd unit that
# reports "activating" forever.
"$PREFIX/godot" --version >/dev/null 2>&1 || die "$PREFIX/godot will not execute -- wrong architecture for $(uname -m)?"
say "godot: $("$PREFIX/godot" --version)"

# --- project ---------------------------------------------------------------
say "installing project from $GAME_SRC"
rm -rf "$PREFIX/game"
mkdir -p "$PREFIX/game"
# -a to keep the tree; .git and the local Godot cache are dead weight on a
# server and .godot is regenerated on first boot anyway.
(cd "$GAME_SRC" && tar --exclude=.git --exclude=.godot --exclude=build -cf - .) | (cd "$PREFIX/game" && tar -xf -)
chown -R "$SERVICE_USER:$SERVICE_USER" "$PREFIX/game"

# --- import ----------------------------------------------------------------
# ⚠️⚠️ THE `.godot` CACHE IS EXCLUDED ABOVE ON PURPOSE, AND THAT MAKES THIS STEP
# MANDATORY. The dev machine's cache is built for its own platform and absolute
# paths, so shipping it is worse than shipping nothing — but a project with no
# cache imports its whole asset tree on first run. For this project that is a
# few hundred MB of 3D and audio.
#
# Doing it ONCE, here, rather than letting the units do it: eight services
# starting at the same second would each begin the same import into the same
# directory, on a 2-core box, while systemd's StartLimitBurst counts the ones
# that take too long. Import first, then start things that assume it is done.
say "importing assets (first run only, this takes a while)"
runuser -u "$SERVICE_USER" -- env HOME="/var/lib/$SERVICE_USER" \
	"$PREFIX/godot" --headless --path "$PREFIX/game" --import >/dev/null 2>&1 \
	|| sudo -u "$SERVICE_USER" HOME="/var/lib/$SERVICE_USER" \
	   "$PREFIX/godot" --headless --path "$PREFIX/game" --import >/dev/null 2>&1 \
	|| die "asset import failed -- run it by hand to see why:
  sudo -u $SERVICE_USER HOME=/var/lib/$SERVICE_USER $PREFIX/godot --headless --path $PREFIX/game --import"
chown -R "$SERVICE_USER:$SERVICE_USER" "$PREFIX/game"

# --- units -----------------------------------------------------------------
UNIT_SRC="$GAME_SRC/tools/server/systemd/tumbang-preso-lobby@.service"
[ -f "$UNIT_SRC" ] || die "missing $UNIT_SRC"
say "installing systemd template unit"
install -m 0644 "$UNIT_SRC" /etc/systemd/system/tumbang-preso-lobby@.service
systemctl daemon-reload

say "starting $POOL_SIZE lobbies from $BASE_PORT"
i=0
while [ "$i" -lt "$POOL_SIZE" ]; do
	port=$((BASE_PORT + i))
	systemctl enable --now "tumbang-preso-lobby@${port}.service" >/dev/null
	i=$((i + 1))
done

# --- prove it ---------------------------------------------------------------
# ⚠️ "ACTIVE" IS NOT "LISTENING". The single most likely deployment mistake here
# produces a unit systemd calls active with nothing bound to the port, so the
# check that matters is the socket, not the unit. See §2.
sleep 4
say "bound UDP ports (game + status)"
bound=0
i=0
while [ "$i" -lt "$POOL_SIZE" ]; do
	port=$((BASE_PORT + i))
	if command -v ss >/dev/null 2>&1 && ss -lun 2>/dev/null | grep -q ":$port\b"; then
		printf '  %s  LISTENING\n' "$port"
		bound=$((bound + 1))
	else
		printf '  %s  NOT LISTENING  <- journalctl -u tumbang-preso-lobby@%s\n' "$port" "$port"
	fi
	i=$((i + 1))
done

printf '\n'
if [ "$bound" -eq "$POOL_SIZE" ]; then
	printf 'All %s lobbies are up.\n' "$POOL_SIZE"
else
	printf '%s of %s lobbies bound. Check the units that did not.\n' "$bound" "$POOL_SIZE"
fi
cat <<EOF

Two things this script deliberately did NOT do:

  1. Firewall. Allow UDP ${BASE_PORT}-$((BASE_PORT + POOL_SIZE - 1)) AND
     $((BASE_PORT + 10))-$((BASE_PORT + 10 + POOL_SIZE - 1)) (the status ports)
     in BOTH the provider's firewall and this box's own. See §5 -- and do not
     use ufw on Oracle's Ubuntu images.

  2. Point the game at this box. Set POOL_ADDRESS in
     scripts/systems/server_query.gd to this VM's public address and rebuild
     the players' copies. Until then HOST ONLINE and join codes are switched
     off in every build. See §2b.

Then, from a dev machine, without editing the constant:

  Godot_v${GODOT_VERSION}-stable_win64.exe --path . tools/ui/host_online_shot.tscn -- --pool=<this-vm-ip> %TEMP%\\

EOF
