class_name TrackSettings
extends Resource
## Treadmill knobs: the track, its obstacles, the scrolling, the ships and the
## bots per mode. Blob physics comes from BlobStats / PhysicsFeel as usual, and
## every colour from the theme's skins.
## Shared by every track piece through level/arenas/track/track_settings.tres.

@export_group("Track and camera")
@export var track_width := 700.0 # distance between the side walls
@export var side_zone := 150.0 # space beside the track where the laser ships fly
@export var scroll_start := 55.0 # camera speed (px/s) when the round starts
@export var scroll_max := 130.0 # top camera speed
@export var scroll_ramp_time := 90.0 # seconds to go from start speed to top speed
@export var edge_inset := 26.0 # how far inside the screen edge the kill lasers sit

@export_group("Obstacles")
@export var chunk_height := 420.0 # the track is generated in slices this tall
@export var start_clear := 260.0 # empty floor above the spawn line
@export var obstacle_gap := 95.0 # min space between obstacles (a full-size blob is ~80 wide)
@export var wall_thickness := 24.0
@export var kicker_speed := 650.0 # pink walls fling you away at this speed
@export var bumper_kick := 780.0 # round pinball bumpers fling you at this speed
@export var bumper_stun := 0.2
@export var difficulty_distance := 6000.0 # px travelled until obstacles are at their densest
@export var food_per_chunk_max := 2

@export_group("Ships")
@export var ship_speed := 0.6 # how fast they cruise up and down

@export_group("Players and bots")
@export var bots_vs_cpu := 3
@export var bots_with_two_players := 2
