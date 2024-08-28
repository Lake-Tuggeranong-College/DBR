extends Node

# Define signals for weapon switching
signal weapon_switched(weapon_name)

# Inventory slots
var guns = ["Glock-19", "AK-47"]
var melees = ["Knife"]


# Add weapons to the inventory
func add_weapon(weapon_name, weapon_type):
	if weapon_type == "gun" and guns.size() < 3:
		guns.append(weapon_name)
	elif weapon_type == "melee" and melees.size() < 3:
		melees.append(weapon_name)


# Switch weapons based on the inventory slot for each individual of it
func switch_weapon(weapon_slot):
	var weapon_name = ""

	if weapon_slot == 1 and guns.size() > 0:
		weapon_name = guns[0]  # Switch to 'Glock-19'
	elif weapon_slot == 2 and guns.size() > 1:
		weapon_name = guns[1]  # Switch to 'AK-47'
	elif weapon_slot == 3 and melees.size() > 0:
		weapon_name = melees[0]  # Switch to 'Knife'
	else:
		print("No weapon to switch for!")

	if weapon_name != "":
		emit_signal("weapon_switched", weapon_name)
