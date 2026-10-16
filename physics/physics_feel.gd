class_name PhysicsFeel
extends Resource
## How blobs bounce off each other and off walls. Used by BlobPhysics, and
## passed to every collider so walls and bumpers share the same numbers.

@export var substeps := 2               # physics substeps per frame (stops fast blobs tunnelling)
@export_range(0.0, 1.0) var blob_restitution := 0.9 # 0 = dead thud, 1 = perfect bounce
@export var bump_pop := 70.0            # extra separation speed on every real contact (the "boing")
@export var bump_pop_min_impact := 40.0
@export_range(0.0, 1.0) var wall_restitution := 0.7
