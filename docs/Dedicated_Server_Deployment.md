# Standing up the dedicated lobby pool

How to run the online lobbies on a cloud VM, what it actually costs, and the
four things that fail silently.

Scripts referenced here live in `tools/server/`:

| file | what it is |
| --- | --- |
| `lobby-pool.sh` | Linux. Starts / stops / inspects the pool. POSIX sh, no dependencies. |
| `lobby-pool.ps1` | Windows. Same verbs, for exercising the pool on a dev machine. |
| `systemd/tumbang-preso-lobby@.service` | One templated unit per port, for the real deployment. |

---

## 1. The shape of the thing

One process is one match. `RoundManager` and `MatchManager` are Godot autoloads,
so a running process holds exactly one score, one timer and one round state.
Eight concurrent lobbies is eight processes on eight UDP ports — 8910 to 8917 —
not one process juggling eight matches. Nothing in the codebase is re-entrant
and nothing should be made so; `network_manager.gd::host_game`'s dedicated
header says the same thing at the source.

`--dedicated` makes the process referee without taking a seat. It still owns
round logic, still answers `is_host()`, and simply does not enter itself into
`connected_peer_ids` — so all four seats stay available to humans, filled by AI
until they arrive.

### What a player actually does

Nobody types an IP. On the MULTIPLAYER screen:

* **HOST ONLINE** takes an idle server out of the pool and drops that player in as
  lobby leader. The lobby then shows them a four-character code to read out.
* **JOIN** takes that code. `server_query.gd::resolve_code()` turns it into an
  address by matching it against what the pool answered.
* **ONLINE SERVERS** lists the pool — `SERVER 3 · 2/4 · ESKINITA · IN THE LOBBY`.
  Codes are deliberately **not** shown in that list; see the ⚠️ in
  `multiplayer_setup.gd::_refresh_online_browser`.

Typing `<vm-ip>:<port>` still works and is the fallback when something is wrong:
`split_address()` splits host from port, so `203.0.113.9:8913` reaches the fourth
lobby in the pool, and a bare address falls back to 8910. It is also the only one
of the four that does not depend on the status-query socket, which makes it the
right thing to try first when the pool looks dead.

"Hosting online" is a claim, not a launch. The eight processes are already
running; HOST ONLINE picks one reporting `players == 0` and `in_progress == false`,
and the leader role goes to the first peer that identifies. So the number of
people who can host **at the same time** is the pool size, not the player count —
§7 is therefore a question about how many simultaneous hosts you want, not just
how much RAM you have.

---

## 2. ⚠️ The one command, and the one way to get it wrong

```
godot --headless --path /opt/tumbang-preso/game res://scenes/ui/MatchSetup.tscn -- --dedicated --port=8910
```

Two parts of that are load-bearing and neither fails loudly.

**`res://scenes/ui/MatchSetup.tscn` is required.** `project.godot` sets
`run/main_scene` to `res://scenes/ui/SplashScreen.tscn`. The `--dedicated` and
`--port=` parsing lives in `scripts/ui/match_setup.gd::_read_dedicated_args`,
which never runs if the splash screen is what booted. Measured on the dev machine
2026-08-02: launched without the scene path, the process ran for 18 seconds, used
the same ~215 MB as a working server, logged nothing but the engine banner,
exited nothing, and **never bound its UDP port**. `systemctl status` would call
that unit active.

**⚠️ It must be `MatchSetup.tscn`, NOT `Main.tscn`, and this one is even quieter.**
`scripts/main.gd` also understands `--dedicated`, so naming `Main.tscn` produces a
server that starts, binds both ports and accepts connections — and is wrong. It
drops straight into a running match, so `NetworkManager.match_in_progress` is true
from frame one, every row in the players' server list reads *in a match* before
anyone has joined, and a joining player is routed into a live game with no seat to
pick and no ready-up. `MatchSetup.tscn` is the waiting room a listen host already
uses, and parking there is what makes the lobby joinable.

Measured on the dev machine 2026-08-02, same port, same flags, only the scene
changed:

| Boot scene | status reply |
| --- | --- |
| `res://scenes/ui/MatchSetup.tscn` | `code=DE23 players=0/4 in_progress=false` — joinable |
| `res://scenes/main/Main.tscn` | `code=CRG6 players=0/4 in_progress=true` — unjoinable, silently |
There is no error anywhere.

**`--` is required, and everything game-related goes after it.** `main.gd` reads
`OS.get_cmdline_user_args()`, which returns only the arguments following `--`.
Put `--dedicated` in front of it and the engine rejects it as an unknown option
instead.

If you only remember one diagnostic from this document: a lobby that is up but
not listening is almost always the missing scene path. `lobby-pool.sh status`
prints `BOUND=NO` next to a live PID for exactly that case.

---

## 2b. ⚠️ The half nobody remembers: pointing the GAME at the VM

Standing up the pool is only one end of it. **The client build has to be told
where the pool is**, and that is a constant in the game, not a setting on the box:

```gdscript
# scripts/systems/server_query.gd
const POOL_ADDRESS: String = ""   # <- put the VM's public IP or hostname here
```

It ships **empty**, deliberately — there is no VM yet, and a constant pointing at
somebody's old test box would be worse than one pointing nowhere. But until it is
filled in, three of the four ways into a game are dead:

| With `POOL_ADDRESS` empty | What the player sees |
| --- | --- |
| HOST ONLINE | *"This build has no online server address in it yet…"* |
| ONLINE SERVERS | button reads `ONLINE SERVERS · UNAVAILABLE` |
| a four-character code | *"Join codes need the online servers…"* |
| typing `<vm-ip>:<port>` | **works** — it never asks the pool |

This is why the screen names the unconfigured case explicitly instead of sitting
on *searching…*: an empty constant and a dead VM look identical from the player's
side, and only one of them is worth debugging the network over.

**So a deployment is two artefacts, not one:** the pool running on the VM, and a
build of the game with the VM's address compiled into it. Change the VM's IP and
every existing build stops finding it — which is the argument for a hostname you
control rather than a raw IP, if you have one.

Verify from a dev machine without touching the constant:

```
Godot_v4.7.1-stable_win64.exe --path . tools/ui/host_online_shot.tscn -- --pool=<vm-ip> %TEMP%\
```

`--pool=` overrides `POOL_ADDRESS` at runtime (see `_read_pool_override`). It
exists for exactly this check and for local testing against `127.0.0.1`; it is
not something a player ever passes.

---

## 3. ⚠️ The architecture trap: Oracle's free tier is ARM

Godot export templates are per-architecture. The Always Free capacity Oracle
actually wants to give you is **Ampere A1, which is arm64 (aarch64)** — so a
server binary built with the `linux x86_64` template will not run on it at all.

**What the research found (checked 2026-08-02):**

- **A Linux arm64 template does ship, and you do not have to compile it.** The
  official 4.7-branch build script copies eight Linux binaries into the template
  pack: `linux_{debug,release}.{x86_64,x86_32,arm64,arm32}`. Confirmed from
  [godot-build-scripts, 4.7 branch](https://raw.githubusercontent.com/godotengine/godot-build-scripts/4.7/build-release.sh),
  which is the Godot organisation's own release tooling.
  ⚠️ **Confirmed from the build script, not from a listing of the shipped
  `.tpz`** — nobody opened the released archive to count what is inside it. If
  you are betting a deployment on this, download
  `Godot_v4.7.1-stable_export_templates.tpz` and check for `linux_release.arm64`
  before you provision anything.
- **There is no separate arm64 template download**, and none is needed. The
  4.7.1-stable release carries exactly two template assets (standard and Mono).
  The `Godot_v4.7.1-stable_linux.arm64.zip` asset on the download page is the
  **editor**, not a template.
- **There is no separate server build either.** Godot's own docs state that
  since 4.0, headless is a flag on any binary and *"You do not need to use a
  specialized server binary anymore, unlike Godot 3.x."*
  ([Exporting for dedicated servers](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_dedicated_servers.html))
- Godot's Linux export preset also *offers* `rv64`, `ppc64` and `loongarch64`,
  and official builds ship **no** templates for those three. Not relevant to
  either free tier, but it is the shape of the trap: the preset dropdown is not
  the same list as the template pack.

**So the trap is survivable, but it is still a trap:** the arm64 template exists,
and picking the x86_64 one by accident produces a binary that will not execute on
the box you deployed it to. The export architecture has to be chosen
deliberately, and the choice is invisible until runtime.

**Two ways to avoid the question entirely:**

1. **Use Google's `e2-micro`, which is x86-64.** Comes with its own costs (§4).
2. **Do not export at all.** Put the Linux **editor** binary plus the project
   source on the server and run it with `--path`, exactly as the dev machine
   does. Godot publishes a Linux arm64 editor build, so this works on Ampere
   too, and it is how every measurement in §7 was taken. It costs disk and boot
   time and puts your source on the server, but it removes the export step —
   and the architecture mistake — from the deployment.

---

## 4. Which free tier is realistic

Both serious options require a **credit card at signup**. Oracle: *"most users
need a mobile phone number and a credit card"*, with a temporary authorisation
hold and no charge unless you upgrade. Google: *"A Google Cloud billing account
is required"*, with a $0–$1 temporary hold. Neither charges for the free
resources; neither has a card-free path. If a card is not available, the honest
answer is a cheap paid VPS, not either of these.

### Oracle Cloud Always Free

- **What you get (arm64):** Ampere A1 at **1,500 OCPU-hours + 9,000 GB-hours per
  month — 2 OCPUs and 12 GB RAM** run continuously, as one 2-OCPU VM or two
  1-OCPU VMs.
  ⚠️ **The widely repeated "4 OCPU / 24 GB" figure is stale.** Oracle's own
  [Compute Arm reference page](https://docs.oracle.com/en-us/iaas/Content/Compute/References/arm.htm)
  still says 3,000/18,000 while two Free Tier pages say 1,500/9,000; the Free
  Tier pages corroborate each other and are the ones to trust. Secondhand
  reporting dates the cut to mid-June 2026 — *that date is unverified*.
- **What you get (x86-64):** two `VM.Standard.E2.1.Micro` instances, each
  **1/8 OCPU (burstable) and 1 GB RAM**, in a single availability domain.
- **200 GB total block storage** across boot and block volumes, 47 GB boot
  minimum.
- **⚠️ "Out of host capacity" on A1 is officially acknowledged, not a rumour.**
  Oracle's Free Tier FAQ says to try a different availability domain, and
  otherwise *"wait a while, and then try to launch the instance again."* You can
  create the account and be unable to launch the instance you signed up for.
  **Do not schedule a demo against an A1 instance that does not exist yet.**
- **⚠️ Idle reclamation is real and the criteria are published.** An Always Free
  instance is deemed idle when, over a 7-day window, *all* of: 95th-percentile
  CPU below 20%, network below 20%, and (A1 only) memory below 20%. **A pool of
  empty lobbies is exactly that profile.** Oracle's word is "reclaimed" and it
  does not say whether that means stopped or terminated — the community claim
  that it is only a stop, and that upgrading to pay-as-you-go exempts you, is
  **not confirmed by any Oracle page**. Plan for termination.
- Two more teeth, both from Oracle's own docs: exceed the A1 cap and *"all
  existing OCI Ampere A1 Compute instances are disabled and then deleted after
  30 days, unless you upgrade to a paid account"*; and *"Accounts left idle for
  30 days or more may be deemed abandoned and become eligible for suspension or
  termination."*

### Google Cloud free tier (`e2-micro`)

- **What you get:** `e2-micro` — **1 GB RAM**, and **0.25 of a vCPU presented to
  the guest as 2 vCPUs** (each gets 12.5% of a core), burstable to 100% for 30 s
  at no charge. **x86-64** (Intel or AMD EPYC Milan, chosen for you).
- **Metered in instance-hours, not instances.** Free until the hours used equal
  the hours in the month (~730), summed across regions — enough for exactly one
  VM running 24/7.
- **Regions: `us-west1`, `us-central1`, `us-east1` only.**
  ⚠️ None of them are near Southeast Asia. For players in the Philippines that is
  roughly 200 ms round-trip to US-West before the game does anything, and this
  is a physics-heavy 2v2. This is arguably a bigger problem than the RAM.
- **No ARM in the free tier.** T2A/C4A/N4A do not appear in the free-tier limits.
- **✅ No reclaim.** The free-tier text specifies a **non-preemptible** instance,
  and Google's idle-VM feature is advisory — *"You can use idle VM
  recommendations to find and stop idle VM instances"*, the operator's action,
  not Google's. The only Google-initiated stop is trial expiry at 90 days.
- **⚠️⚠️ EGRESS IS 1 GB PER MONTH.** From North America to all destinations
  *"excluding China and Australia"*, and free egress is **Premium Tier only**.
  For a continuously-streaming UDP game server this is the number most likely to
  end the experiment. **Unmeasured here** — no client traffic was generated
  against a real server — but the arithmetic is worth doing before you commit: if
  a four-player match sends on the order of 100 kB/s outbound, 1 GB is about
  three hours of a single match, per month. Measure it, do not hope.
- **⚠️ The external IPv4 address is not free.** *"This free usage is limited to
  one hour per month per account"* at $0.005/hr — roughly **$3.65/month** (my
  arithmetic, not a quoted figure) for one static or ephemeral IPv4 on the
  otherwise-free VM. External IPv6 and internal IPs are free.
- **30 GB-months** of standard persistent disk. Snapshots are absent from the
  free-tier table; treat them as not free.

### Both

Free-tier terms change and both providers reserve the right to change them
(Google with 30 days' notice). Everything above was checked on 2026-08-02
against the providers' own documentation pages. **Re-read the current free-tier
page before committing.** Oracle's egress allowance was not checked and is not
stated here.

### The short version

| | Oracle A1 | Oracle E2.1.Micro | GCP e2-micro |
| --- | --- | --- | --- |
| Architecture | arm64 — §3 applies | x86-64 | x86-64 |
| RAM | 12 GB (2 OCPU) | 1 GB | 1 GB |
| Can you actually get one | often not | usually | yes |
| Reclaimed when idle | yes, published criteria | yes, same terms | no |
| Latency to PH | pick a nearby region | pick a nearby region | US only, ~200 ms |
| Egress | not checked | not checked | 1 GB/month |
| Hidden cost | — | — | ~$3.65/mo for the IPv4 |

If eight concurrent lobbies is a real requirement, Oracle A1 is the only free
option that fits (§7) — and you have to actually get one.

---

## 5. ⚠️ Firewall: UDP, and BOTH firewalls

This is the second silent failure and it costs people entire afternoons.

**ENet is UDP.** Not TCP. Every diagnostic habit that reaches for `ss -lt`,
`telnet host port` or a TCP health check will report nothing forever while a
perfectly healthy pool is running. Use `ss -lun`.

**A cloud VM has two firewalls and you must open both.** The provider's
network-level rules and the OS's own rules are independent, and opening one
while the other is closed produces the identical symptom: connection times out,
nothing in any log, server clearly running.

### ⚠️ How wide the range has to be

The eight ENet game ports are **8910-8917**. If the build also carries the
online lobby list (`scripts/systems/server_query.gd`), each server additionally
binds a **status port at game port + 10**, so the real range is **8910-8927**.

That file was in-flight parallel work when this was written and had not landed;
check whether it exists before deciding. The failure mode if you get it wrong is
characteristically quiet — matches work perfectly when players type an address,
and the lobby list is simply always empty. Opening 8910-8927 up front costs
nothing and removes the question.

Every command below uses `8910-8917`. Widen it to `8910-8927` if the status
protocol is in your build.

### Oracle — layer 1, the VCN

A **Security List** ingress rule on the subnet, or a **Network Security Group**
attached to the VNIC:

```
Direction:               Ingress
Stateless:               no (leave it stateful)
Source Type / CIDR:      CIDR, 0.0.0.0/0     (narrow it if you can)
IP Protocol:             UDP
Source Port Range:       (blank = all)
Destination Port Range:  8910-8917
```

Oracle's docs confirm a port *range* is accepted here.

### Oracle — layer 2, the image's own firewall

⚠️ **Oracle platform images block by default and this is documented:**
*"Instances created using platform images have a default set of firewall rules
that allow only SSH access."* This catches almost everyone, because on most
other providers the OS side is wide open.

**Oracle Linux / Autonomous Linux — firewalld:**

```bash
sudo firewall-cmd --permanent --add-port=8910-8917/udp
sudo firewall-cmd --reload
```

⚠️ Oracle's own published example is TCP; the `8910-8917/udp` range form is
standard firewalld syntax but is **not** something Oracle documents. Verify with
`sudo firewall-cmd --list-ports`.
⚠️ Oracle warns that on instances with an **iSCSI boot volume**, `--reload` can
cause problems.

**Ubuntu on Oracle — ⚠️⚠️ DO NOT USE `ufw`:**

Oracle's images doc says, plainly: *"Do not use Uncomplicated Firewall (UFW) to
edit firewall rules on an Ubuntu image. Using UFW to edit rules might cause an
instance not to boot."* `ufw` is inactive on these images, but netfilter rules
are present and **do** block — so `ufw status` reporting "inactive" is not
evidence that traffic is allowed. Edit iptables directly:

```bash
sudo iptables -I INPUT 6 -m state --state NEW -p udp --dport 8910:8917 -j ACCEPT
sudo netfilter-persistent save
```

⚠️ The insert position matters. `-I INPUT 6` puts the rule **above** the chain's
REJECT rule; append it instead and it is never reached. Check the numbering with
`sudo iptables -L INPUT -n --line-numbers` first — 6 is Oracle's documented
position for their stock chain, not a universal constant. The `-p udp
--dport 8910:8917` form is standard iptables, but Oracle only publishes the TCP
single-port example, so confirm the rule landed.

⚠️ Do not delete the iSCSI rules for `169.254.0.2:3260` / `169.254.2.0/24:3260`
while you are in there — that exposes the boot volume.

### Google Cloud

The default VPC is **default-deny for ingress**, so nothing works until you add
a rule. (The auto-created `default` network does already allow all TCP and UDP
*internally* within `10.128.0.0/9`, which is worth knowing but does not help an
internet client.)

```bash
gcloud compute firewall-rules create allow-udp-8910-8917 \
  --network=default --direction=INGRESS --priority=1000 \
  --action=ALLOW --rules=udp:8910-8917 \
  --source-ranges=0.0.0.0/0 --target-tags=gameserver
```

- The colon-then-hyphen form (`udp:8910-8917`) is the documented syntax.
- `--allow` and `--action`/`--rules` are mutually exclusive; pick one pair.
- ⚠️ **The instance must actually carry the `gameserver` network tag** or the
  rule matches nothing:
  `gcloud compute instances add-tags <vm> --tags=gameserver`.
  Omit `--target-tags` entirely and the rule applies to *every* instance on the
  network, which is worse than a typo.

OS level on GCE — **unverified either way.** Google's OS-details page never
mentions iptables, ufw or firewalld in the Debian or Ubuntu sections. (The
"all traffic is allowed through the guest firewall" line appears only in the
AlmaLinux/CentOS/RHEL sections and must not be cited for Debian/Ubuntu.) So do
not assume it is open and do not assume it is closed — check on the box:

```bash
sudo iptables -L -n
sudo ufw status
```

### Verifying

From the VM:

```bash
ss -lun | grep 891      # should list one line per lobby
```

From outside, with `nc` (⚠️ `-u`; a UDP "connection" succeeding proves only that
nothing dropped the packet, so absence of an error is weak evidence — the real
test is a game client joining `<ip>:<port>`):

```bash
nc -u -z -v <vm-ip> 8910
```

---

## 6. Keeping it running

### Manual / testing: `lobby-pool.sh`

```bash
export GODOT_BIN=/opt/tumbang-preso/godot
export GAME_PATH=/opt/tumbang-preso/game     # omit if using an exported server binary
export BASE_PORT=8910
export POOL_SIZE=8

./lobby-pool.sh start        # start the whole pool
./lobby-pool.sh start 4      # or just the first four
./lobby-pool.sh status
./lobby-pool.sh stop         # stops every lobby it has a pidfile for
```

Behaviour worth knowing:

- Starting over a live pool is a no-op per port; only dead slots get refilled.
- A port bound by something the pool does not own is refused with a message,
  rather than launched into an "address in use" crash seconds later.
- Each lobby runs under a tiny supervisor subshell that writes a dated exit line
  into that port's log when the process dies. It does **not** restart anything.
- `stop` walks pidfiles, not the configured `POOL_SIZE`, so shrinking the pool
  cannot orphan the lobbies that fell off the end.
- State lives in `$STATE_DIR` (default `~/.local/state/tumbang-preso`): pidfiles
  in `run/`, per-port logs in `log/`.

⚠️ **Two things that go wrong getting the script onto the box**, neither of them
the script's fault:

- **CRLF line endings.** A `#!/bin/sh` line ending in CRLF fails with
  `bad interpreter: /bin/sh^M`, which reads as a missing shell rather than a
  mangled file. The file is committed LF-only, but `.gitattributes` carries no
  `*.sh eol=lf` rule, so nothing enforces it. If you copied it through anything
  Windows-flavoured, run `file lobby-pool.sh` — it should not say "CRLF" — or
  just `sed -i 's/\r$//' lobby-pool.sh`.
- **The executable bit.** `scp` and unzipping both drop it. `chmod +x lobby-pool.sh`.

### Production: systemd

`tools/server/systemd/tumbang-preso-lobby@.service` is a templated unit where
the instance name is the port:

```bash
sudo cp tools/server/systemd/tumbang-preso-lobby@.service /etc/systemd/system/
sudo $EDITOR /etc/systemd/system/tumbang-preso-lobby@.service   # fix the paths
sudo systemctl daemon-reload
sudo systemctl enable --now tumbang-preso-lobby@891{0,1,2,3,4,5,6,7}.service

systemctl status 'tumbang-preso-lobby@*'
journalctl -u tumbang-preso-lobby@8913 -f
```

Templated rather than one unit wrapping the script, because per-process
supervision is the entire point: `Restart=always` is meaningful per lobby, and
`systemctl status tumbang-preso-lobby@8913` answers "is lobby 4 up" with no
parsing. `enable` is what survives the reboot.

⚠️ **The script and the units are alternatives, not layers.** Do not run
`lobby-pool.sh start` on a box where the units are enabled. The port check makes
the second starter refuse rather than corrupt anything, but two supervisors is a
confusing thing to debug.

---

## 7. How much RAM, and how many lobbies fit

### Measured

On the dev machine (Windows 11, `Godot_v4.7.1-stable_win64.exe`, `--headless`,
project run from source, one dedicated lobby with no players connected):

| metric | value |
| --- | --- |
| Working set, steady state | **211–212 MB** |
| Private bytes (commit) | **129 MB** |
| Marginal system commit per additional instance (4 running, 3 stopped) | **214 MB** |
| Drift over a 4½-minute soak, sampled every 30 s | none — 211.6 → 211.5 MB, handles 359 → 355 |

Four instances measured 211.6 / 211.8 / 211.9 / 211.4 MB working set. It is a
very repeatable number.

This is not an empty engine sitting at a menu. `main.gd::_start_hosting` calls
`_fill_empty_slots_with_placeholders()` before the ready phase, so the measured
process has the map loaded, all four seats spawned as AI-driven characters, and
physics running. What it does **not** include is four connected clients and an
active round.

### ⚠️ What this number is not

- **It is Windows, not Linux.** A Linux headless process does not carry the
  Windows working-set overhead, and the numbers will differ.
- **It is the editor binary running from source**, not an exported dedicated
  server. An export strips the editor and the rendering server, so the real
  figure should be **lower** — but by how much is unmeasured.
- **It is an idle lobby.** Four connected peers and a live round were not
  measured; there was no way to drive four clients at a real server in this
  environment.

Treat 215 MB as a **conservative ceiling for planning** and measure again on the
actual target box before filling the pool. `systemd-cgtop` or
`systemctl status tumbang-preso-lobby@8910` will give you the real per-unit
figure in one command.

### Therefore

Using the conservative 215 MB, minus roughly 300–400 MB for the OS on a small
image:

| tier | RAM | lobbies that fit |
| --- | --- | --- |
| Oracle A1, full free allowance (arm64) | 12 GB | **~50 on RAM alone** — the 8-lobby pool fits several times over |
| Oracle A1, one 1-OCPU half | 6 GB | **~25 on RAM** — the full pool fits comfortably |
| Oracle `E2.1.Micro` (x86-64) | 1 GB | **2, maybe 3.** Not 8. |
| GCP `e2-micro` (x86-64) | 1 GB | **2, maybe 3.** Not 8. |

⚠️ **Neither free x86 option fits the intended eight-lobby pool.** On 1 GB you
get two or three concurrent matches, and `POOL_SIZE` should be set to match
rather than letting the eighth process be OOM-killed mid-round. Eight concurrent
lobbies on a free tier means Oracle A1 — and therefore §3 and the A1 capacity
lottery in §4.

⚠️ **RAM is almost certainly not the binding constraint on A1, and the real one
is unmeasured.** Two OCPUs will not run fifty physics simulations. CPU was not
measured at all, on any tier, and neither was network. On a shared-core
`e2-micro` (0.25 vCPU) even three simultaneous matches may exhaust the CPU
allowance long before the RAM — and on GCP, 1 GB of monthly egress (§4) is a
harder ceiling than either. Do not read the table above as a capacity plan; it
is a RAM floor and nothing else.

---

## 8. Rough edges to know about

Read from the source, not observed on a deployed server:

- **`LanBeacon` advertises the wrong port.** Every host broadcasts a discovery
  packet whose payload hardcodes `NetworkManagerScript.DEFAULT_PORT` (8910),
  regardless of what `--port=` it was actually given. Harmless on a cloud VM —
  nobody is on that broadcast domain and players connect by typed address — but
  it means LAN discovery cannot see a pool correctly, and seven of eight
  advertisements are wrong.
- **`DISCOVERY_PORT` is 8911, inside the pool range.** No conflict in practice:
  a server only *sends* to 8911, and the listener that *binds* it is started
  only by the client-side browse screen (`multiplayer_setup.gd`). Worth knowing
  before anyone widens the pool range or adds a beacon listener to the server.
- **Godot logs allocator noise on SIGTERM.** `ERROR: Pages in use exist at exit
  in PagedAllocator` appears in the log of every cleanly stopped lobby. Observed
  on every `stop` during testing; it is shutdown noise, not a fault.
- **Matchmaking is arriving separately.** As of writing, nothing tells a player
  which of the eight ports is free — they type a port. `scripts/systems/server_query.gd`
  was in-flight parallel work adding a UDP status protocol and lobby list, and
  it changes two things here: each server binds a second socket at game port +
  10 (see §5), and the pool range is a compile-time constant in that file, so
  growing the pool past its `POOL_PORT_FIRST`/`POOL_PORT_LAST` means shipping a
  build, not editing `BASE_PORT`. Re-read that file before changing the port
  layout in `lobby-pool.sh`.

---

## 9. First deployment, start to finish

```bash
# 1. Create the VM.
#    Match the Godot binary's architecture to it — §3. On Ampere that is arm64.
# 2. Provider firewall: UDP 8910-8917 ingress. §5.
# 3. On the box:
sudo useradd -r -m -d /var/lib/gameserver gameserver
sudo mkdir -p /opt/tumbang-preso
# ...copy the Godot binary to /opt/tumbang-preso/godot
# ...copy the project (or exported server) to /opt/tumbang-preso/game
sudo chmod +x /opt/tumbang-preso/godot
/opt/tumbang-preso/godot --version     # runs at all? wrong-arch binaries die here.

# 4. OS firewall — the command depends on the image. §5.
#    ⚠️ NOT `ufw` on Oracle's Ubuntu images: it can stop the instance booting.

# 5. Prove ONE lobby works before installing anything else.
/opt/tumbang-preso/godot --headless --path /opt/tumbang-preso/game \
    res://scenes/ui/MatchSetup.tscn -- --dedicated --port=8910
#    ^ in another shell: ss -lun | grep 8910   -> must show a line.
#      If it does not, re-read §2 before doing anything else.

# 6. Then join it from a real client at <vm-ip>:8910 — the only test that
#    covers both firewalls. `nc -u -z` proves almost nothing about UDP.
#    Type the ADDRESS for this one: it is the only path that does not depend
#    on POOL_ADDRESS being set yet. §2b.

# 7. Then the pool, then systemd.

# 8. ⚠️ Then point the GAME at the box — §2b. Set POOL_ADDRESS in
#    scripts/systems/server_query.gd to the VM's address and rebuild.
#    Until this is done HOST ONLINE, the server browser and join codes are
#    all switched off in every copy of the game, however healthy the pool is.

# 9. Prove it from a client BEFORE handing builds out: press HOST ONLINE,
#    read the four-character code off the lobby, and join it from a second
#    machine on a DIFFERENT network — not a second window on the same one.
#    Loopback and a shared router both skip the NAT this whole design exists
#    to get around.
```

Step 5 is not optional ceremony. Every silent failure in this document produces
a process that looks fine; the only cheap thing that distinguishes a working
lobby from a broken one is whether the UDP port is bound.

Steps 8 and 9 are the two that get skipped because the pool looks finished
without them. A pool nobody's build can see is indistinguishable from no pool.

---

## 10. What was actually verified

Written 2026-08-02. This section exists so nobody has to guess which parts of
this document are measurements and which are reading.

### Run and measured, on the dev machine (Windows 11, Godot 4.7.1)

- The `--dedicated --port=` launch form starts a server that binds its UDP port.
- ⚠️ **The missing-scene-path failure**, reproduced deliberately: process alive
  18 s, engine banner only, port never bound. §2 is a measurement, not a warning.
- Per-instance memory, four concurrent instances, and a 4½-minute soak. §7.
- `lobby-pool.ps1`: start, status, stop, restart-over-a-live-pool, refusal of a
  foreign-owned port, detection and logging of a hard-killed lobby, refilling
  only the dead slot, `stop` twice in a row, and all ports released afterwards.
- `lobby-pool.sh`: syntax-checked with `sh -n`, then actually run under Git Bash
  against the real project. Started two lobbies, both bound their ports; a
  `kill -9` produced `port 8965 exited with status 137` in that port's log and
  removed the pidfile; `stop` produced status 143 and released both ports; a
  second `stop` was a clean no-op; a bad `GODOT_BIN` failed preflight.
- **The player's path, against two real dedicated lobbies on loopback**
  (`tools/ui/host_online_shot.gd`): the browser listed both over a real UDP
  round trip; HOST ONLINE picked the free one; the claiming peer became lobby
  leader; and the code the lobby displayed (`56EH`, `T2WK`, … it is minted per
  run) matched the code that server had advertised.

### ⚠️ NOT verified, and it is the part that matters most

**Nothing here has crossed a real network.** Every measurement above is
loopback: no NAT, no packet loss, no MTU limit, sub-millisecond latency. The
entire reason this design exists is to get four people on four home connections
into one game, and that is precisely the condition not yet tested. Until step 9
of §9 has been done from two different networks, treat "it works" as meaning
"it works on one machine".

### Read from the source, not run

- One process = one match (autoload lifetime), and what `--dedicated` changes.
- Clients reach a specific port by typing `<ip>:<port>` — `split_address()` in
  `multiplayer_setup.gd`.
- Everything in §8.

### Taken from provider and Godot documentation, not tested

Everything in §3, §4 and §5. Each claim carries its source in place; the ones
that could **not** be confirmed are marked as such and repeated here:

- **Nobody opened the released `.tpz`** to confirm `linux_release.arm64` is
  physically in it. The evidence is Godot's official 4.7-branch build script.
  Check the archive before provisioning ARM.
- Whether Linux arm64 templates have shipped continuously since 4.0 — verified
  for 4.7 only.
- Oracle: the size of the card authorisation hold; whether "reclaimed" means
  stopped or terminated; whether a pay-as-you-go upgrade exempts you; any
  Oracle-sanctioned workaround for A1 capacity beyond retrying; and
  Oracle-published **UDP** firewall syntax for either image family — only TCP
  examples exist, so the UDP range forms in §5 are standard syntax that Oracle
  itself does not document.
- Oracle's egress allowance was not researched at all.
- GCP: whether the stock Debian/Ubuntu images run a host firewall — the docs are
  silent, so §5 says to check on the box rather than citing anything.
- The ~$3.65/month external-IPv4 figure is arithmetic on a published hourly
  rate, not a quoted monthly price.

### Not verified by anyone, and load-bearing

- **CPU cost per lobby. Zero measurements, on any platform.** The capacity table
  in §7 is RAM only and will overstate what a shared-core instance can do.
- **Network cost per lobby.** No client traffic was ever generated against a
  real server, so the GCP 1 GB/month egress ceiling in §4 has not been tested
  against reality. On the free GCP tier this is probably the first thing to
  break.
- **Anything on real Linux.** No Linux machine was involved at any point. The
  shell script was exercised under Git Bash on Windows, which shares its syntax
  but not its process model, signals, or `ss`.
- **A four-player match against a pooled server**, from a client on the internet.
