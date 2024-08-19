extends Node

@onready var main_menu = $CanvasLayer/MainMenu
@onready var address_entry = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/AddressEntry
@onready var hud = $CanvasLayer/HUD
@onready var health_bar = $CanvasLayer/HUD/HealthBar


## Documentation about using different type of characters
##
## - This one down here is the original code to make that happens:
##		const Player = preload("res://player.tscn")
##
## - For any new character models, inherance the 'normal_declan.tscn' file and change the 
##   'Albedo' texture + adjust the animation in 'AnimationPlayer' node (if needed).
##
## - Then, preload that new model as below:
##		const Player = preload("res://models/characters/<model-name>.tscn")


const Player = preload("res://models/characters/normal_declan.tscn")
const PORT = 9999
var enet_peer = ENetMultiplayerPeer.new()

#func _on_weapon_switched(gun_name):
	


func _on_weapon_switched(gun_name):
	if(gun_name == 'AK-47'):
		get_node('CanvasLayer/HUD/AK-47').texture = load('res://AK-47-Active.png')
		get_node('CanvasLayer/HUD/Glock-19').texture = load('res://Glock-19.png')
	elif(gun_name == 'Glock-19'):
		get_node('CanvasLayer/HUD/Glock-19').texture = load('res://Glock-19-Active.png')
		get_node('CanvasLayer/HUD/AK-47').texture = load('res://AK-47.png')
	#print("Switched to gun: %s" % gun_name)

func _ready():
	var callable_gun_signal = Callable(self, "_on_weapon_switched")
	Global.connect("weapon_switched", callable_gun_signal)
	#print(callable_gun_signal)

	if OS.get_name()=="macOS":
		DisplayServer.window_set_size(Vector2i(1920, 1080))



func _unhandled_input(event):
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()

func _on_host_button_pressed():
	main_menu.hide()
	hud.show()
	
	enet_peer.create_server(PORT)
	multiplayer.multiplayer_peer = enet_peer
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(remove_player)
	
	add_player(multiplayer.get_unique_id())
	
	# Commented out to remove required uPNP functionality
	# uPNP does not work on the school network.
	#upnp_setup()

func _on_join_button_pressed():
	main_menu.hide()
	hud.show()
	
	enet_peer.create_client(address_entry.text, PORT)
	multiplayer.multiplayer_peer = enet_peer

func add_player(peer_id):
	var player = Player.instantiate()
	player.name = str(peer_id)
	add_child(player)
	if player.is_multiplayer_authority():
		player.health_changed.connect(update_health_bar)

func remove_player(peer_id):
	var player = get_node_or_null(str(peer_id))
	if player:
		player.queue_free()

func update_health_bar(health_value):
	health_bar.value = health_value

func _on_multiplayer_spawner_spawned(node):
	if node.is_multiplayer_authority():
		node.health_changed.connect(update_health_bar)

func upnp_setup():
	var upnp = UPNP.new()
	
	var discover_result = upnp.discover()
	assert(discover_result == UPNP.UPNP_RESULT_SUCCESS, \
		"UPNP Discover Failed! Error %s" % discover_result)

	assert(upnp.get_gateway() and upnp.get_gateway().is_valid_gateway(), \
		"UPNP Invalid Gateway!")

	var map_result = upnp.add_port_mapping(PORT)
	assert(map_result == UPNP.UPNP_RESULT_SUCCESS, \
		"UPNP Port Mapping Failed! Error %s" % map_result)
	
	print("Success! Join Address: %s" % upnp.query_external_address())
