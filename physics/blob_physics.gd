class_name BlobPhysics
extends Node
## Moves and collides every blob in the "blobs" group. Blobs never move
## themselves: stepping them all here, in tree order, keeps collisions resolving
## the same way every frame.

## Every blob-vs-blob contact. Main listens: sparks, boing, shake, hitstop.
signal blob_contact(a: Blob, b: Blob, point: Vector2, impact: float)
## Every bounce off the outer wall. Main listens: sparks, thud, shake.
signal wall_hit(blob: Blob, point: Vector2, impact: float)

@export var substeps := 2               # physics substeps per frame (stops fast blobs tunnelling)
@export var blob_restitution := 0.9     # 0 = dead thud, 1 = perfect bounce
@export var bump_pop := 70.0            # extra separation speed on every real contact (the "boing")
@export var bump_pop_min_impact := 40.0
@export var wall_restitution := 0.7

## Used until there is an Arena node in the "arena" group to read them from.
@export var fallback_ring_radius := 300.0
@export var fallback_wall_radius := 380.0

var _center := Vector2.ZERO
var _ring_r := 300.0
var _wall_r := 380.0


func _physics_process(delta: float) -> void:
	_update_arena()
	var blobs := _living_blobs()
	var h := delta / substeps
	for _i in substeps:
		for b in blobs:
			b.step_motion(h, b.global_position.distance_to(_center) > _ring_r)
		_collide_blobs(blobs)
		_collide_walls(blobs)


## Read the ring and wall from the Arena if there is one, else assume the origin.
func _update_arena() -> void:
	var arena = get_tree().get_first_node_in_group("arena")
	if arena != null:
		_center = arena.global_position
		_ring_r = arena.ring_radius
		_wall_r = arena.wall_radius
	else:
		_center = Vector2.ZERO
		_ring_r = fallback_ring_radius
		_wall_r = fallback_wall_radius


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
				var jimp := (1.0 + blob_restitution) * impact / isum
				if impact > bump_pop_min_impact:
					jimp += bump_pop / isum
				a.vel -= n * jimp * ia
				b.vel += n * jimp * ib
				# Lighter blob squashes more.
				var share_a := ia / isum
				a.body.bump(n, impact * share_a * 2.0)
				b.body.bump(n, impact * (1.0 - share_a) * 2.0)
				blob_contact.emit(a, b, a.global_position + n * a.radius, impact)


func _collide_walls(blobs: Array[Blob]) -> void:
	for b in blobs:
		var rel := b.global_position - _center
		var dist := rel.length()
		var limit := _wall_r - b.radius
		if dist <= limit:
			continue
		var n := rel / dist
		b.global_position = _center + n * limit
		var vn := b.vel.dot(n)
		if vn > 0.0:
			b.vel -= n * vn * (1.0 + wall_restitution)
			b.body.bump(n, vn)
			wall_hit.emit(b, b.global_position + n * b.radius, vn)
