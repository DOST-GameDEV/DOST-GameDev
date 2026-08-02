#!/usr/bin/env python3
"""Stop lobbies nobody is in, so an idle box runs nothing.

Run from `tumbang-preso-reap.timer`, once a minute.

⚠️⚠️ WITHOUT THIS, ON-DEMAND IS ONLY HALF TRUE. `spawner.py` starts a lobby when a
player asks; `main.gd`'s § BACK TO THE WAITING ROOM returns an abandoned lobby to
its waiting room and mints a fresh code -- but it stays RUNNING, holding ~155 MB.
So the box would ratchet upward: every host that ever happened would leave a lobby
behind, and the pool would end up exactly as pre-started as it used to be, just
more slowly.

⚠️ IT ASKS THE LOBBY, IT DOES NOT ASK systemd. A unit being active says the process
is alive, not that anybody is in it. The status protocol (`server_query.gd`) already
answers "how many humans are attached" on the game port + 10, so that is what this
reads -- the same number the players' server browser is looking at.

⚠️ TWO CONSECUTIVE EMPTY CHECKS, NOT ONE. A lobby is legitimately empty for the few
seconds between being started and the player who asked for it arriving; killing it
in that window would make HOST ONLINE fail intermittently and look like a network
fault. `GRACE_CHECKS` is what makes the difference between "nobody came" and
"nobody has arrived yet".
"""

import json
import os
import re
import socket
import subprocess
import sys

MAGIC = "tumbang-preso-query"
PROTOCOL_VERSION = 1

POOL_PORT_FIRST = 8910
POOL_PORT_LAST = 8917
STATUS_PORT_OFFSET = 10

# The timer fires every minute, so this is "empty for ~2-3 minutes". Long enough
# that somebody reading a code out loud, alt-tabbing and typing it does not lose
# the lobby underneath them.
GRACE_CHECKS = 3

STATE_PATH = "/var/lib/tumbang-preso-reaper/empty-counts.json"
UNIT_TEMPLATE = "tumbang-preso-lobby@{port}.service"
UNIT_RE = re.compile(r"^tumbang-preso-lobby@\d{4}\.service$")


def unit_is_active(port: int) -> bool:
    return subprocess.run(
        ["systemctl", "is-active", "--quiet", UNIT_TEMPLATE.format(port=port)],
        capture_output=True,
    ).returncode == 0


def occupancy(port: int):
    """How many humans are attached, or None if the lobby did not answer."""
    request = json.dumps({"magic": MAGIC, "v": PROTOCOL_VERSION}).encode("utf-8")
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.settimeout(1.0)
    try:
        sock.sendto(request, ("127.0.0.1", port + STATUS_PORT_OFFSET))
        payload, _ = sock.recvfrom(4096)
        reply = json.loads(payload.decode("utf-8"))
        if reply.get("magic") != MAGIC:
            return None
        # ⚠️ `occupied`, NOT `players`. `players` counts SEATS taken, so a lobby
        # holding one spectator reports 0 and would be reaped out from under them.
        # `occupied` is every human attached, which is the question being asked.
        return int(reply.get("occupied", reply.get("players", 0)))
    except (OSError, ValueError, json.JSONDecodeError):
        return None
    finally:
        sock.close()


def load_state() -> dict:
    try:
        with open(STATE_PATH, "r", encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, ValueError):
        return {}


def save_state(state: dict) -> None:
    os.makedirs(os.path.dirname(STATE_PATH), exist_ok=True)
    with open(STATE_PATH, "w", encoding="utf-8") as handle:
        json.dump(state, handle)


def main() -> int:
    state = load_state()
    for port in range(POOL_PORT_FIRST, POOL_PORT_LAST + 1):
        key = str(port)
        if not unit_is_active(port):
            state.pop(key, None)
            continue

        here = occupancy(port)
        if here is None:
            # ⚠️ NO ANSWER IS NOT "EMPTY". A lobby mid-scene-change, or one whose
            # status socket failed to bind, would otherwise be reaped for being
            # quiet -- and a busy match is exactly when a process is least likely
            # to answer promptly. Reset the count and look again next minute.
            state.pop(key, None)
            continue

        if here > 0:
            state.pop(key, None)
            continue

        state[key] = int(state.get(key, 0)) + 1
        if state[key] < GRACE_CHECKS:
            continue

        unit = UNIT_TEMPLATE.format(port=port)
        if not UNIT_RE.match(unit):
            continue
        subprocess.run(["systemctl", "stop", unit], capture_output=True)
        sys.stderr.write("reaper: stopped %s after %d empty checks\n"
                         % (unit, state[key]))
        state.pop(key, None)

    save_state(state)
    return 0


if __name__ == "__main__":
    sys.exit(main())
