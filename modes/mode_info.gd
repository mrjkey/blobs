class_name ModeInfo
extends Resource
## A game mode as the menus see it: its name, its scene and how many players
## it takes. The main menu hands it to the lobby, which builds the lineup and
## starts `scene`. The mode's script holds it too (GameMode.info), for the
## default lineup when the scene is started on its own.

const MAX_SLOTS := 4

@export var title := "MODE"
@export var subtitle := ""
@export_file("*.tscn") var scene := ""
@export_range(1, 4) var min_slots := 2
@export_range(1, 4) var max_slots := 4
@export_range(1, 4) var default_slots := 2 # seats open when the lobby starts, and in the default lineup
@export_range(1, 4) var max_humans := 4 # 1 = a one-player mode: P1 plays with the keyboard and a gamepad
