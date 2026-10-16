class_name LaserSettings
extends Resource
## How a laser emitter (turret, ship) charges, fires and hits. Timings are in
## beats of the music, so lasers always land on the beat. Colours come from the
## theme (laser.beam, laser.body, laser.engine).

@export var charge_beats := 2.0 # telegraph length
@export var lock_beats := 0.75 # aim freezes this many beats before firing
@export var fire_beats := 0.5 # how long the beam stays visible
@export var width := 20.0 # hit width
@export var impulse := 700.0 # knockback on a mass-1 blob
