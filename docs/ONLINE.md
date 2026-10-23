# Online play

Playing on several computers: this Windows PC and a Linux laptop on the same
network for now, later over slower connections (the design has to hold up at
about 100 ms round trip). Agreed 2026-10-23.

## How it works

**The host runs the game; the others send their presses and show what the
host sends back.** Every computer simulating the game itself (lockstep) is
out: Windows and Linux builds compute `pow`/`sin` slightly differently, and
the copies would drift apart in seconds.

- `Net` (autoload, `autoload/net.gd` + `net.tscn`) is the only thing that
  touches the network. One copy hosts (ENet over UDP, port 24680), the others
  join. Messages are a type and some data: `Net.send(to, type, data,
  reliable)` (`to`: a peer id, 1 is the host, 0 is everyone) and
  `Net.message(from, type, data)`. Reliable messages (channel 0) arrive in
  order; unreliable ones (channel 1) may be lost, for things sent every frame.
  Clients only ever talk to the host.
- Handshake: a joining copy sends `hello` (name, `Net.PROTOCOL`); the host
  answers `welcome` or `reject` (another version). Then `roster` (everyone's
  names), `status` (the host is in the lobby, or playing a game), `ping` /
  `pong` twice a second (the ping, and the host's clock:
  `Net.host_time_usec()`), and `bye` when the host stops. **Bump
  `Net.PROTOCOL` whenever a message changes.**
- Each computer has a player name (`Session.player_name`, the computer's
  name to begin with) and remembers the games it joined
  (`Session.recent_hosts`). Hosted games answer `LanDiscovery` broadcasts on
  port 24681, so they show up on the online screen without typing anything.
- In someone else's game, the host's choices decide the rules
  (`GameSettings.use_host_settings()`): every option but the menu's and
  lab's own, and those marked `local` (the energy bar). The look stays each
  player's own.
- `PlayerSlot.peer` is the computer a seat's player is on (1 offline or on
  the host). `to_net()` / `from_net()` turn a seat into plain data.
- ENet's throttling is off (`Net.THROTTLE`): it would drop the per-frame
  updates for a while after any hitch, like a scene loading.

## The games

When the host loads a game (from the lobby, a restart, Don't Get Fat!'s
next level), its `NetGame` (`core/net/net_game.gd`, a child `GameMode`
adds) sends `match` (the scene, the lineup, `GameMode.net_match_info()`:
Don't Get Fat!'s run and level), and every joined computer loads it too,
whatever screen it's on, someone who joined mid-game included: they watch.
When the host goes back to the lobby, everyone does.

- **The host plays the game as always.** A seat whose player is on another
  computer gets a `RemoteInput` (a `PlayerInput` fed from the network)
  instead of reading keys, so everything that reads a `PlayerInput` (the
  blob, Don't Get Fat!'s upgrade cards) works for them.
- **A joined computer plays none of it.** It loads the same scene, but every
  node's `_physics_process` is off there (except group `net_local`: things
  that only animate, like the neon grid), the mode spawns nothing, and the
  mode's `_process` is off (`GameMode.net_mirror()` is for what a mode keeps
  up there itself: the treadmill's scrolling grid). It shows the host's game
  and sends its players' keys (`ni`: steering, and how many times each
  button was pressed so far, every physics frame).
- **Entities**: a node with `net_state()` (an Array) and `net_apply()`.
  Ones from a scene file (the mode, the HUD, the camera, the ring's lasers,
  a map's items) are known by path; ones made during the game (blobs,
  slashes, spit, food, the treadmill's walls, the feeder's items) get a
  number, and the others make a copy from the same scene file
  (`net_spawn()` -> `net_setup()` for what the copy needs, plus its
  position). A joined computer frees any it makes on its own. Changed
  states go out every physics frame, unreliable, and all of them every
  half second (`ns`, in packets of up to 1000 bytes so the network never
  splits one: a lost packet loses only its part of the frame); made,
  happened and gone go reliable (`nw`). F3 on the host shows how big they get
  (Football with five blobs: about 1.3 KB a frame).
- **Smoothing**: a joined computer shows the game `_delay` in the past (the
  updates' age, plus a frame and a half, plus room for the jitter: about
  30 ms at home) and blends between the two updates either side: numbers,
  vectors and colours blend, the rest switches.
- **Effects**: `Juice` and `Sfx` calls, and a node's `fx_...` methods that
  call `NetGame.relay()` (the ring's wall flashing, a kicker or bumper
  lighting up), play on every computer at the same moment of the game.
  A sound only for this computer (its own menu) uses `Sfx.play_here()`.
- **Colours**: each computer draws in its own theme, so a joined computer
  swaps the host's player colours for its own wherever they turn up in
  states and effects (a shot, slime, a banner). Effects in a lightened
  player colour (bursts) stay in the host's.
- **The music**: a joined computer counts beats from the host's start
  (`Techno.sync_start()`), shifted by `_delay`, so the beat lasers fire when
  they're shown.
- **Menus**: online the pause menu doesn't stop the game (this computer's
  players let go while it's open); only the host restarts, and its QUIT
  takes everyone back to the lobby. A joined computer's QUIT goes to the
  lobby alone and comes back for the next game.
- Online, every human gets a tag (P1...) and the name of their computer
  ("LAPTOP", "LAPTOP P2" with two there); the banners never say YOU.
- Adding something to a game: if it changes during play and isn't a Juice
  or Sfx effect, give it `net_state()` / `net_apply()` (and `net_spawn()` /
  `net_setup()` if it's made during the game), and route one-off visual
  effects through an `fx_` method that calls `NetGame.relay()`. Check it
  with `tools/net_test.sh` and a screenshot of both sides.

## The lobby

The host's lobby is the real one; the others show a copy. After every
change the host sends `lobby_state` (the game, the shared settings, PLAYERS,
the seats, who's ready, the keyboard halves, messages). A joined computer
reads its own keyboard and controllers as before, keeps looking around
(GAME/PLAYERS, the GAME list's focus) to itself, but goes along when the
host switches between GAME and PLAYERS, and sends the presses that
change something as `lobby_act` [device, action]; the host handles them
like its own, keyed `"<peer>/<device>"`. Only the host changes the game and
the rules and starts; a client's confirm starts the game when everyone's
ready. Back with nobody joined, twice, stops hosting or leaves. The strip at
the top shows the host its addresses (to tell the others) and who's in;
the others see whose game it is and their ping. Going back to the main menu
always ends the online game.

## Testing on one computer

1. **Two copies from the editor:** Debug → Customize Run Instances → 2, with
   launch arguments `-- --host` for one and `-- --join=127.0.0.1 --name=LAPTOP`
   for the other. Both open straight into the lobby.
2. **Pretend lag:** SETTINGS → NETWORK TEST (PRETEND LAG, JITTER, LOSS), or
   `--lag=100 --jitter=30 --loss=5` on the command line. The copy holds every
   message back for half the round trip each way; unreliable ones can be
   lost. One copy with it set feels the whole lag. F3 shows the network
   overlay: who's in, pings, the pretend lag, messages per second.
3. **Headless test:** `tools/net_test.sh` runs a host and a client from a
   copy of the project (the editor can stay open) and prints PASS or FAIL:
   lobby, seat, ready, the game, the client's blob moving on both, back to
   the lobby. Extra arguments go to the client: `tools/net_test.sh
   --lag=200 --loss=15`. `GAME=FOOTBALL` (TREADMILL, "DON'T GET FAT!": with
   the report card, an upgrade pick from the client and level 2) plays
   another game; `LATE=1` adds a third copy that joins during the game. It
   prints how long the client's blob took to answer a press. With
   `shots=DIR` in `tools/net_test.gd`'s arguments (run by hand, without
   `--headless`) both copies save a screenshot.
4. **Windows against Linux:** build both (`tools/export_builds.sh`), run the
   Linux build in WSL and the Windows build on Windows. This PC's WSL shares
   the PC's addresses (mirrored networking), so `127.0.0.1` works between them.
   Hosting in WSL avoids a firewall prompt on Windows.

## Builds

`tools/export_builds.sh` exports the "Windows Desktop" and "Linux" presets
(one file each, the game packed in) into `C:/godot_exports/bumper_blobs/`.
On the laptop: `chmod +x BumperBlobs.x86_64`. The first time a copy hosts
on Windows, the firewall asks: allow it on private networks. The Web build
can't play online (ENet needs real UDP sockets).

## Steps

1. ~~Exports, the online screen, hosting and joining, the lobby on every computer.~~
2. ~~Ring: blobs, shots, slashes and effects over the network.~~
3. ~~Football: the ball, the clock, goals.~~
4. ~~Treadmill: the track, lasers, food.~~
5. ~~Don't Get Fat!: the buddy, items, the report card and upgrade cards.~~
6. Decide on prediction (below), after playing with pretend lag.

Joining during a match: the newcomer watches and gets a seat back in the
lobby.

## What lag does, and what's planned for it

Without prediction a client sees its own blob answer about a round trip plus
the smoothing late. Measured with `tools/net_test.sh` (a press until the
blob has moved 2 px; on the host itself that takes about 50 ms, the blob
speeding up): on this computer about 95 ms (45 more), with 100 ms of pretend
lag about 220 ms (170 more). Options, cheapest first: predict your own blob's movement
(instant steering; it snaps when the host decides a bump), lag compensation
on the host for pushes, slashes and shields, and full rollback (a rewrite
of how everything updates; only if the others aren't enough). So that the
first two stay possible, everything networked is built for them:

- inputs are sent per physics frame with frame numbers, each packet repeating
  the last few, so a lost packet never loses a press;
- the host's updates carry frame numbers and clients keep a smoothing buffer
  that grows with jitter;
- every networked thing can save and apply its state;
- effects and sounds go through one place (`Juice`, `Sfx`);
- every computer knows the host's clock, so the music and beat-timed lasers line up.
