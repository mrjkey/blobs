extends Node
## Autoload "Session": choices that must survive scene changes and reloads.
## Menus write here, game scenes read here in _ready().

## Treadmill mode picked in ui/menus/treadmill_menu.tscn (0 = 1P vs computer,
## 1 = 2P versus, 2 = 2P + computer, 3 = watch). -1 = not picked yet, e.g. when
## treadmill.tscn is run on its own with F6.
var treadmill_mode := -1
