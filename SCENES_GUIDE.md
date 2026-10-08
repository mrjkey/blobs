# Bumper Blobs: Rebuilding with Godot Scenes

Oct 8, 2026 · [Live version](https://claude.ai/code/artifact/e3598743-6512-4624-8ca0-c404d5f7b881)

## Overview

Give everything you can point at in the game its own scene (`.tscn`) with a script attached, and let a Main scene instance them. In the current project, `game.gd` builds everything with `.new()` and `add_child()`. In the scene version, the node trees are built in the editor, the numbers live in the Inspector, and Main spawns ready-made scenes.

What changes and what stays:

| Today (built in code) | Scene version (normal Godot) |
| --- | --- |
| `Blob.new()` in `game.gd` | `blob.tscn`, spawned with `PackedScene.instantiate()` |
| `if is_player` branches + `brain` var | Player and Bot are inherited scenes with a controller child node |
| `tuning.gd` full of `const` | `@export` vars + a `BlobStats` Resource (`.tres`) you edit in the Inspector |
| `_setup_input()` builds the Input Map | Project Settings > Input Map |
| `game.gd` holds references to everything | Groups (`"blobs"`), signals (`eliminated`, `ate_food`), `%UniqueName` lookups |
| Particles and labels built in code | `CPUParticles2D`, `Label`, `AnimationPlayer` nodes placed in the editor |

The physics math, jelly deformation and bot logic stay almost line for line. They only move into different files.

How the scenes fit together:

```
Main  (main.tscn: spawns the scenes, reacts to signals)
├── Arena          ring + wall
├── BlobPhysics    moves and collides every blob
├── Blobs          spawned here ─── signals: pushed, eliminated ──▶ Main
│   ├── player.tscn   (+ PlayerInput)  ┐
│   └── bot.tscn      (+ BotBrain)     ┴─ both inherit blob.tscn (movement, push, jelly)
├── Food           spawned by a Timer
└── HUD            count, banners
```

Main owns or spawns everything below it. The only path back up is signals: blobs emit them, and Main reacts.

Target folder layout:

```
res://
  main.tscn, main.gd
  blob/
    blob.tscn, blob.gd          # shared body: movement, push, jelly, drawing
    player.tscn                 # inherits blob.tscn, adds PlayerInput
    bot.tscn                    # inherits blob.tscn, adds BotBrain
    player_input.gd, bot_brain.gd
    blob_stats.gd               # the Resource class
    default_stats.tres, heavy_stats.tres
  arena/arena.tscn, arena.gd
  food/food.tscn, food.gd
  fx/burst.tscn, shockwave.tscn, shockwave.gd
  ui/hud.tscn, hud.gd
  sfx/*.wav
```

## Project setup

Define the controls once in Project Settings. Then no script needs `_setup_input()`.

1. Project > Project Settings > **Input Map**. Type an action name, then Add: `move_left`, `move_right`, `move_up`, `move_down`, `push`, `restart`, `quit`.
2. On each action, click **+** and press the key (A, D, W, S, Space, R, Esc). Add arrow keys and gamepad events to the same actions if you want them.
3. Project Settings > **Display > Window**: viewport 1280 x 720, Stretch Mode `canvas_items`, Aspect `expand` (same as now).
4. Rendering > Environment > Default Clear Color for the background.

Code then just reads the actions: `Input.get_vector("move_left", "move_right", "move_up", "move_down")`. The Input Map is saved in `project.godot`, so it survives scene reloads and works in every scene.

## Tuning in the Inspector

Replace `tuning.gd` with `@export` vars, so every number becomes a field in the Inspector. Blob numbers go in a custom Resource that blobs share. Arena numbers go on the Arena node. Round and spawn numbers go on Main.

`blob/blob_stats.gd`:

```gdscript
class_name BlobStats
extends Resource

@export_group("Movement")
@export var base_radius := 22.0
@export var base_speed := 330.0
@export var base_accel := 3200.0
@export var turn_accel_mult := 1.6
@export var drag := 1.6
@export var knockback_drag := 4.0
@export_range(0.0, 1.0) var knockback_control := 0.3

@export_group("Push")
@export var push_impulse := 1050.0
@export var push_range := 70.0
@export var push_cooldown := 0.9
@export var push_stun := 0.35

@export_group("Jelly")
@export var jelly_stiffness := 380.0
@export var jelly_damping := 9.0
@export var squash_kick := 0.011
```

To make a stats file: in the FileSystem dock, right-click > **New Resource** > BlobStats > save as `default_stats.tres`. Double-click it to edit the numbers in the Inspector. Make `heavy_stats.tres` with different numbers to get a slow, heavy bot type without writing code.

The Blob script points at one: `@export var stats: BlobStats`. Drag the `.tres` into that slot on `blob.tscn`.

- Use `@export_range(min, max)` to get a slider, and `@export_group` to fold fields into sections.
- While the game runs, the **Remote** tab in the Scene dock shows the live nodes. Values you change there take effect immediately but are not saved. Copy the good ones back afterwards.
- One `.tres` is shared by every blob that uses it. Mass changes per blob, so keep `mass` as a plain var on the Blob, not in the Resource.

## The Blob scene

Blob is the shared base scene: the body, movement, push, jelly and look. It knows nothing about who controls it. Something else just sets `move_dir` and calls `request_push()`.

Create it: Scene > New Scene > Other Node > **Node2D**, rename it `Blob`, and save it as `blob/blob.tscn`. Node tree:

```
Blob (Node2D)                 blob.gd, in group "blobs"
├─ Body (Node2D)              body.gd, draws the jelly and eyes in _draw()
├─ PushSound (AudioStreamPlayer2D)
└─ BumpSound (AudioStreamPlayer2D)
```

Add the group in the editor: select Blob > **Node** dock > Groups > type `blobs` > Add. Every blob you spawn is then in that group, and any script can find them with `get_tree().get_nodes_in_group("blobs")`. This replaces `game.blobs`.

`blob/blob.gd`, the skeleton (fill in the bodies from today's `blob.gd`):

```gdscript
class_name Blob
extends Node2D

signal pushed(blob: Blob)               # main listens: shake, hitstop, shockwave
signal bumped(blob: Blob, impact: float)
signal ate_food(blob: Blob)
signal eliminated(blob: Blob)

@export var stats: BlobStats
@export var color := Color.WHITE
@export var display_name := "Blob"

var vel := Vector2.ZERO
var mass := 1.0
var radius := 22.0
var move_dir := Vector2.ZERO            # set by PlayerInput or BotBrain
var alive := true
var push_cooldown := 0.0
var push_buffer := 0.0
var windup := 0.0
var stun := 0.0

@onready var body: Node2D = $Body
@onready var push_sound: AudioStreamPlayer2D = $PushSound

func _ready() -> void:
    set_mass(1.0)

func request_push() -> void:
    push_buffer = 0.15

func step_motion(h: float) -> void:
    pass  # same as today, but read stats.base_speed etc. instead of T.BASE_SPEED

func _release_push() -> void:
    var reach := radius + stats.push_range
    for other: Blob in get_tree().get_nodes_in_group("blobs"):
        if other == self or not other.alive:
            continue
        # same distance / falloff math as today's do_push()
        # other.take_push(direction, speed)
    push_sound.play()
    pushed.emit(self)
```

Push now lives on the Blob itself. Main no longer runs it: it only listens to the `pushed` signal for screen shake and hitstop.

For drawing, `body.gd` reads its parent and draws. Move today's `_draw()`, `_draw_eyes()` and the jelly spring into it:

```gdscript
extends Node2D
@onready var blob: Blob = get_parent()

func _process(_delta: float) -> void:
    queue_redraw()

func _draw() -> void:
    pass  # today's polygon, outline, highlight and eyes, using blob.color and blob.radius
```

A simpler look to start with: make Body a **Sprite2D** with a white circle PNG, tinted with `modulate = color`. Squash it by pointing it along the hit and scaling one axis, then tween back:

```gdscript
body.rotation = hit_dir.angle()
body.scale = Vector2(0.7, 1.2)
create_tween().tween_property(body, "scale", Vector2.ONE, 0.35) \
    .set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
```

`TRANS_ELASTIC` gives the wobble for free. The custom `_draw()` version looks better, but this one is a good first step.

## Player and bot: inherited scenes with a controller node

The player and the bots are the same Blob with a different child node doing the steering. This replaces the `is_player` checks and the `brain` var.

Make each one with Scene > **New Inherited Scene** > pick `blob.tscn`:

```
player.tscn  (inherits blob.tscn)        bot.tscn  (inherits blob.tscn)
Blob                                     Blob
├─ Body, sounds (from blob.tscn)         ├─ Body, sounds (from blob.tscn)
└─ PlayerInput (Node)                    └─ BotBrain (Node)
```

Nodes from the base scene show up greyed out. Change something in `blob.tscn` and both scenes get it. Values you override in the child scene (for example `color` on the player) show a revert arrow in the Inspector.

`blob/player_input.gd`:

```gdscript
extends Node
@onready var blob: Blob = get_parent()

func _physics_process(_delta: float) -> void:
    blob.move_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
    if Input.is_action_just_pressed("push"):
        blob.request_push()
```

`blob/bot_brain.gd`: today's `ai_brain.gd` with three changes:

- `extends Node` instead of `RefCounted`, and `@onready var me: Blob = get_parent()` instead of `_init()`.
- The personality numbers become exports, so each bot instance can be tuned in the Inspector: `@export_range(0, 1) var aggression := 0.7`. In `_ready()`, randomize them only if a `randomize_personality` export is on.
- It runs its own `_physics_process(delta)` (today's `think()`), and finds targets with `get_tree().get_nodes_in_group("blobs")` and food with the `"food"` group.

Bonus: drop a PlayerInput onto a second blob that reads different actions (`p2_move_left`, and so on), and you have local two-player.

## Physics: custom manager or built-in bodies

Keep the custom physics for the rebuild. The feel you just tuned lives in that math. Try `RigidBody2D` later as a separate experiment, because it is the more standard Godot route and teaches the physics nodes.

| Approach | Good | Watch out |
| --- | --- | --- |
| Custom physics in a `BlobPhysics` node (today's code) | Exact control; your tuned numbers carry over; deterministic order | You write the circle collisions yourself (already done) |
| `RigidBody2D` per blob | Collisions, bounce and mass built in; editor shows collision shapes; `Area2D` signals work | Feel is harder to pin down; steering has to go through `_integrate_forces`; impact speed for squash needs contact data |
| `CharacterBody2D` per blob | Easy movement with `move_and_collide` | Bodies don't push each other; you'd compute every bounce by hand anyway |

**Custom route, as scenes:** add a plain `Node` called `BlobPhysics` to Main with `blob_physics.gd`. Move today's `_simulate()`, `_collide_blobs()` and `_collide_walls()` into it, looping over the `"blobs"` group. Blobs don't run their own `_physics_process` for movement. BlobPhysics calls `step_motion()` on each blob, so everything steps in a fixed order. Give it `@export var arena: Arena` so it reads the wall radius from the Arena node.

**RigidBody2D route**, if you try it:

- Blob root becomes `RigidBody2D` with a `CollisionShape2D` (CircleShape2D) child. Set Gravity Scale 0 and Lock Rotation on.
- Physics Material Override > new PhysicsMaterial: Bounce 0.9, Friction 0. Linear > Damp 1.6.
- Steering goes in `_integrate_forces(state)`: `state.linear_velocity += (target - state.linear_velocity).limit_length(accel * state.step)`.
- Push: `other.apply_central_impulse(dir * speed * other.mass)`. Knockback drag: raise `linear_damp` while moving faster than top speed.
- Squash: turn on Contact Monitor (Max Contacts Reported 4), then read `state.get_contact_local_normal(i)` in `_integrate_forces`.
- Wall: `StaticBody2D` + `CollisionPolygon2D` in Segments mode with points around a circle (generate them in a `@tool` script).
- Ring-out: an `Area2D` with a big CircleShape2D; its `body_exited` / `body_entered` signals start and stop the out timer.
- Gotcha: a CircleShape2D is shared between every instance of the scene. If food changes `shape.radius`, every blob grows. Tick **Local to Scene** on the shape resource, or call `shape = shape.duplicate()` in `_ready()`.

## Arena, Food and effects scenes

**Arena** (`arena/arena.tscn`, root `Node2D` with `arena.gd`). Make it a `@tool` script so the arena draws in the editor and resizes live when you drag the numbers:

```gdscript
@tool
class_name Arena
extends Node2D

@export var ring_radius := 300.0:
    set(v):
        ring_radius = v
        queue_redraw()
@export var wall_radius := 380.0:
    set(v):
        wall_radius = v
        queue_redraw()
@export var ring_out_time := 1.0

func is_outside(pos: Vector2) -> bool:
    return pos.distance_to(global_position) > ring_radius

func _draw() -> void:
    pass  # today's arena drawing from game.gd
```

**Food** (`food/food.tscn`):

```
Food (Node2D)              food.gd, in group "food"
├─ Sprite (Sprite2D or a Node2D that draws a circle)
└─ AnimationPlayer         "spawn" (pop-in scale) and "idle" (bob, looping)
```

The pop-in and bob become animations you make in the Animation panel instead of `sin()` math. `food.gd` checks the `"blobs"` group each frame. When one overlaps, it calls `blob.eat()` and `queue_free()`. Main spawns food from a **Timer** node (Wait Time 2, Autostart on, `timeout` signal connected to `_spawn_food()`).

**Effects:**

- `fx/burst.tscn`: a `CPUParticles2D` with One Shot on, Explosiveness 1, Emitting on. Tune spread, speed and color ramp in the Inspector. Connect its `finished` signal to `queue_free`. Spawn it with `var b = burst_scene.instantiate(); b.position = p; b.color = c; fx_root.add_child(b)`.
- `fx/shockwave.tscn`: a `Node2D` that draws a ring. A Tween grows it: `create_tween().tween_property(self, "radius", to_r, 0.28)`, then `queue_free` when the tween finishes.
- Sounds: replace the synthesized tones with `.wav` files (jsfxr or sfxr make good boings in seconds) on `AudioStreamPlayer2D` nodes inside the scenes that make them. Randomize `pitch_scale` a little before each `play()`.

## The Main scene

Main places the pieces, spawns blobs from `PackedScene` exports, and reacts to their signals. It no longer runs every system itself.

```
Main (Node2D)                 main.gd
├─ Camera2D  (%Camera)        camera_shake.gd
├─ Arena  (arena.tscn)
├─ BlobPhysics (Node)         blob_physics.gd
├─ SpawnPoints (Node2D)
│  ├─ Marker2D × 5             drag them where blobs start
├─ Blobs (Node2D)             spawned blobs go here
├─ FoodRoot (Node2D)
├─ FoodTimer (Timer)
├─ FX (Node2D, Z Index 10)
└─ HUD  (hud.tscn)
```

Right-click Camera2D > **Access as Unique Name**. Any script in the scene can then use `%Camera` without a path.

`main.gd`:

```gdscript
extends Node2D

@export var player_scene: PackedScene     # drag player.tscn here
@export var bot_scene: PackedScene        # drag bot.tscn here
@export var bot_colors: Array[Color] = []
@export var countdown_time := 2.4

var state := "countdown"

func _ready() -> void:
    var points := $SpawnPoints.get_children()
    for i in points.size():
        var scene := player_scene if i == 0 else bot_scene
        var b: Blob = scene.instantiate()
        b.position = points[i].position
        if i > 0 and i - 1 < bot_colors.size():
            b.color = bot_colors[i - 1]
        $Blobs.add_child(b)
        b.eliminated.connect(_on_blob_eliminated)
        b.pushed.connect(_on_blob_pushed)
    $HUD.set_alive(points.size())
    await $HUD.play_countdown(countdown_time)
    state = "playing"

func _on_blob_pushed(_b: Blob) -> void:
    %Camera.add_shake(7.0)
    hitstop(0.06)

func _on_blob_eliminated(b: Blob) -> void:
    var left := get_tree().get_nodes_in_group("blobs").filter(func(x): return x.alive)
    $HUD.set_alive(left.size())
    if left.size() <= 1:
        state = "over"
        $HUD.show_winner(left)

func hitstop(seconds: float) -> void:
    Engine.time_scale = 0.0
    await get_tree().create_timer(seconds, true, false, true).timeout  # ignores time scale
    Engine.time_scale = 1.0

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("restart"):
        get_tree().reload_current_scene()
```

- The number of blobs equals the number of Marker2D nodes. Add a sixth marker and you get a fifth bot.
- Set a blob's exported values (`color`, `position`) **before** `add_child()`. They are then in place when its `_ready()` runs.
- Connect signals in code here, because the blobs don't exist in the editor. For nodes that do exist in the editor (FoodTimer), connect in the **Node** dock > Signals tab.
- The ring-out check moves to BlobPhysics, or to each Blob using `arena.is_outside(position)`. When the timer runs out, the blob calls `eliminated.emit(self)` and plays its own death animation.

## The HUD scene

Build the HUD in the editor with anchors, and give it a few small functions that Main calls. Main never touches its Labels directly.

```
HUD (CanvasLayer)             hud.gd
└─ Root (Control, Full Rect, Mouse Filter: Ignore)
   ├─ Status (Label)          anchor Top Left
   ├─ Hint (Label)            anchor Center Bottom
   ├─ Banner (Label)          anchor Full Rect, centered both ways
   └─ AnimationPlayer         "pop": Banner scale 0.6 → 1.1 → 1.0, "fade": modulate alpha 1 → 0
```

- Set anchors from the **Anchor preset** button in the 2D toolbar while a Control is selected.
- Text outline: in the Label's Inspector, Label Settings > New LabelSettings > Outline Size 12, black. Save it as `ui/big_text.tres` and reuse it on every Label.
- To scale the Banner from its middle, set **Pivot Offset** to half its size.

`ui/hud.gd`:

```gdscript
extends CanvasLayer

@onready var status: Label = %Status
@onready var banner: Label = %Banner
@onready var anim: AnimationPlayer = %AnimationPlayer

func set_alive(n: int) -> void:
    status.text = "Blobs left: %d" % n

func show_banner(text: String, color := Color.WHITE) -> void:
    banner.text = text
    banner.modulate = color
    anim.play("pop")

func play_countdown(total: float) -> void:
    for n in [3, 2, 1]:
        show_banner(str(n))
        await get_tree().create_timer(total / 3.0).timeout
    show_banner("BUMP!", Color(1, 0.9, 0.4))
    anim.queue("fade")

func show_winner(left: Array) -> void:
    if left.is_empty():
        show_banner("DRAW!")
    elif left[0] is Blob and left[0].get_node_or_null("PlayerInput"):
        show_banner("YOU WIN!", Color(1, 0.9, 0.35))
    else:
        show_banner("%s WINS" % left[0].display_name.to_upper(), left[0].color)
```

`play_countdown` uses `await`, so Main can write `await $HUD.play_countdown(2.4)` and simply wait until it finishes. That replaces the countdown state machine in `game.gd`.

## Build order and gotchas

Build in this order and press F5 after every step. Each step should be playable before you start the next.

- [ ] New project, Input Map, display settings.
- [ ] `BlobStats` resource + `default_stats.tres`.
- [ ] `blob.tscn` that draws a plain circle, plus `player.tscn` with PlayerInput. Movement only: one blob steering around an empty screen.
- [ ] `arena.tscn` as a `@tool` script, so you can see it in the editor. Put it and the player in `main.tscn`.
- [ ] BlobPhysics: wall bounce, then `bot.tscn` with a BotBrain that just chases you, then blob-vs-blob collisions.
- [ ] Push: windup, `_release_push()`, `pushed` signal, screen shake, hitstop.
- [ ] Jelly drawing in `body.gd` (or the Sprite2D + elastic tween version first).
- [ ] Ring-out timer, `eliminated` signal, spawn points, win check, restart.
- [ ] Food scene + FoodTimer + `eat()`.
- [ ] HUD, bursts, shockwaves, sounds.
- [ ] The full bot brain: flanking, edge safety, counter-push.

Gotchas that come up in this kind of rebuild:

- **Shared resources.** A `.tres`, a CircleShape2D or a LabelSettings is one object shared by every node that uses it. Changing it at runtime changes all of them. Use **Local to Scene** or `.duplicate()` when each instance needs its own copy.
- **`@onready` timing.** `@onready` vars are null until the node enters the tree. Set exported values before `add_child()`. Don't touch `$Child` nodes from `_init()`.
- **`class_name` not found.** The editor registers new `class_name` scripts when it rescans. If you see "Could not find type Blob", save all, and reopen the project if needed.
- **`%Name` lookups** only work for nodes marked **Access as Unique Name**, and only inside the same scene file.
- **Type inference errors.** `var x := something_untyped.foo` is an error, not a warning. Write `var x: float = ...` when the right side comes from an untyped var, an Array or a Dictionary.
- **Hitstop with `Engine.time_scale = 0`** also freezes timers and tweens, unless they ignore time scale: the 4th argument of `create_timer`, or `tween.set_ignore_time_scale()`.
- **Inherited scenes.** Edit shared things in `blob.tscn`, not in `player.tscn`. Otherwise you create an override that silently stops following the base scene.
