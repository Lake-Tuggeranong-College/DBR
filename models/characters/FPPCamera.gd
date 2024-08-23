extends Camera3D

# Define the ADS parameters
var normal_fov = 75
var ads_fov = 55
var ads_speed = 0.25
var is_ads = false

func _process(delta):
	if Input.is_action_pressed("ads"):
		if not is_ads:
			is_ads = true
			tween_fov(ads_fov)
	else:
		if is_ads:
			is_ads = false
			tween_fov(normal_fov)

func tween_fov(target_fov):
	var tween = get_node("Tween")
	if tween:
		tween.interpolate_property(self, "fov", fov, target_fov, ads_speed, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
		tween.start()
