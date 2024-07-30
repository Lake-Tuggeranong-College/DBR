extends Node

# Declare the inventory array
var inventory = []

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
