class_name BlobPhysics
extends Node
## Moves and collides every living blob in the "blobs" group. Blobs never move
## themselves: stepping them all here, in tree order, keeps collisions resolving
## the same way every frame.
##
## Walls and obstacles join the "blob_colliders" group and implement
##     func collide(blob: Blob, feel: PhysicsFeel) -> void
## which is called for every blob on every substep, after blob-vs-blob contacts.
## The node in group "arena" (if any) can slow blobs down with
##     func is_in_mud(pos: Vector2) -> bool

## Every blob-vs-blob contact.
signal blob_contact(a: Blob, b: Blob, point: Vector2, impact: float)

@export var feel: PhysicsFeel = preload("res://core/physics/default_feel.tres")


func _ready() -> void:
	process_physics_priority = 0 # after controllers (-10), before blob abilities (10)


func _physics_process(delta: float) -> void:
	if delta <= 0.0:
		return
	var blobs := _living_blobs()
	var colliders := get_tree().get_nodes_in_group("blob_colliders")
	var arena := get_tree().get_first_node_in_group("arena")
	var has_mud := arena != null and arena.has_method("is_in_mud")
	var h := delta / feel.substeps
	for _i in feel.substeps:
		for b in blobs:
			b.step_motion(h, has_mud and arena.is_in_mud(b.global_position))
		_collide_blobs(blobs)
		for c in colliders:
			for b in blobs:
				c.collide(b, feel)


func _living_blobs() -> Array[Blob]:
	var out: Array[Blob] = []
	for b: Blob in get_tree().get_nodes_in_group("blobs"):
		if b.alive:
			out.append(b)
	return out


func _collide_blobs(blobs: Array[Blob]) -> void:
	for i in blobs.size():
		var a := blobs[i]
		for j in range(i + 1, blobs.size()):
			var b := blobs[j]
			if a.is_ghost() or b.is_ghost():
				continue # mid ghost dash: pass straight through
			var d := b.global_position - a.global_position
			var rsum := a.radius + b.radius
			var dist2 := d.length_squared()
			if dist2 >= rsum * rsum:
				continue
			var dist := sqrt(dist2)
			var n := d / dist if dist > 0.001 else Vector2.from_angle(randf() * TAU)
			var ia := 1.0 / a.mass
			var ib := 1.0 / b.mass
			var isum := ia + ib
			# Push apart, lighter blob moves more.
			var overlap := rsum - dist
			a.global_position -= n * overlap * ia / isum
			b.global_position += n * overlap * ib / isum
			# Bounce.
			var vn := (b.vel - a.vel).dot(n)
			if vn < 0.0:
				var impact := -vn
				var jimp := (1.0 + feel.blob_restitution) * impact / isum
				if impact > feel.bump_pop_min_impact:
					jimp += feel.bump_pop / isum
				# A solid dash knocks whoever it hits out of control for a moment.
				if a.is_dashing():
					b.stun = maxf(b.stun, a.stats.dash_hit_stun)
				if b.is_dashing():
					a.stun = maxf(a.stun, b.stats.dash_hit_stun)
				a.vel -= n * jimp * ia
				b.vel += n * jimp * ib
				_contact_feedback(a, b, n, impact)


func _contact_feedback(a: Blob, b: Blob, n: Vector2, impact: float) -> void:
	var js := Juice.settings
	var point := a.global_position + n * a.radius
	Juice.impact_at(point, impact)
	# Lighter blob squashes more.
	var share_a := (1.0 / a.mass) / (1.0 / a.mass + 1.0 / b.mass)
	a.bump(n, impact * share_a * 2.0)
	b.bump(n, impact * (1.0 - share_a) * 2.0)
	if impact > 90.0:
		var pitch := randf_range(0.9, 1.15) / sqrt((a.mass + b.mass) * 0.5)
		Sfx.play("boing", pitch, linear_to_db(clampf(impact / 500.0, 0.2, 1.0)))
	if impact > js.spark_min_impact:
		Juice.burst(point, a.color.lerp(b.color, 0.5).lightened(0.3), int(clampf(impact / 60.0, 3.0, 14.0)), impact * 0.5)
	if impact > js.shake_min_impact:
		Juice.shake(impact * js.shake_per_impact)
	if impact > js.hitstop_min_impact:
		Juice.hitstop(js.hitstop_bump)
	blob_contact.emit(a, b, point, impact)


## For colliders: move `b` out of a solid surface by `depth` along `n` (pointing
## from the surface toward the blob) and bounce it. Returns the impact speed,
## or 0 if the blob wasn't moving into the surface.
static func bounce(b: Blob, n: Vector2, depth: float, restitution: float) -> float:
	b.global_position += n * depth
	var vn := b.vel.dot(n)
	if vn >= 0.0:
		return 0.0
	b.vel -= n * vn * (1.0 + restitution)
	b.bump(n, -vn)
	return -vn


## For colliders: the sparks, thud and shake of a blob hitting a wall at `point`.
static func wall_feedback(point: Vector2, impact: float, color: Color) -> void:
	var js := Juice.settings
	if impact > 120.0:
		Juice.impact_at(point, impact)
		Juice.burst(point, color.lightened(0.4), int(clampf(impact / 80.0, 3.0, 10.0)), impact * 0.4)
		Sfx.play("wall", randf_range(0.9, 1.1), linear_to_db(clampf(impact / 500.0, 0.2, 1.0)))
	if impact > js.shake_min_impact:
		Juice.shake(impact * js.shake_per_impact * 0.7)
