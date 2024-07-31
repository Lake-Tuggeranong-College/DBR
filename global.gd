extends Node

# Declare the inventory array
var inventory = []
var selectSlot

# Array of available guns
var Guns = [
	'Knife',
	'Glock-19',
	'AK-47',
	'M4A1',
]

# Function to add an item to the inventory
func add_item(item):
	inventory.append(item)
	print("Item added: ", item)

# Function to remove an item from the inventory
func remove_item(item):
	if item in inventory:
		inventory.erase(item)
		print("Item removed: ", item)
	else:
		print("Item not found in inventory")

# Function to list all items in the inventory
func list_inventory():
	print("Inventory: ", inventory)

# Function to select an item slot
func select_slot(slot):
	if slot >= 0 and slot < Guns.size():
		var item = Guns[slot]
		remove_item(item)  # Remove the current item in the slot
		add_item(item)  # Add the new item to the slot
		selectSlot = slot
		print("Selected Slot: ", selectSlot, " with item: ", item)
	else:
		print("Invalid slot selected")
