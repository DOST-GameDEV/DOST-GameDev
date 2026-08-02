#!/bin/sh
# ---------------------------------------------------------------------------
# Dedicated lobby pool — Linux. Starts, stops and inspects a fixed pool of
# headless game processes, one per port.
#
# WHY A POOL AND NOT ONE PROCESS: RoundManager and MatchManager are Godot
# autoloads, so a running process holds exactly one match's score, timer and
# round state. Two concurrent lobbies therefore means two processes on two
# ports. Nothing in the codebase is re-entrant and nothing should try to be —
# see network_manager.gd::host_game's dedicated header.
#
# POSIX sh on purpose. A freshly created cloud VM is guaranteed /bin/sh, kill
# and mkdir; it is not guaranteed bash, systemd-run, python or lsof. The one
# optional tool used here is `ss`, and its absence only downgrades a warning.
#
#   ./lobby-pool.sh start [count]
#   ./lobby-pool.sh stop
#   ./lobby-pool.sh restart [count]
#   ./lobby-pool.sh status
#
# Configuration is environment variables, so a systemd unit can set them
# without editing this file:
#
#   GODOT_BIN     path to the headless-capable Godot binary or exported server
#   GAME_PATH     project directory (omit if GODOT_BIN is an exported server)
#   BASE_PORT     first UDP port in the pool           (default 8910)
#   POOL_SIZE     how many lobbies                     (default 8)
#   STATE_DIR     where pidfiles and logs live         (default below)
# ---------------------------------------------------------------------------

GODOT_BIN="${GODOT_BIN:-/opt/tumbang-preso/godot}"
GAME_PATH="${GAME_PATH:-/opt/tumbang-preso/game}"
BASE_PORT="${BASE_PORT:-8910}"
POOL_SIZE="${POOL_SIZE:-8}"
STATE_DIR="${STATE_DIR:-$HOME/.local/state/tumbang-preso}"

RUN_DIR="$STATE_DIR/run"
LOG_DIR="$STATE_DIR/log"

# ⚠️⚠️ THE SCENE PATH IS NOT OPTIONAL AND ITS ABSENCE IS SILENT.
#
# `run/main_scene` in project.godot is res://scenes/ui/SplashScreen.tscn. The
# `--dedicated` / `--port=` parsing lives in the scene that boots — for the path
# below that is scripts/ui/match_setup.gd::_read_dedicated_args, and the splash
# screen parses neither of them. Launch without this path
# and you get a healthy-looking process, a normal-looking log, zero errors, and
# NOTHING LISTENING ON THE PORT. Measured 2026-08-02: the no-scene process ran
# for 18 s at full memory with its UDP port unbound.
#
# This is the single most likely deployment mistake. Do not "simplify" it out.
MAIN_SCENE="res://scenes/ui/MatchSetup.tscn"

# How long `stop` waits for a TERM to be honoured before sending KILL. Godot
# closes the ENet peer and flushes its log on TERM; five seconds is generous
# for a process whose shutdown is a socket close.
STOP_GRACE_SECONDS=5

# ---------------------------------------------------------------------------

usage() {
	cat <<EOF
usage: $0 {start|stop|restart|status} [count]

  GODOT_BIN=$GODOT_BIN
  GAME_PATH=$GAME_PATH
  BASE_PORT=$BASE_PORT
  POOL_SIZE=$POOL_SIZE
  STATE_DIR=$STATE_DIR
EOF
}

say() {
	printf '[pool] %s\n' "$*"
}

err() {
	printf '[pool] %s\n' "$*" >&2
}

stamp() {
	date '+%Y-%m-%d %H:%M:%S'
}

pidfile_for() {
	printf '%s/lobby-%s.pid\n' "$RUN_DIR" "$1"
}

logfile_for() {
	printf '%s/lobby-%s.log\n' "$LOG_DIR" "$1"
}

# Echoes the pid if a live process owns this port's pidfile. A pidfile whose
# process is gone is deleted here rather than reported — that is a crash that
# was already logged by the supervisor subshell, and leaving the stale file
# would make `start` refuse to refill the slot.
running_pid() {
	_pf=$(pidfile_for "$1")
	[ -f "$_pf" ] || return 1
	_pid=$(cat "$_pf" 2>/dev/null)
	case "$_pid" in
		''|*[!0-9]*) rm -f "$_pf"; return 1 ;;
	esac
	if kill -0 "$_pid" 2>/dev/null; then
		printf '%s\n' "$_pid"
		return 0
	fi
	rm -f "$_pf"
	return 1
}

# ⚠️ UDP, NOT TCP. ENet is UDP; `ss -lt` will show nothing here forever and
# reads as "the server never started". Returns 0 when the port is bound.
port_bound() {
	command -v ss >/dev/null 2>&1 || return 2
	ss -lun 2>/dev/null | grep -q "[:.]$1[[:space:]]"
}

preflight() {
	_ok=0
	if [ ! -x "$GODOT_BIN" ]; then
		err "GODOT_BIN '$GODOT_BIN' is not an executable file."
		_ok=1
	fi
	# GAME_PATH is only meaningful when GODOT_BIN is an editor/template binary
	# being pointed at a project directory. An exported server binary carries
	# its own pack, so an absent directory is not automatically an error — but
	# a directory that exists and has no project.godot certainly is.
	if [ -d "$GAME_PATH" ] && [ ! -f "$GAME_PATH/project.godot" ]; then
		err "GAME_PATH '$GAME_PATH' exists but has no project.godot in it."
		_ok=1
	fi
	return $_ok
}

start_one() {
	port="$1"
	log=$(logfile_for "$port")
	pf=$(pidfile_for "$port")

	if pid=$(running_pid "$port"); then
		say "port $port already served by pid $pid — left alone."
		return 0
	fi

	# Someone else's process, or an instance this script did not start (a
	# hand-run server, a leftover from a previous STATE_DIR). Refusing is right:
	# create_server() would fail with "address in use" and the new process would
	# exit seconds later, which is a confusing way to find that out.
	if port_bound "$port"; then
		err "port $port is already bound by a process this pool does not own — skipped."
		return 1
	fi

	# ⚠️ The `--` separates engine arguments from GAME arguments.
	# scripts/main.gd reads OS.get_cmdline_user_args(), which returns ONLY what
	# follows `--`. Put `--dedicated` before it and the engine rejects it as an
	# unknown option.
	set -- --headless
	if [ -d "$GAME_PATH" ]; then
		set -- "$@" --path "$GAME_PATH"
	fi
	set -- "$@" "$MAIN_SCENE" -- --dedicated "--port=$port"

	printf '\n[pool] %s starting on udp/%s\n' "$(stamp)" "$port" >>"$log"

	# The subshell exists to notice the death. Without it a crashed lobby is an
	# empty port and a stale pidfile, discovered by a player failing to connect;
	# with it there is a dated line in the port's own log saying what exit status
	# it died with. It does NOT restart anything — that is systemd's job, and two
	# things trying to restart the same process is worse than neither.
	#
	# `trap '' HUP` so the pool outlives the shell that ran this script (an ssh
	# session that ends must not take eight matches with it).
	(
		trap '' HUP
		"$GODOT_BIN" "$@" >>"$log" 2>&1 &
		child=$!
		printf '%s\n' "$child" >"$pf"
		wait "$child"
		status=$?
		printf '[pool] %s port %s exited with status %s\n' "$(stamp)" "$port" "$status" >>"$log"
		rm -f "$pf"
	) </dev/null >/dev/null 2>&1 &

	# Give the child a moment to write its pidfile, then report what actually
	# happened rather than what was requested.
	sleep 1
	if pid=$(running_pid "$port"); then
		say "started port $port (pid $pid, log $log)"
		return 0
	fi
	err "port $port failed to start — see $log"
	return 1
}

stop_one() {
	port="$1"
	pid=$(running_pid "$port") || {
		say "port $port was not running."
		return 0
	}
	kill -TERM "$pid" 2>/dev/null
	waited=0
	while [ "$waited" -lt "$STOP_GRACE_SECONDS" ]; do
		kill -0 "$pid" 2>/dev/null || break
		sleep 1
		waited=$((waited + 1))
	done
	if kill -0 "$pid" 2>/dev/null; then
		err "port $port (pid $pid) ignored TERM for ${STOP_GRACE_SECONDS}s — sending KILL."
		kill -KILL "$pid" 2>/dev/null
		sleep 1
	fi
	rm -f "$(pidfile_for "$port")"
	say "stopped port $port."
}

cmd_start() {
	count="${1:-$POOL_SIZE}"
	preflight || return 1
	mkdir -p "$RUN_DIR" "$LOG_DIR" || return 1
	failures=0
	i=0
	while [ "$i" -lt "$count" ]; do
		start_one $((BASE_PORT + i)) || failures=$((failures + 1))
		i=$((i + 1))
	done
	if [ "$failures" -gt 0 ]; then
		err "$failures of $count lobbies did not start."
		return 1
	fi
	say "pool of $count up on udp/$BASE_PORT-$((BASE_PORT + count - 1))."
	return 0
}

# Stops the WHOLE pool, not just the count that is nominally configured — a
# pool that was once started at 8 and is now configured at 4 must not leave
# four orphans behind. Driven off the pidfiles that exist.
cmd_stop() {
	[ -d "$RUN_DIR" ] || {
		say "no state directory at $RUN_DIR — nothing to stop."
		return 0
	}
	found=0
	for pf in "$RUN_DIR"/lobby-*.pid; do
		[ -e "$pf" ] || continue
		found=$((found + 1))
		port=${pf##*/lobby-}
		port=${port%.pid}
		stop_one "$port"
	done
	if [ "$found" -eq 0 ]; then
		say "no lobbies were running."
	fi
	return 0
}

cmd_status() {
	printf '%-7s %-10s %-8s %s\n' PORT PID BOUND LOG
	i=0
	while [ "$i" -lt "$POOL_SIZE" ]; do
		port=$((BASE_PORT + i))
		if pid=$(running_pid "$port"); then :; else pid='-'; fi
		port_bound "$port"
		case $? in
			0) bound=yes ;;
			1) bound=NO ;;
			*) bound='?' ;;  # no `ss` on this box
		esac
		printf '%-7s %-10s %-8s %s\n' "$port" "$pid" "$bound" "$(logfile_for "$port")"
		i=$((i + 1))
	done
	# A live pid with an unbound port is the interesting failure: the process is
	# up but is not the dedicated server (almost always the missing scene path),
	# or create_server() failed and it is sitting there doing nothing.
	printf '\n[pool] pid set with BOUND=NO means the process is up but is not\n'
	printf '[pool] listening — check that %s is on its command line.\n' "$MAIN_SCENE"
}

case "${1:-}" in
	start)   shift; cmd_start "$@" ;;
	stop)    cmd_stop ;;
	restart) shift; cmd_stop; cmd_start "$@" ;;
	status)  cmd_status ;;
	*)       usage; exit 2 ;;
esac
