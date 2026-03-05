extends Node

var player: Node3D # We leave this empty for now

func register_player(p):
	player = p
	# Now that we have the player, tell the enemies!
	get_tree().call_group("enemies", "set_player", player)
