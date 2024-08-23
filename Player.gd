extends CharacterBody3D

signal health_changed(health_value)

# Set enumuration values reflect player's current camera view state
enum DynamicCameraViewToggleAction {
	FIRST_PERSON_VIEW,
	THIRD_PERSON_VIEW
}

# First Player View (FPP)
@onready var fpp_camera: Camera3D = $FPPCamera
@onready var fpp_muzzle_flash: GPUParticles3D = $FPPCamera/FPPPistol/MuzzleFlash
@onready var fpp_raycast: RayCast3D = $FPPCamera/FPPRayCast3D

@onready var fpp_pistol: Node3D = $FPPCamera/FPPPistol
@onready var fpp_ak47: Node3D = $FPPCamera/FPPAK47
@onready var fpp_knife: Node3D = $FPPCamera/FPPKnife

# Third Player View (TPP)
@onready var tpp_camera: Camera3D = $TPPCamera
@onready var tpp_muzzle_flash: GPUParticles3D = $TPPCamera/TPPPistol/MuzzleFlash
@onready var tpp_raycast: RayCast3D = $TPPCamera/TPPRayCast3D

@onready var tpp_pistol: Node3D = $TPPCamera/TPPPistol
@onready var tpp_ak47: Node3D = $TPPCamera/TPPAK47
@onready var tpp_knife: Node3D = $TPPCamera/TPPKnife

# Multiplayer Synchronizer
@onready var multiplayer_sync: MultiplayerSynchronizer = $MultiplayerSynchronizer

# Animations
@onready var anim_player: AnimationPlayer = $AnimationPlayer

# Set player's current camera view state in the editor
@export var camera_player_state: DynamicCameraViewToggleAction = DynamicCameraViewToggleAction.FIRST_PERSON_VIEW

var health = 3
var MAX_HEALTH = 10
var Ammo_Weapon = 10
var Fully_Loaded_Weapon = 10 
var spare_ammo = 10

var Ammo_In_Weapon = 3
const HEALTH_AMOUNTS = 2
const SPEED = 10.0
const JUMP_VELOCITY = 10.0

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = 25.0

# Track different state of camera node to toggle either FPP or TPP.
var is_fpp: bool = true

# Track the current weapon
var current_weapon: String = ""

# Store initial visibility states
var initial_fpp_pistol_visible: bool = false
var initial_fpp_ak47_visible: bool = false
var initial_fpp_knife_visible: bool = false

var initial_tpp_pistol_visible: bool = false
var initial_tpp_ak47_visible: bool = false
var initial_tpp_knife_visible: bool = false


func _enter_tree():
	set_multiplayer_authority(str(name).to_int())


func _ready():
	
	# Connect new 'weapon_switched' signal from the Global script
	var callable_gun_signal = Callable(self, "_on_weapon_switched")
	Global.connect("weapon_switched", callable_gun_signal)
	
	if not is_multiplayer_authority(): return
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
		# Store initial visibility states
	initial_fpp_pistol_visible = fpp_pistol.visible
	initial_fpp_ak47_visible = fpp_ak47.visible
	initial_fpp_knife_visible = fpp_knife.visible

	initial_tpp_pistol_visible = tpp_pistol.visible
	initial_tpp_ak47_visible = tpp_ak47.visible
	initial_tpp_knife_visible = tpp_knife.visible
	
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

	if Input.is_action_just_pressed("shoot") and anim_player.current_animation != "shoot":
		Ammo_Weapon -= 1 
		if Ammo_Weapon < 0:
			print("empty")
			print("failure")
			return
		#play_shoot_effects.rpc()
		if is_fpp and fpp_raycast.is_colliding():
			var hit_player = fpp_raycast.get_collider()
			hit_player.receive_damage.rpc_id(hit_player.get_multiplayer_authority())

		elif not is_fpp and tpp_raycast.is_colliding():
			var hit_player = tpp_raycast.get_collider()
			hit_player.receive_damage.rpc_id(hit_player.get_multiplayer_authority())

func Reload():
	var ammo_needed = Fully_Loaded_Weapon - Ammo_In_Weapon
	if Input.is_action_just_pressed("reload"):
		spare_ammo -= ammo_needed
		Ammo_In_Weapon = Fully_Loaded_Weapon


func _physics_process(delta):
	#print(health)
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
				
				# Add to Ammo instead.
				print("I collided with ", collision.get_collider().name)
				add_health(1)
				collision.get_collider().queue_free()
			if "Health" in collision.get_collider().name:
				print("I collided with ", collision.get_collider().name)
				add_health(1)
				collision.get_collider().queue_free()


# Get defined key inputs
func _input(event):
# Switch guns in inventory slot according to the key inputs set for it
	if event.is_action_pressed("inventory_slot_1"):
		Global.switch_gun(1)
	elif event.is_action_pressed("inventory_slot_2"):
		Global.switch_gun(2)
	elif event.is_action_pressed("inventory_slot_3"):
		Global.switch_gun(3)

# Switch player's camera view according to the key inputs set for it
	if event.is_action_pressed("dynamic_camera_view"):
		toggle_different_camera_state();


@rpc("call_local")
func play_shoot_effects():
	anim_player.stop()
	anim_player.play("shoot")
	if is_fpp:
		fpp_muzzle_flash.restart()
		fpp_muzzle_flash.emitting = true
	else:
		tpp_muzzle_flash.restart()
		tpp_muzzle_flash.emitting = true


@rpc("any_peer")
func receive_damage():
	health -= 1
	if health <= 0:
		print("Game Over!")
		# Reset the player's health and position
		health = 3
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

# Update the visibility of guns when player changed the camera view based on their preferrance
func update_weapon_model_visibility():
	# Hide all weapons first
	fpp_pistol.visible = initial_fpp_pistol_visible
	fpp_ak47.visible = initial_fpp_ak47_visible
	fpp_knife.visible = initial_fpp_knife_visible
	tpp_pistol.visible = initial_tpp_pistol_visible
	tpp_ak47.visible = initial_tpp_ak47_visible
	tpp_knife.visible = initial_tpp_knife_visible

	# Show the correct weapon based on the current weapon and camera view state
	if is_fpp:
		if current_weapon == "Glock-19":
			fpp_pistol.visible = true
		elif current_weapon == "AK-47":
			fpp_ak47.visible = true
		elif current_weapon == "Knife":
			fpp_knife.visible = true
	else:
		if current_weapon == "Glock-19":
			tpp_pistol.visible = true
		elif current_weapon == "AK-47":
			tpp_ak47.visible = true
		elif current_weapon == "Knife":
			tpp_knife.visible = true

	# Synchronize visibility for multiplayer
	if is_multiplayer_authority():
		multiplayer_sync.set_visibility_for(multiplayer.get_unique_id(), fpp_pistol.visible)
		multiplayer_sync.set_visibility_for(multiplayer.get_unique_id(), fpp_ak47.visible)
		multiplayer_sync.set_visibility_for(multiplayer.get_unique_id(), fpp_knife.visible)
		multiplayer_sync.set_visibility_for(multiplayer.get_unique_id(), tpp_pistol.visible)
		multiplayer_sync.set_visibility_for(multiplayer.get_unique_id(), tpp_ak47.visible)
		multiplayer_sync.set_visibility_for(multiplayer.get_unique_id(), tpp_knife.visible)
