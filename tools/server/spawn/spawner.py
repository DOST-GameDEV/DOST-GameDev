#!/usr/bin/env python3
"""Start a lobby when a player asks for one, and only then.

    🧑 2026-08-02: "we dont need 3 lobbies running at a time. we just wanna be
    able to run multiple lobbies when players host lobbies. unless someone is
    already running a lobby, no lobbies should be showing/running"

This is socket-activated by systemd (`tumbang-preso-spawn.socket`), so while
nobody is hosting there is NO process here at all -- systemd holds the UDP
socket and starts this script only when a datagram lands on it. Idle cost is a
file descriptor.

⚠️⚠️ WHY THIS EXISTS AT ALL, WHEN THE POOL USED TO BE PRE-STARTED. `server_query.gd`
has no registry: a lobby is discovered by asking its port what it is doing, and a
lobby that is not running cannot answer. So "start lobbies on demand" needs
something that is always reachable to receive the request -- and this is the
cheapest possible something, because it is not running either.

⚠️ THE BOX HAS DIED TWICE FROM RUNNING LOBBIES NOBODY WAS IN. 2026-08-02: three
pre-started lobbies on a 946 MB VM exhausted memory, disconnected the players and
wedged sshd itself; recovery needed a forced reboot from the cloud console, twice.
`MAX_LOBBIES` below is the hard stop that makes that unrepeatable, and it is
derived from measured footprint, not guessed.

⚠️ IT CANNOT RUN ANYTHING. The only action is `systemctl start` on ONE templated
unit at ONE of a fixed set of ports. There is no field in the request that names a
command, a path or a unit -- the port is chosen HERE, not by the caller. That
matters because this socket is reachable from the internet.
"""

import json
import os
import re
import socket
import subprocess
import sys

# Must match `server_query.gd`. A datagram without this is not ours and is dropped
# without a reply -- an unsolicited port scan learns nothing.
MAGIC = "tumbang-preso-query"
PROTOCOL_VERSION = 1

# Must match `ServerQuery.POOL_PORT_FIRST` / `POOL_PORT_LAST`.
POOL_PORT_FIRST = 8910
POOL_PORT_LAST = 8917

# ⚠️⚠️ SIX, AND EVERY DIGIT OF THAT IS MEASURED ON THE BOX IT RUNS ON. This was ONE on
# the previous host, an Oracle `VM.Standard.E2.1.Micro` — one EIGHTH of an OCPU, where a
# single running match was enough to wedge the machine: SSH failing at banner exchange,
# the console still reporting Running, recovered only by a forced reboot. Twice.
#
# The pool moved to a Vultr 1 vCPU / 2 GB in Singapore on 2026-08-02, and a real match was
# measured there before this number was touched:
#
#     one lobby refereeing a match:  7.8% of the vCPU, 222 MB resident
#     load average with it running:  0.11   (1.00 = the whole core busy)
#     base OS:                       ~268 MB of the 1962 MB
#
# So six matches is ~47% of the core and ~1600 MB, leaving ~360 MB of headroom. CPU stopped
# being the binding constraint the moment the shape had a whole core; memory is now the
# one that runs out first, which is why the live check below is the real backstop.
#
# ⚠️ RAISE THIS ONLY AFTER MEASURING A REAL MATCH ON THE HARDWARE IT WILL RUN ON. Both
# outages on the old box came from a number reached by arithmetic instead of by watching
# one. The port range stays wider than the cap on purpose: a bigger shape raises this in
# one line and needs no new client build, because the client already asks all eight ports.
MAX_LOBBIES = 6

# ⚠️ AND A COUNT IS NOT ENOUGH ON ITS OWN. `MAX_LOBBIES` assumes every lobby costs
# what the measurement said; a match with four humans, a future map or a leak could
# each make that false, and the failure mode is not a slow server — it is the whole
# machine becoming unreachable, sshd included, needing a forced reboot from the
# cloud console. So the last line of defence is the number the kernel reports right
# now, not arithmetic done in advance.
#
# 260 MB leaves room for one more lobby plus the ~100 MB the OS wants for page
# cache. Refusing to start is a bad evening; running out of memory is a dead box.
MIN_AVAILABLE_MB = 400


def available_mb() -> int:
    """MemAvailable, the kernel's own estimate of what can be allocated without swapping."""
    try:
        with open("/proc/meminfo", "r", encoding="utf-8") as handle:
            for line in handle:
                if line.startswith("MemAvailable:"):
                    return int(line.split()[1]) // 1024
    except (OSError, ValueError, IndexError):
        pass
    # ⚠️ UNREADABLE MEANS REFUSE, NOT PROCEED. A guard that fails open is not a guard.
    return 0

UNIT_TEMPLATE = "tumbang-preso-lobby@{port}.service"

# ⚠️ ANCHORED AND FULLY LITERAL. This is the only string that becomes part of a
# command line, and it is built from an integer we chose ourselves -- but the
# check costs nothing and makes that guarantee local instead of three functions
# away.
UNIT_RE = re.compile(r"^tumbang-preso-lobby@\d{4}\.service$")


def unit_is_active(port: int) -> bool:
    unit = UNIT_TEMPLATE.format(port=port)
    result = subprocess.run(
        ["systemctl", "is-active", "--quiet", unit],
        capture_output=True,
    )
    return result.returncode == 0


def running_ports() -> list:
    return [p for p in range(POOL_PORT_FIRST, POOL_PORT_LAST + 1) if unit_is_active(p)]


def start_lobby(port: int) -> bool:
    unit = UNIT_TEMPLATE.format(port=port)
    if not UNIT_RE.match(unit):
        return False
    result = subprocess.run(["systemctl", "start", unit], capture_output=True)
    if result.returncode != 0:
        sys.stderr.write("spawner: failed to start %s: %s\n"
                         % (unit, result.stderr.decode("utf-8", "replace").strip()))
        return False
    return True


def handle(payload: bytes) -> dict:
    """Decide what to do about one request. Returns the reply, or {} for silence."""
    try:
        request = json.loads(payload.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        return {}
    if not isinstance(request, dict):
        return {}
    if request.get("magic") != MAGIC or int(request.get("v", 0)) != PROTOCOL_VERSION:
        return {}
    if request.get("op") != "spawn":
        return {}

    live = running_ports()

    # ⚠️ AN ALREADY-FREE LOBBY IS NOT A REASON TO START ANOTHER, and the client
    # checks that first anyway -- but two players pressing HOST ONLINE in the same
    # second would both arrive here, and without this the second one starts a
    # lobby nobody needed. Reporting the existing one back is both cheaper and
    # what the client would have found on its next poll.
    if len(live) >= MAX_LOBBIES:
        return {"magic": MAGIC, "v": PROTOCOL_VERSION, "op": "full",
                "running": len(live), "max": MAX_LOBBIES}

    free_mb = available_mb()
    if free_mb < MIN_AVAILABLE_MB:
        sys.stderr.write("spawner: refusing to start a lobby, only %d MB available "
                         "(need %d)\n" % (free_mb, MIN_AVAILABLE_MB))
        return {"magic": MAGIC, "v": PROTOCOL_VERSION, "op": "full",
                "running": len(live), "max": MAX_LOBBIES}

    for port in range(POOL_PORT_FIRST, POOL_PORT_LAST + 1):
        if port in live:
            continue
        if not start_lobby(port):
            continue
        sys.stderr.write("spawner: started lobby on %d (%d running)\n"
                         % (port, len(live) + 1))
        return {"magic": MAGIC, "v": PROTOCOL_VERSION, "op": "spawned", "port": port}

    return {"magic": MAGIC, "v": PROTOCOL_VERSION, "op": "full",
            "running": len(live), "max": MAX_LOBBIES}


def main() -> int:
    # systemd hands the listening socket in as fd 3 (SD_LISTEN_FDS_START).
    # ⚠️ Accept=no in the .socket unit, so this IS the socket, not a connection.
    #
    # ⚠️⚠️ THE FAMILY IS DETECTED, NOT DECLARED, AND GETTING THAT WRONG COST A DEPLOY.
    # `ListenDatagram=8909` binds a dual-stack IPv6 socket (`*:8909`), so `recvfrom`
    # returns a FOUR-tuple — (host, port, flowinfo, scope_id). Constructing the wrapper
    # as AF_INET made `sendto` reject that peer with "AF_INET address must be a pair",
    # which killed the process AFTER it had already started the lobby: the player got
    # their server and no answer, and the unit went into `failed`.
    #
    # `socket.socket(fileno=...)` reads family, type and proto off the descriptor
    # itself, so this is right whether systemd hands us v4, v6 or dual-stack.
    try:
        sock = socket.socket(fileno=3)
    except OSError:
        sys.stderr.write("spawner: no socket on fd 3 -- run me from systemd\n")
        return 1

    # ⚠️ DRAIN, THEN EXIT. systemd re-arms the socket after this process ends, so
    # anything that arrives during the gap is lost -- which is fine, because the
    # client retries every second while it waits. Draining what is already queued
    # avoids starting a whole process per datagram in a burst.
    sock.settimeout(0.4)
    served = 0
    while served < 16:
        try:
            payload, peer = sock.recvfrom(2048)
        except socket.timeout:
            break
        reply = handle(payload)
        if reply:
            # ⚠️ THE REPLY MUST NEVER TAKE DOWN THE SPAWNER. The lobby has already been
            # started by this point, so a failure here loses a courtesy message and
            # nothing else — the client is not waiting on it (see `request_lobby`'s ⚠️
            # in server_query.gd) and finds the new lobby by its normal poll. Crashing
            # instead would leave a perfectly good lobby running behind a unit systemd
            # has marked `failed`, which is exactly what happened on the first deploy.
            try:
                sock.sendto(json.dumps(reply).encode("utf-8"), peer)
            except (OSError, TypeError, ValueError) as err:
                sys.stderr.write("spawner: could not reply to %r: %s\n" % (peer, err))
        served += 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
