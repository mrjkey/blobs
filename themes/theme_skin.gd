@tool
class_name ThemeSkin
extends Resource
## Base for every skin: a Resource that draws one kind of thing in one theme's
## style. A skin holds only colours and drawing code; the node it draws keeps
## all the state and calls the skin from its _draw(), so skins draw with
## node.draw_*(). Skins live in themes/<theme>/ and are listed in GameTheme.


## 1.0 on each kick drum of the music, fading before the next; 0 without music or in the editor.
static func kick(node: Node) -> float:
	return 0.0 if Engine.is_editor_hint() else Techno.current_kick(node.get_tree())


## Beats of the music since its scene started (a steady clock without music; 0 in the editor).
static func beat(node: Node) -> float:
	return 0.0 if Engine.is_editor_hint() else Techno.current_beat(node.get_tree())
