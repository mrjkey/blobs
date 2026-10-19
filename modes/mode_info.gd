class_name ModeInfo
extends Resource
## A game mode as the menus see it: its name, its scene and how many players
## it takes. The main menu hands it to the lobby, which builds the lineup and
## starts `scene`. The mode's script holds it too (GameMode.info), for the
## default lineup when the scene is started on its own.
##
## `teams` names the teams of a team mode (empty: every blob for itself).
## Seats alternate between them: P1 and P3 on the first, P2 and P4 on the
## second. `options` are keys of GameSettings.OPTIONS the lobby shows under
## the mode's name (match length and the like). A mode without `bots` is for
## humans only: the lobby never fills a seat with a computer. A mode with a
## `theme` always plays in that look, whatever the THEME setting says.

const MAX_SLOTS := 4

@export var title := "MODE"
@export var subtitle := ""
@export_file("*.tscn") var scene := ""
@export_range(1, 4) var min_slots := 2
@export_range(1, 4) var max_slots := 4
@export_range(1, 4) var default_slots := 2 # seats open when the lobby starts, and in the default lineup
@export_range(1, 4) var max_humans := 4 # 1 = a one-player mode: P1 plays with the keyboard and a gamepad
@export var teams := PackedStringArray() # e.g. ["BLUE", "RED"]; empty = no teams
@export var options := PackedStringArray() # GameSettings option keys, set in the lobby
@export var bots := true # computers can take seats; false = humans only (co-op modes)
@export var theme := "" # a key of Session.THEMES this mode always plays in (e.g. "classic"); "" = the player's pick
@export var mass_loss := false # blobs shrink over time, pay mass for spit and lasers, and pop when too small (Blob.loses_mass)


## The team of the seat with index `seat` (0..3), or -1 in a mode without teams.
func team_of(seat: int) -> int:
	return seat % teams.size() if not teams.is_empty() else -1
