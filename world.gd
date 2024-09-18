extends Node

@onready var main_menu = $CanvasLayer/MainMenu
@onready var address_entry = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/AddressEntry
@onready var hud = $CanvasLayer/HUD
@onready var ipLabel = $CanvasLayer/HUD/IP/Label
@onready var ipSprite = $CanvasLayer/HUD/IP
@onready var health_bar = $CanvasLayer/HUD/HealthBar
var ip_address
##################################################################################################################
######                          Documentation about using different type of characters                      ######
##################################################################################################################

## - This one down here is the original code to make that happens:
##		const Player = preload("res://player.tscn")
##
## - For any new character models, inherance the 'normal_declan.tscn' file. Then, change the 
##   'Albedo' texture: 

##		(click on the model in 'Scene Tree' --> expand it out and find the 'MeshInstance3D' Node (the box-looking 
##		symbol if you don't know the term for it) --> click on it -->  click on the 'Geometry' drop-down option
##		--> click on 'Material Override' drop-down option --> choose 'New StandardMaterial3D' option --> expand 
##		it out and find 'Albedo' drop-down option --> click on it and find 'Texture' option --> drag your .png 
##		(or .jpg, or .jpeg [.webp won't work, you'll have to convert it using any online tools]) file that comes 
##		with the .fbx file into this option --> (if the texture not loaded properly after you dragged it in, 
##		enable the 'Texture Force sRGB' button. It should fix it. If not, try the 'Texture MSDF' button) --> 
##		done!)  

## - After you finish doing all of that, adjust the animation in 'AnimationPlayer' node (if the model does comes 
##   with animation).
##
## - Then, preload that new model as below:
##		const Player = preload("res://models/characters/<model-name>.tscn")
##
##		**Applied the same concept for any new weapon models, right click on the .fbx file and click on the 'New 
##		Inherited Scene' button. Then, re-name the 'Node' name in the 'Weapon Scene Tree' (the thing on your left 
##		if you don't know the term for it) into the correct name that reflect the new model you added in this 
##		project. After that, use 'Ctrl + S' combinantion key bind or right click on the '[unsaved]' scene (right 
##		at the top of your eye view if you don't see it), and click 'Save Scene As...' button (for the 'right 
##		click' method), or rename the .tscn file, which Godot given you when you try to save with the combination 
##		key bind, into the correct naming that reflect the new weapon model you added in this project. Put them 
##		into to somewhere that you think it's easy to navigate for you and everyone. Then, you can follow the 
##		step to inherance the new weapon's .tscn file into the 'Chacracter Scene Tree' just right above this 
##		comment. Although it's not directly for the character model, but it should relavantly the same setup that 
##		you can follow through. At this point, you have successfully done this if you follow the step correctly. 
##		Hooray!**

##################################################################################################################
######             End of the Documentation. You may freely to continue working on this now!                ######
##################################################################################################################

const Player = preload("res://models/characters/normal_declan.tscn")
const PORT = 9999
var enet_peer = ENetMultiplayerPeer.new()

#func _on_weapon_switched(gun_name):
	

func _physics_process(delta):
	# Assuming Global.ammo is a valid global variable
	var currentammo_label = get_node("CanvasLayer/HUD/AmmoBox/CurrentAmmo")
	currentammo_label.text = str(Global.current_ammo)  # Convert to string if needed
	var spareammo_label = get_node("CanvasLayer/HUD/AmmoBox/SpareAmmo")
	spareammo_label.text = str(Global.spare_ammo)


func _on_weapon_switched(gun_name):
	if(gun_name == 'AK-47'):
		get_node('CanvasLayer/HUD/AK-47').texture = load('res://images/AK-47-Active.png')
		get_node('CanvasLayer/HUD/Glock-19').texture = load('res://images/Glock-19.png')
		get_node('CanvasLayer/HUD/CombatKnife').texture = load('res://images/CombatKnife.png')
	elif(gun_name == 'Glock-19'):
		get_node('CanvasLayer/HUD/Glock-19').texture = load('res://images/Glock-19-Active.png')
		get_node('CanvasLayer/HUD/AK-47').texture = load('res://images/AK-47.png')
		get_node('CanvasLayer/HUD/CombatKnife').texture = load('res://images/CombatKnife.png')
	elif(gun_name == 'Knife'):
		get_node('CanvasLayer/HUD/Glock-19').texture = load('res://images/Glock-19.png')
		get_node('CanvasLayer/HUD/AK-47').texture = load('res://images/AK-47.png')
		get_node('CanvasLayer/HUD/CombatKnife').texture = load('res://images/CombatKnife-Active.png')
	#print("Switched to gun: %s" % gun_name)

func get_local_ip() -> String:
	var ip = ""
	for address in IP.get_local_addresses():
		if "." in address and not address.begins_with("127.") and not address.begins_with("169.254.") and not address.begins_with("192.168."):
			if address.begins_with("10.") or (address.begins_with("172.") and int(address.split(".")[1]) >= 16 and int(address.split(".")[1]) <= 31):
				ip = address
				break
	return ip

func _ready():
	var callable_gun_signal = Callable(self, "_on_weapon_switched")
	Global.connect("weapon_switched", callable_gun_signal)
	#print(callable_gun_signal)
	
	ip_address = get_local_ip()

	if OS.get_name()=="macOS":
		DisplayServer.window_set_size(Vector2i(1920, 1080))



func _unhandled_input(event):
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()

func _on_host_button_pressed():
	main_menu.hide()
	hud.show()
	#get_node("CanvasLayer/HUD/ip").text = "test"
	#ipLabel = $CanvasLayer/HUD/IP/Label
	ipSprite.visible = true
	#print(ipLabel)
	ipLabel.text = ip_address
	
	
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
