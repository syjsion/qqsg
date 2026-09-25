class_name MovementRules
extends RefCounted

const SPEED = 250.0
const GRAVITY = 1500.0
const JUMP = -560.0

# Same fixed-step controller on server and local prediction. Positions are feet.
static func step(body: Dictionary, axis: Vector2, jump: bool, dt: float, map: Dictionary) -> void:
	if body.get("dead", false):
		return
	var x = float(body.x)
	var y = float(body.y)
	var vy = float(body.get("vy", 0))
	var ladder = false
	for l in map.ladders:
		if absf(x - float(l[0])) < 25 and y >= float(l[1]) - 10 and y <= float(l[2]) + 10:
			ladder = true
	var climb = ladder and absf(axis.y) > 0
	if jump and (body.get("grounded", false) or body.get("climbing", false)):
		vy = JUMP
		climb = false
	elif climb:
		vy = axis.y * 170
	else:
		vy = minf(vy + GRAVITY * dt, 900)
	x = clampf(x + axis.x * SPEED * dt, 32, float(map.width) - 32)
	var next_y = y + vy * dt
	var grounded = false
	if vy >= 0 and not climb:
		for p in map.platforms:
			if x >= float(p[0]) and x <= float(p[1]) and y <= float(p[2]) + 2 and next_y >= float(p[2]):
				next_y = float(p[2])
				vy = 0
				grounded = true
	if next_y > 900:
		x = float(map.spawn[0])
		next_y = float(map.spawn[1])
		vy = 0
	body.x = x
	body.y = next_y
	body.vy = vy
	body.grounded = grounded
	body.climbing = climb
	if axis.x != 0:
		body.facing = 1 if axis.x > 0 else -1
	body.moving = absf(axis.x) > 0
