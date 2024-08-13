extends Node

# Define signals for weapon switching
signal weapon_switched(weapon_name)

# Inventory slots for guns
var guns = ["Glock-19", "AK-47"]

# Add guns to the inventory
func add_gun(gun_name):
	if guns.size() < 2:
		# Slow down the gun name text ouput by a bit. No rushing, you know :D
		guns.append(gun_name)

# Switch guns based on the inventory slot for each individual of it
func switch_gun(slot):
	# Create an emtpy array to store gun name dynacally
	var gun_name = ""
	
	if slot == 1 and guns.size() > 0:
		gun_name = guns[0]  # Example 1: Switch to "AK-47"
	elif slot == 2 and guns.size() > 1:
		gun_name = guns[1]  # Example 2: Switch to "Glock-19"

	# Auto add the gun name into it based on what guns have already been defined
	if gun_name != "":
		emit_signal("weapon_switched", gun_name)

