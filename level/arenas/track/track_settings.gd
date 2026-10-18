class_name TrackSettings
extends Resource
## Treadmill knobs: the track, its obstacles, the scrolling and the ships
## (who plays comes from the lineup). Blob physics comes from BlobStats / PhysicsFeel as usual, and
## every colour from the theme (see each piece's script for its colour names).
## Shared by every track piece through level/arenas/track/track_settings.tres.

@export_group("Track and camera")
@export var track_width := 700.0 # distance between the side walls
@export var belt_height := 1600.0 # distance between the kill lasers at TRACK VIEW: FAR (less for the others); the camera always shows all of it
@export var camera_margin := 90.0 # floor shown past each kill laser (keeps them clear of the HUD text)
@export var spawn_y := 150.0 # where blobs start, below the belt's centre
@export var finish_overshoot := 300.0 # on a map, the belt stops when its top laser is this far past the finish line
@export var side_zone := 150.0 # space beside the track where the laser ships fly
@export var scroll_start := 70.0 # belt speed (px/s) when the round starts, at TRACK SPEED: NORMAL
@export var scroll_max := 160.0 # top belt speed, at TRACK SPEED: NORMAL
@export var scroll_ramp_time := 90.0 # seconds to go from start speed to top speed

@export_group("Obstacles")
@export var chunk_height := 380.0 # the track is generated in slices this tall (most get a wall row)
@export var start_clear := 260.0 # empty floor above the spawn line (and a little below it)
@export var obstacle_gap := 95.0 # min space between obstacles (a full-size blob is ~80 wide)
@export var wall_thickness := 24.0
@export_range(0.0, 1.0) var ghost_proof_chance := 1.0 # chance each wall (rows and loose ones) stops ghost dashes too (drawn hatched)
@export var kicker_speed := 650.0 # pink walls fling you away at this speed
@export var bumper_kick := 780.0 # round pinball bumpers fling you at this speed
@export var bumper_stun := 0.2
@export var difficulty_distance := 6000.0 # px travelled until obstacles are at their densest

@export_group("Wall rows")
## A row is a wall right across the track with a few gaps in it. The widest
## gap decides which blobs get through: a mass-5 blob is ~90 wide, a mass-10 one ~124.
@export var row_chance := 0.7 # chance a chunk gets a row (rises to 1 with difficulty)
@export var row_gaps := Vector2i(1, 3) # how many gaps a row has
@export var row_widest_gap := Vector2(90.0, 220.0) # the widest gap's width
@export var row_narrow_gap := Vector2(45.0, 100.0) # the other gaps' widths
@export var row_kicker_chance := 0.12 # chance each piece of a row is a kicker

@export_group("Food")
@export var food_per_chunk := Vector2i(2, 4) # pellets per chunk, times the FOOD setting

@export_group("Ships")
@export var ship_speed := 0.6 # how fast they cruise up and down
