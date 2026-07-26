extends Node
class_name NetworkManagerScript

## Intended as an autoload singleton named "NetworkManager" (Project Settings > Autoload)
## once Phase 3 (Networking) starts — see Dev_Plan_and_Godot_Setup.md Part 1.
## Gameplay scripts should call functions on this manager without caring whether they're
## the host or a client; this manager decides whether that becomes an RPC or a local call.
##
## - Host-authoritative: Downed state, seal/capture checks, timer, score.
## - Client-predicted: movement, synced via MultiplayerSynchronizer, host validates hits.
##
## LAN only — no relay/NAT needed. Test with Debug > Run Multiple Instances before
## testing across real devices.

const DEFAULT_PORT: int = 8910
const MAX_PLAYERS: int = 4

var peer: ENetMultiplayerPeer

func host_game() -> Error:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(DEFAULT_PORT, MAX_PLAYERS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK

func join_game(ip_address: String) -> Error:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(ip_address, DEFAULT_PORT)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK

func is_host() -> bool:
	return multiplayer.is_server()
