extends CharacterBody3D

signal health_changed(health_value)
signal ammo_changed(current_ammo)

# Set enumuration values reflect player's current camera view state
enum DynamicCameraViewToggleAction {
	FIRST_PERSON_VIEW,
	THIRD_PERSON_VIEW
}

# First Player View (FPP)
@onready var fpp_camera: Camera3D = $FPPCamera
@onready var fpp_raycast: RayCast3D = $FPPCamera/FPPRayCast3D

@onready var fpp_pistol: Node3D = $FPPCamera/FPPPistol
@onready var fpp_ak47: Node3D = $FPPCamera/FPPAK47
@onready var fpp_knife: Node3D = $FPPCamera/FPPKnife

@onready var fpp_pistol_muzzle_flash: GPUParticles3D = $FPPCamera/FPPPistol/MuzzleFlash
@onready var fpp_ak47_muzzle_flash: GPUParticles3D = $FPPCamera/FPPAK47/MuzzleFlash

# Third Player View (TPP)
@onready var tpp_camera: Camera3D = $TPPCamera
@onready var tpp_raycast: RayCast3D = $TPPCamera/TPPRayCast3D

@onready var tpp_pistol: Node3D = $TPPCamera/TPPPistol
@onready var tpp_ak47: Node3D = $TPPCamera/TPPAK47
@onready var tpp_knife: Node3D = $TPPCamera/TPPKnife

@onready var tpp_pistol_muzzle_flash: GPUParticles3D = $TPPCamera/TPPPistol/MuzzleFlash
@onready var tpp_ak47_muzzle_flash: GPUParticles3D = $TPPCamera/TPPAK47/MuzzleFlash

# Animations
@onready var anim_player: AnimationPlayer = $AnimationPlayer

# Teleport
@onready var teleport_point: Node3D = $FPPCamera/TelePoint

# Set player's current camera view state in the editor
@export var camera_player_state: DynamicCameraViewToggleAction = DynamicCameraViewToggleAction.FIRST_PERSON_VIEW

# Set positon for the camera when zoomed in or out
@export var zoom_in_position: Vector3 = Vector3(0, 3, -8)
@export var zoom_out_position: Vector3 = Vector3(0, 3, 0)

var health: int = 10
var MAX_HEALTH: int = 10
var max_ammo: int = 30
var current_ammo: int = max_ammo
var is_reloading: bool = false
var reload_time: float = 2.0  # Time in seconds to reload

const HEALTH_AMOUNTS: int = 2
const SPEED: float = 13.0
const JUMP_VELOCITY: float = 10.0

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity: float = 25.0

# Track different state of camera node to toggle either FPP or TPP.
var is_fpp: bool = true

# Track the current weapon
var current_weapon: String = ""

# Set the coordination value that teleportation feature will use to make it happens
var teleport_final_destination: Vector3

func _enter_tree():
	set_multiplayer_authority(str(name).to_int())


func _ready():
	#Global.player = self
	# Connect new 'weapon_switched' signal from the Global script
	var callable_gun_signal = Callable(self, "_on_weapon_switched")
	Global.connect("weapon_switched", callable_gun_signal)
	
	if not is_multiplayer_authority(): return
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Initialize camera and gun visibility based on the editor setting
	update_camera_visibility()
	update_weapon_model_visibility()


func _unhandled_input(event):
	if not is_multiplayer_authority(): return

	if event is InputEventMouseMotion:
		# FPP camera
		if is_fpp:
			rotate_y(-event.relative.x * .005)
			fpp_camera.rotate_x(-event.relative.y * .005)
			fpp_camera.rotation.x = clamp(fpp_camera.rotation.x, -PI/2, PI/2)
		# TPP camera
		else:
			rotate_y(-event.relative.x * .005)
			tpp_camera.rotate_x(-event.relative.y * .005)
			tpp_camera.rotation.x = clamp(tpp_camera.rotation.x, -PI/2, PI/2)

	if Input.is_action_just_pressed("shoot"):
		#print("shoot")
		current_ammo -= 1 
		print("Bang! Ammo left: ", current_ammo)
		ammo_changed.emit(current_ammo)
		if is_reloading:
			if current_ammo<= 0:
				print("Out of ammo! Reload needed.")
				return #is needed otherwise can shoot without Ammo 
		play_shoot_effects.rpc()
		if is_fpp and fpp_raycast.is_colliding():
			var hit_player = fpp_raycast.get_collider()
			hit_player.receive_damage.rpc_id(hit_player.get_multiplayer_authority())

		elif not is_fpp and tpp_raycast.is_colliding():
			var hit_player = tpp_raycast.get_collider()
			hit_player.receive_damage.rpc_id(hit_player.get_multiplayer_authority())


func reload():
	var _is_reloading = true
	print("Reloading...")
	await get_tree().create_timer(reload_time).timeout
	current_ammo = max_ammo
	is_reloading = false
	print("Reloaded! Ammo refilled to: ", current_ammo)


func _physics_process(delta):
	#print(health)
	Global.ammo = current_ammo
	
	if not is_multiplayer_authority(): return
	
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle Jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("left", "right", "up", "down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	if anim_player.current_animation == "shoot":
		pass
	elif input_dir != Vector2.ZERO and is_on_floor():
		anim_player.play("move")
	else:
		anim_player.play("idle")

	move_and_slide()
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		if collision.get_collider().is_in_group("pickup"):
			print("pickup collided.")
			if "AmmoBox" in collision.get_collider().name:
				add_ammo(10)
				# Add to Ammo instead.
				print("I collided with ", collision.get_collider().name)
				add_health(1)
				collision.get_collider().queue_free()
			if "Health" in collision.get_collider().name:
				print("I collided with ", collision.get_collider().name)
				add_health(5)
				collision.get_collider().queue_free()


# Get defined key inputs
func _input(event):
# Switch guns in inventory slot according to the key inputs set for it
	if event.is_action_pressed("inventory_slot_1"):
		Global.switch_weapon(1)
	elif event.is_action_pressed("inventory_slot_2"):
		Global.switch_weapon(2)
	elif event.is_action_pressed("inventory_slot_3"):
		Global.switch_weapon(3)

# Switch player's camera view according to the key inputs set for it
	if event.is_action_pressed("dynamic_camera_view"):
		toggle_different_camera_state();

# Reload weapon's ammo according to the key inputs set for it 
	if event.is_action_pressed("reload"):
		reload()

# Change player's camera positon according to the key inputs set for it 
	if event.is_action_pressed("zoom"):
		if is_multiplayer_authority():
			#print("Zoom key clicked")
			fpp_camera.position = zoom_in_position
			
			# Hide weapon models when zoomed in based on what view mode is choosen
			if is_fpp:
				match current_weapon:
					"Glock-19":
						fpp_pistol.visible = false
					"AK-47":
						fpp_ak47.visible = false
					"Knife":
						fpp_knife.visible = false
		
			## Just leave it here 'cause we don't do zoom in in TPP. Might need in future anyways.
			#else:
				#match current_weapon:
					#"Glock-19":
						#tpp_pistol.visible = false
					#"AK-47":
						#tpp_ak47.visible = false
					#"Knife":
						#tpp_knife.visible = false
			
	elif event.is_action_released("zoom"):
		if is_multiplayer_authority():
			#print("Zoom key released")
			fpp_camera.position = zoom_out_position
			
			# Show weapon models when zoomed out based on what view mode is choosen	
			if is_fpp:
				match current_weapon:
					"Glock-19":
						fpp_pistol.visible = true
					"AK-47":
						fpp_ak47.visible = true
					"Knife":
						fpp_knife.visible = true
		
			## Just leave it here 'cause we don't do zoom out in TPP. Might need in future anyways.
			#else:
				#match current_weapon:
					#"Glock-19":
						#tpp_pistol.visible = true
					#"AK-47":
						#tpp_ak47.visible = true
					#"Knife":
						#tpp_knife.visible = true
	
	if event.is_action_pressed("teleport"):
		if is_multiplayer_authority():
			if is_fpp:
				#print("Teleport button worked!")
				teleport_point.visible = true

				# Perform a raycast to find the teleportation destination
				if fpp_raycast.is_colliding():
					# Set the teleportation destination to the hit position
					teleport_final_destination = fpp_raycast.get_collision_point()
					print("Raycast hit position: ", fpp_raycast.get_collision_point())

					# Move the teleportation destination model to the hit position
					teleport_point.global_position = teleport_final_destination				
					print("Teleport destination: ", teleport_final_destination)
				
			else:
				print("You are not allowed to do this in TPP!")

	elif event.is_action_released("teleport"):
		if is_multiplayer_authority():
			if is_fpp:
				#print("Teleport button got released!")
				teleport_point.visible = false
		
				# Call the teleportation function with the destination position
				teleport_to_position(teleport_final_destination)
				print("Current player position: ", teleport_to_position(teleport_final_destination))
			
			else:
				# Block the feature to run in TPP view mode
				print("You are not allowed to do this in TPP!")


@rpc("call_local")
func play_shoot_effects():
	anim_player.stop()
	anim_player.play("shoot")
	if is_fpp:
		if current_weapon == "Glock-19":
			fpp_pistol_muzzle_flash.restart()
			fpp_pistol_muzzle_flash.emitting = true
		elif current_weapon == "AK-47":
			fpp_ak47_muzzle_flash.restart()
			fpp_ak47_muzzle_flash.emitting = true
	else:
		if current_weapon == "Glock-19":
			tpp_pistol_muzzle_flash.restart()
			tpp_pistol_muzzle_flash.emitting = true
		elif current_weapon == "AK-47":
			tpp_ak47_muzzle_flash.restart()
			tpp_ak47_muzzle_flash.emitting = true


@rpc("any_peer")
func receive_damage():
	health -= 1
	print("damage taken")
	if health <= 0:
		print("Game Over!")
		# Reset the player's health and position
		health = MAX_HEALTH
		position = Vector3.ZERO
		# Emit the health_changed signal with the reset health value
		health_changed.emit(health)
	else:
		# Emit the health_changed signal with the updated health value
		health_changed.emit(health)


func _on_animation_player_animation_finished(anim_name):
	if anim_name == "shoot":
		anim_player.play("idle")


func add_health(additional_health):
	health += additional_health
	health_changed.emit(health)


func add_ammo(additional_ammo):
	current_ammo += additional_ammo
	ammo_changed.emit(current_ammo)


#func t_body_entered(body):
	##if_area_is_in_group("player")
	#print("added_Health")
	#if body.has_method("add_health"):
		#body.add_health(HEALTH_AMOUNTS)


# Handle weapon switching based on the key inputs
func _on_weapon_switched(weapon_name):
	print("Switched to weapon: %s" % weapon_name)
	current_weapon = weapon_name
	update_weapon_model_visibility()


# Handle diffrent state of player's camera view
func toggle_different_camera_state():
	is_fpp = not is_fpp
	update_camera_visibility()
	update_weapon_model_visibility()


# Update player's camera view when player pressed the pre-defined key input
func update_camera_visibility():
	if is_multiplayer_authority():
		fpp_camera.current = is_fpp
		tpp_camera.current = not is_fpp


##################################################################################################################
######      Documentation about synchronising weapon models into multiplayer game in a correct way          ######
##################################################################################################################

## - To prevent the bug where let's say you have 2 player in the multiplayer room, 'Player 1' clicked the key 
##   bind '1' --> that weapon model shows on both 'Player 1' and 'Player 2' character model, but not for the 
##   'Player 2's screen, STRICTLY follow the instruction below to not letting that happens again (I have already 
##   fix it):
##
##		+ Add new weapon models into the 'Player Scene Tree' (the thing on your left if you don't know the term 
##		  for it) under each of the view mode: TPP and FPP (remember to re-name them as how the naming is written 
##		  inside each view mode). 
##
##		  **If you unsure on how to add new weapon models into the 'Player Scene Tree', have a look at the 
##		  'world.gd' file and read the documentation in there. It's very detailise and it should help you to be 
##		  able to achieve this action (although it's not related to the weapon models, but it should be similar 
##		  about the node setup).**
##
##		+ Then, click on the 'MultiplayerSynchronizer' Node (at the end of the 'Player Scene Tree') or click on 
##		  the 'Replication' section (right at the bottom of your eye view if you don't see it)
##
##		+ After that, click on the 'Add property to sync...' button (It's the big ass '+' symbol if you don't see 
##		  it).
##
##		+ After you clicked the button, it'll pop-up and show you the 'Player Scene Tree'. Don't be panic about 
##		  all of the stuff in there yet, this documentation is where your life'll be easier. Clicks on your new 
##		  weapon model (both TPP and FPP view mode, do it one by one because Godot won't let you to be a 'I'm 
##		  fast as fuck boiz').
##
##		+ After you clicked the new weapon model respectively, it'll pop-up and show you all the options that you 
##		  can choose to synchronise across all player. It's alright if you don't get wtf it's happening in 
##		  there, just mindlessly follow this upcoming step to have a happy dev life (you can test out the other 
##		  options on your own if you wanted to). Clicks on the 'visible' property (it's under the 'Node3D' 
##		  section if you don't see it), and do the same for your new weapon models in both view mode.
##
##		+ You have officially made it if you followed the step correctly up to this point. Hooray!

##################################################################################################################
######             End of the Documentation. You may freely to continue working on this now!                ######
##################################################################################################################


# Update the visibility of guns when player changed the camera view based on their preferrance
func update_weapon_model_visibility():
	#print("Updating weapon model visibility")

	# Hide all weapon models
	fpp_pistol.visible = false
	fpp_ak47.visible = false
	fpp_knife.visible = false
	tpp_pistol.visible = false
	tpp_ak47.visible = false
	tpp_knife.visible = false

	# Show the weapon model that corresponds to the currently selected weapon and is owned by the current player
	if is_multiplayer_authority():
		match current_weapon:
			"Glock-19":
				if is_fpp:
					fpp_pistol.visible = true
				else:
					tpp_pistol.visible = true
			"AK-47":
				if is_fpp:
					fpp_ak47.visible = true
				else:
					tpp_ak47.visible = true
			"Knife":
				if is_fpp:
					fpp_knife.visible = true
				else:
					tpp_knife.visible = true

	#print("FPP Pistol Visible: ", fpp_pistol.visible)
	#print("FPP AK47 Visible: ", fpp_ak47.visible)
	#print("FPP Knife Visible: ", fpp_knife.visible)
#
	#print("TPP Pistol Visible: ", tpp_pistol.visible)
	#print("TPP AK47 Visible: ", tpp_ak47.visible)
	#print("TPP Knife Visible: ", tpp_knife.visible)


func teleport_to_position(final_destination_position):
	# Set the player's position to the destination position
	position = final_destination_position

	# Hide the teleportation destination model
	teleport_point.visible = false
