# Lays out Don't Get Fat! levels 0 to 5 section by section and writes them
# as static map scenes (level/maps/fat_N/fat_N.tscn + fat_N_rules.tres).
# Seeded, so the output is the same every time. Running it again OVERWRITES
# the levels, hand edits included: change the layout here, or edit the scenes
# by hand and stop running it. For more or less of something without a new
# layout, change the feeder's rates in a level's _rules.tres instead (they
# apply while the game runs).
# Usage, from the project folder: python3 tools/make_fat_levels.py . [levels...]
import random, sys, os

KINDS = ["burger", "fries", "cake", "donut", "soda", "bed", "tv", "apple", "carrot", "broccoli", "water",
         "dumbbell", "football", "egg", "fish", "drumstick", "bread", "rice", "corn", "banana"]
POWERS = ["golden", "sneakers", "sugar_crash"]
BURN = 0.08  # kg/s the buddy burns on its own (FatSettings.burn)
GROUP = {"egg": "protein", "fish": "protein", "drumstick": "protein", "bread": "grains", "rice": "grains",
         "corn": "grains", "apple": "veg", "carrot": "veg", "broccoli": "veg", "banana": "veg",
         "burger": "treat", "fries": "treat", "cake": "treat", "donut": "treat", "soda": "treat",
         "bed": "lazy", "tv": "lazy", "dumbbell": "active", "football": "active", "water": "water"}
KG = {"burger": 3.0, "fries": 2.5, "cake": 3.0, "donut": 2.5, "soda": 2.0, "bed": 1.5, "tv": 1.5,
      "egg": 0.5, "fish": 0.5, "drumstick": 0.6, "bread": 0.5, "rice": 0.5, "corn": 0.4,
      "apple": 0.3, "carrot": 0.3, "broccoli": 0.3, "banana": 0.4, "water": -0.5, "dumbbell": -2.5, "football": -2.5}
FEED = {  # seconds between the feeder's drops, per level: workouts, beds, water, plate food, treats
    1: (7.0, 16.0, 14.0, 0.0, 0.0),
    2: (6.5, 15.0, 13.0, 6.0, 7.0),
    3: (6.0, 14.0, 12.0, 5.0, 6.0),
    4: (6.0, 13.0, 12.0, 5.0, 5.0),
    5: (5.5, 12.0, 11.0, 4.5, 4.5),
}
FLOAT = 600  # power-ups float: placed this much nearer the start than where they should meet the blobs
XS6 = [-300, -180, -60, 60, 180, 300]


class Level:
    def __init__(self, n, title, seed, **rules):
        self.n, self.title, self.rules = n, title, rules
        if n in FEED:
            for key, v in zip(["feed_workouts", "feed_beds", "feed_water", "feed_food", "feed_treats"], FEED[n]):
                self.rules[key] = v
        self.r = random.Random(seed)
        self.items, self.powers, self.walls, self.bumps, self.signs, self.rushes = [], [], [], [], [], []
        self.d = 450.0  # the cursor: distance up the belt (y = -d)
        self.pal = {}
        self.obs_kinds, self.obs_rate = [], 0.0

    def seq(self, *steps):
        """Content sections in order, with an obstacle between them now and then (obs_rate)."""
        for step in steps:
            step()
            if self.obs_kinds and self.r.random() < self.obs_rate:
                self.obstacle()

    def obstacle(self):
        """Something to dodge round, with only a little food: a sliding wall, a splitter, a slalom, bumpers..."""
        kind = self.r.choice(self.obs_kinds)
        if kind == "slider":
            self.sliders(self.r.choice([1, 2]))
        elif kind == "splitter":
            self.splitter()
        elif kind == "slalom":
            side = self.r.choice([-1, 1])
            for i in range(3):
                self.wall(side * 150, self.d, 400, 24)
                self.item(self.good(), -side * 250, self.d + 120)
                side = -side
                self.d += 300
            self.d += 120
        elif kind == "bumpers":
            self.bumpers(2)
        elif kind == "funnel":
            self.funnel(gap_x=self.r.choice([-120, 0, 120]), gap_w=220, then=2)
        elif kind == "kickers":
            self.kickers(2)
        elif kind == "twin":
            self.gate_walls(self.r.choice([1, 2]))

    # pieces
    def item(self, kind, x, d, sway=0, sway_time=3.0):
        self.items.append((kind, x, d, sway, sway_time))

    def power(self, kind, x, d):
        self.powers.append((kind, x, d - FLOAT))

    def wall(self, x, d, w, h, kicker=False, slide=0, slide_time=3.0):
        self.walls.append((x, d, w, h, kicker, slide, slide_time))

    def bumper(self, x, d):
        self.bumps.append((x, d))

    def sign(self, text, gap=380):
        self.signs.append((text, self.d))
        self.d += gap

    def pick(self, group):
        return self.r.choice(self.pal[group])

    def good(self):
        return self.pick(self.r.choice(["protein", "grains", "veg"]))

    def junk(self):
        return self.pick("treat") if self.r.random() < 0.85 or not self.pal.get("lazy") else self.pick("lazy")

    def gap(self, px):
        self.d += px

    # sections: each starts at the cursor and moves it past what it placed
    def snake(self, n, kinds, amp=180, step=130, phase=0.0):
        import math
        for i in range(n):
            self.item(kinds[i % len(kinds)], round(math.sin(phase + i * 0.55) * amp), self.d)
            self.d += step
        self.d += 120

    def pairs(self, n, step=230, spread=180):
        """Rows of a good item and a junk one, sides swapping: a choice every row."""
        for i in range(n):
            side = self.r.choice([-1, 1])
            self.item(self.good(), side * spread + self.r.randint(-40, 40), self.d)
            self.item(self.junk(), -side * spread + self.r.randint(-40, 40), self.d)
            self.d += step
        self.d += 100

    def junk_rows(self, n, goods=1, step=330):
        """Rows of six across, junk except for `goods` gaps of good stuff."""
        for i in range(n):
            slots = self.r.sample(range(6), goods)
            for j, x in enumerate(XS6):
                self.item(self.good() if j in slots else self.junk(), x, self.d)
            self.d += step
        self.d += 80

    def scatter(self, n, good_share=0.65, step=110):
        for i in range(n):
            self.item(self.good() if self.r.random() < good_share else self.junk(), self.r.randint(-290, 290), self.d)
            self.d += step
        self.d += 100

    def diagonal(self, kinds, n, step=90, x0=-280, x1=280):
        for i in range(n):
            self.item(kinds[i % len(kinds)], round(x0 + (x1 - x0) * i / max(n - 1, 1)), self.d)
            self.d += step
        self.d += 120

    def funnel(self, gap_x=0, gap_w=240, then=4):
        """Two walls from the sides with a gap; good stuff lined up in the gap after it, junk beside."""
        left_end, right_start = gap_x - gap_w / 2, gap_x + gap_w / 2
        self.wall((-350 + left_end) / 2, self.d, left_end + 350, 24)
        self.wall((350 + right_start) / 2, self.d, 350 - right_start, 24)
        self.d += 170
        for i in range(then):
            self.item(self.good(), gap_x, self.d)
            if self.r.random() < 0.5:
                self.item(self.junk(), gap_x + self.r.choice([-1, 1]) * 190, self.d + 40)
            self.d += 150
        self.d += 100

    def splitter(self, w=220):
        """A wall in the middle: go round it left or right; each side has its own bite."""
        self.wall(0, self.d, w, 24)
        self.d += 150
        self.item(self.good(), -220, self.d)
        self.item(self.junk(), 220, self.d)
        self.d += 260

    def lanes(self, n, step=210, length_pad=200):
        """A divider down the middle: one lane mostly good, the other mostly junk (sides vary)."""
        start = self.d
        good_side = self.r.choice([-1, 1])
        for i in range(n):
            g_x = good_side * 175 + self.r.randint(-50, 50)
            j_x = -good_side * 175 + self.r.randint(-50, 50)
            self.item(self.good() if self.r.random() < 0.8 else self.junk(), g_x, self.d)
            self.item(self.junk() if self.r.random() < 0.8 else self.good(), j_x, self.d + 60)
            self.d += step
        length = self.d - start + length_pad
        self.wall(0, start - 100 + length / 2, 24, length)
        self.d += 220

    def three_lanes(self, rows, step=200, split_at=None):
        """Walls at x = +-117 make three lanes; each lane has its own mix; a gap halfway lets you switch."""
        start = self.d
        mixes = self.r.sample([("protein", "treat"), ("grains", "veg"), ("veg", "treat"), ("protein", "grains"),
                               ("treat", "lazy" if self.pal.get("lazy") else "treat")], 3)
        for i in range(rows):
            for lane, x in enumerate([-233, 0, 233]):
                g = mixes[lane][i % 2]
                self.item(self.pick(g), x, self.d)
            self.d += step
        end = self.d
        mid = (start + end) / 2 if split_at is None else split_at
        for x in [-117, 117]:
            a0, a1 = start - 80, mid - 90
            b0, b1 = mid + 90, end + 40
            self.wall(x, (a0 + a1) / 2, 24, a1 - a0)
            self.wall(x, (b0 + b1) / 2, 24, b1 - b0)
        self.d += 240

    def lazy_zone(self, rows=4, step=280):
        """Lazing about (beds, TVs) next to activity: the activity burns weight off."""
        for i in range(rows):
            xs = self.r.sample([-250, -50, 150, 260], 3)
            self.item(self.pick("lazy"), xs[0], self.d)
            self.item(self.pick("active"), xs[1], self.d)
            if self.r.random() < 0.6:
                self.item(self.pick("lazy"), xs[2], self.d)
            self.d += step
        self.d += 100

    def kickers(self, n, step=380):
        for i in range(n):
            side = -1 if i % 2 == 0 else 1
            self.wall(side * 250, self.d, 130, 24, kicker=True)
            self.item(self.good(), -side * 60, self.d + 90)
            if self.r.random() < 0.6:
                self.item(self.junk(), side * 40, self.d + 210)
            self.d += step
        self.d += 120

    def bumpers(self, n=2, step=320):
        for i in range(n):
            x = self.r.choice([-200, 0, 200])
            self.bumper(x, self.d)
            self.item(self.good(), -x * 0.6 + self.r.randint(-60, 60), self.d + 130)
            self.d += step
        self.d += 80

    def sway_rows(self, n, amp=110, step=300):
        for i in range(n):
            for x in [-200, 0, 200]:
                kind = self.good() if self.r.random() < 0.45 else self.junk()
                self.item(kind, x, self.d, sway=amp if i % 2 == 0 else -amp, sway_time=2.6)
            self.d += step
        self.d += 100

    def montage(self, n=8, step=160):
        """The training montage: a stretch of workouts and water, no treats, under a WORKOUT! sign."""
        self.sign("WORKOUT!", gap=260)
        for i in range(n):
            x = self.r.choice([-220, -80, 80, 220])
            self.item(self.pick("active"), x, self.d)
            if i % 3 == 1:
                self.item("water", -x * 0.8, self.d + 60)
            self.d += step
        self.d += 200

    def weigh_in(self, n=6, step=170):
        """The last stretch: food one side, activity the other, so a team can fine-tune its weight."""
        for i in range(n):
            side = -1 if i % 2 == 0 else 1
            self.item(self.good(), side * 190, self.d)
            self.item(self.pick("active") if i % 2 == 0 else "water", -side * 190, self.d + 50)
            self.d += step
        self.d += 250

    def capsule(self, kind, x=None, then=None):
        """A power-up bubble, then what it's for: a food field (magnet, sneakers), a junk pile (golden), or junk around good stuff (sugar crash)."""
        x = self.r.choice([-200, 0, 200]) if x is None else x
        self.power(kind, x, self.d)
        self.d += 200
        if then == "field":
            self.scatter(8, good_share=0.75, step=95)
        elif then == "pile":
            for i in range(7):
                self.item(self.junk(), self.r.randint(-260, 260), self.d)
                self.d += 80
            self.d += 120
        elif then == "tempt":
            self.scatter(6, good_share=0.4, step=110)

    def sliders(self, n, step=420, amp=150):
        """Moving walls: a wall slides across the middle, never past the track's edges; items to grab between."""
        for i in range(n):
            w = self.r.choice([220, 280])
            a = min(amp, 350 - w / 2 - 30)
            self.wall(0, self.d, w, 24, slide=a if i % 2 == 0 else -a, slide_time=self.r.choice([2.4, 3.0, 3.6]))
            self.item(self.good(), self.r.randint(-250, 250), self.d + 170)
            if self.r.random() < 0.5:
                self.item(self.junk(), self.r.randint(-250, 250), self.d + 270)
            self.d += step
        self.d += 120

    def gate_walls(self, n, step=460):
        """Two walls sliding together: the gap between them and the gaps at the sides open and close."""
        for i in range(n):
            slide = 75 if i % 2 == 0 else -75
            self.wall(-175, self.d, 160, 24, slide=slide, slide_time=3.2)
            self.wall(175, self.d, 160, 24, slide=slide, slide_time=3.2)
            self.item(self.good(), 0, self.d + 160)
            self.item(self.junk(), self.r.choice([-250, 250]), self.d + 160)
            self.d += step
        self.d += 120

    def rush(self, inner):
        start = self.d
        self.d += 150
        inner()
        self.rushes.append((start, self.d - start))
        self.d += 250

    # output
    def write(self, root):
        name = "fat_%d" % self.n
        folder = os.path.join(root, "level", "maps", name)
        os.makedirs(folder, exist_ok=True)
        length = round(self.d + 300)
        self.length = length
        if self.rules.get("plate", True):
            # A full plate plus the burn lands 2 kg under the middle of the window: a little room for extras.
            speed = (self.rules["scroll_start"] + self.rules["scroll_end"]) / 2
            plate_kg = 3 * self.rules["plate_target"] * 0.42
            mid = (self.rules["window_low"] + self.rules["window_high"]) / 2
            start = mid - 2.0 - plate_kg + BURN * length / speed
            self.rules["start_weight"] = round(min(start, self.rules["window_low"] - 1.0) * 2) / 2  # always start hungry
        with open(os.path.join(folder, name + "_rules.tres"), "w") as f:
            f.write('[gd_resource type="Resource" script_class="FatRules" format=3]\n\n')
            f.write('[ext_resource type="Script" path="res://modes/dont_get_fat/fat_rules.gd" id="1_script"]\n\n')
            f.write('[resource]\nscript = ExtResource("1_script")\ntitle = "%s"\n' % self.title)
            for k, v in self.rules.items():
                f.write("%s = %s\n" % (k, ("true" if v else "false") if isinstance(v, bool) else
                                      (("%d" % v) if isinstance(v, int) else ("%.1f" % v))))
        out = ['[gd_scene format=3]\n',
               '[ext_resource type="Script" path="res://level/maps/map.gd" id="1_map"]',
               '[ext_resource type="Resource" path="res://level/maps/%s/%s_rules.tres" id="2_rules"]' % (name, name),
               '[ext_resource type="PackedScene" path="res://level/pickups/health/health_item.tscn" id="3_item"]',
               '[ext_resource type="PackedScene" path="res://level/pickups/health/power_up.tscn" id="4_power"]',
               '[ext_resource type="PackedScene" path="res://level/obstacles/wall_block.tscn" id="5_wall"]',
               '[ext_resource type="PackedScene" path="res://level/obstacles/bumper.tscn" id="6_bumper"]',
               '[ext_resource type="Script" path="res://level/maps/spawn_point.gd" id="7_spawn"]',
               '[ext_resource type="Script" path="res://level/maps/gate.gd" id="8_gate"]',
               '[ext_resource type="Script" path="res://level/maps/belt_sign.gd" id="9_sign"]',
               '[ext_resource type="Script" path="res://level/maps/rush_zone.gd" id="10_rush"]\n',
               '[node name="Fat%d" type="Node2D"]\nscript = ExtResource("1_map")\nrules = ExtResource("2_rules")\n' % self.n,
               '[node name="Signs" type="Node2D" parent="."]\n']
        for i, (text, d) in enumerate(self.signs):
            out.append('[node name="Sign%d" type="Node2D" parent="Signs"]\nscript = ExtResource("9_sign")\n'
                       'position = Vector2(0, %d)\ntext = "%s"\n' % (i + 1, -round(d), text))
        out.append('[node name="Rushes" type="Node2D" parent="."]\n')
        for i, (d, length_) in enumerate(self.rushes):
            out.append('[node name="Rush%d" type="Node2D" parent="Rushes"]\nscript = ExtResource("10_rush")\n'
                       'position = Vector2(0, %d)\nlength = %.1f\n' % (i + 1, -round(d), length_))
        out.append('[node name="Items" type="Node2D" parent="."]\n')
        counts = {}
        for kind, x, d, sway, sway_time in sorted(self.items, key=lambda it: it[2]):
            counts[kind] = counts.get(kind, 0) + 1
            node = '[node name="%s%d" parent="Items" instance=ExtResource("3_item")]\nposition = Vector2(%d, %d)\nkind = %d\n' % (
                kind.capitalize(), counts[kind], round(x), -round(d), KINDS.index(kind))
            if sway:
                node += "sway = %.1f\nsway_time = %.1f\n" % (sway, sway_time)
            out.append(node)
        out.append('[node name="PowerUps" type="Node2D" parent="."]\n')
        pc = {}
        for kind, x, d in self.powers:
            pc[kind] = pc.get(kind, 0) + 1
            nm = "".join(p.capitalize() for p in kind.split("_"))
            out.append('[node name="%s%d" parent="PowerUps" instance=ExtResource("4_power")]\nposition = Vector2(%d, %d)\nkind = %d\n' % (
                nm, pc[kind], round(x), -round(d), POWERS.index(kind)))
        out.append('[node name="Obstacles" type="Node2D" parent="."]\n')
        for i, (x, d) in enumerate(self.bumps):
            out.append('[node name="Bumper%d" parent="Obstacles" instance=ExtResource("6_bumper")]\nposition = Vector2(%d, %d)\n' % (
                i + 1, round(x), -round(d)))
        for i, (x, d, w, h, kicker, slide, slide_time) in enumerate(sorted(self.walls, key=lambda w_: w_[1])):
            node = '[node name="%s%d" parent="Obstacles" instance=ExtResource("5_wall")]\nposition = Vector2(%d, %d)\nsize = Vector2(%d, %d)\n' % (
                "Kicker" if kicker else ("Slider" if slide else "Wall"), i + 1, round(x), -round(d), round(w), round(h))
            if kicker:
                node += "kicker = true\n"
            if slide:
                node += "slide = %.1f\nslide_time = %.1f\n" % (slide, slide_time)
            out.append(node)
        out.append('[node name="Spawns" type="Node2D" parent="."]\n')
        for s in range(4):
            out.append('[node name="P%d" type="Node2D" parent="Spawns"]\nscript = ExtResource("7_spawn")\nposition = Vector2(%d, 150)\n%s' % (
                s + 1, -150 + 100 * s, "" if s == 0 else "seat = %d\n" % (s + 1)))
        out.append('[node name="Gate" type="Node2D" parent="."]\nscript = ExtResource("8_gate")\nposition = Vector2(0, %d)\n' % -length)
        with open(os.path.join(folder, name + ".tscn"), "w") as f:
            f.write("\n".join(out))
        self.report(counts)

    def report(self, counts):
        by = {}
        for k, c in counts.items():
            by.setdefault(GROUP[k], []).append(c)
        healthy = [k for k in counts if GROUP[k] in ("protein", "grains", "veg")]
        n_healthy = sum(counts[k] for k in healthy)
        avg = sum(KG[k] * counts[k] for k in healthy) / max(n_healthy, 1)
        speed_ = (self.rules["scroll_start"] + self.rules["scroll_end"]) / 2
        need = (self.rules["window_low"] + self.rules["window_high"]) / 2 - self.rules["start_weight"] + BURN * self.length / speed_
        ideal = "%d servings (%.0f%% of %d) to the middle" % (need / avg, 100 * need / avg / max(n_healthy, 1), n_healthy)
        speed = (self.rules["scroll_start"] + self.rules["scroll_end"]) / 2
        print("fat_%d %-12s %5d px ~%2.0f s | %s | plate %d: protein %d grains %d veg %d | treats %d lazy %d active %d water %d | powers %d walls %d | start %.1f, %s, window %s-%s" % (
            self.n, self.title, self.length, self.length / speed, "plate" if self.rules.get("plate", True) else "no plate",
            self.rules.get("plate_target", 4),
            sum(by.get("protein", [])), sum(by.get("grains", [])), sum(by.get("veg", [])), sum(by.get("treat", [])),
            sum(by.get("lazy", [])), sum(by.get("active", [])), sum(by.get("water", [])), len(self.powers),
            len(self.walls), self.rules["start_weight"], ideal, self.rules["window_low"], self.rules["window_high"]))


def level0():
    L = Level(0, "WARM-UP", 100, start_weight=66.5, window_low=66.0, window_high=76.0, scroll_start=210.0,
              scroll_end=250.0, plate=False, treat_slots=3)
    L.pal = {"protein": ["egg"], "grains": ["bread"], "veg": ["apple", "banana", "carrot"], "treat": ["burger", "donut", "soda"],
             "active": ["dumbbell", "football"], "lazy": []}
    L.sign("CATCH THE FOOD")
    for i in range(7):
        L.item(["apple", "banana", "carrot"][i % 3], 0, L.d)
        L.d += 150
    L.gap(250)
    L.sign("TREATS WEIGH A LOT")
    for kind, good in [("burger", "apple"), ("donut", "banana"), ("soda", "bread"), ("burger", "egg")]:
        L.item(kind, 0, L.d)
        L.item(good, L.r.choice([-200, 200]), L.d)
        L.d += 280
    L.gap(200)
    L.sign("ACTIVITY BURNS IT OFF")
    for i in range(4):
        L.item("dumbbell" if i % 2 == 0 else "football", L.r.choice([-180, 0, 180]), L.d)
        L.item(L.good(), L.r.choice([-260, 260]), L.d + 140)
        L.d += 300
    L.gap(200)
    L.sign("PICK A LANE")
    L.lanes(5, step=220)
    L.sign("GRAB THE BUBBLES")
    L.capsule("sneakers", 0, then="field")
    L.gap(150)
    L.sign("LAND IN THE WINDOW")
    L.weigh_in(5)
    return L


def level1():
    L = Level(1, "BREAKFAST", 101, start_weight=0.0, window_low=72.0, window_high=78.0, scroll_start=280.0,
              scroll_end=330.0, plate_target=4, treat_slots=5)
    L.pal = {"protein": ["egg"], "grains": ["bread", "corn"], "veg": ["banana", "apple"],
             "treat": ["donut", "soda", "cake"], "lazy": ["bed"], "active": ["football", "dumbbell"]}
    L.obs_kinds, L.obs_rate = ["slider", "splitter", "slalom", "bumpers"], 0.5
    L.sign("FILL THE PLATE", gap=300)
    L.seq(lambda: L.snake(6, ["banana", "egg", "bread"], amp=160),
          lambda: L.pairs(5),
          lambda: L.funnel(gap_x=-60),
          lambda: L.scatter(10, good_share=0.6),
          lambda: L.lazy_zone(3),
          lambda: L.junk_rows(2, goods=2),
          lambda: L.capsule("sneakers", then="field"),
          lambda: L.montage(),
          lambda: L.pairs(5),
          lambda: L.scatter(10, good_share=0.6),
          lambda: L.junk_rows(2, goods=2))
    L.weigh_in(6)
    return L


def level2():
    L = Level(2, "LUNCH RUSH", 102, start_weight=0.0, window_low=72.0, window_high=78.0, scroll_start=300.0,
              scroll_end=360.0, plate_target=5, treat_slots=5)
    L.pal = {"protein": ["fish", "drumstick"], "grains": ["rice", "bread"], "veg": ["carrot", "broccoli", "apple"],
             "treat": ["burger", "fries", "soda"], "lazy": ["tv"], "active": ["football", "dumbbell"]}
    L.obs_kinds, L.obs_rate = ["slider", "splitter", "slalom", "bumpers", "funnel"], 0.55
    L.sign("PICK A LANE", gap=300)
    L.seq(lambda: L.snake(6, ["carrot", "rice", "fish"], amp=170),
          lambda: L.lanes(5),
          lambda: L.scatter(8),
          lambda: L.three_lanes(6),
          lambda: L.junk_rows(2, goods=2),
          lambda: L.capsule("sneakers", then="field"),
          lambda: L.montage(),
          lambda: L.lazy_zone(3),
          lambda: L.three_lanes(6),
          lambda: L.pairs(5))
    L.weigh_in(6)
    return L


def level3():
    L = Level(3, "SNACK ATTACK", 103, start_weight=0.0, window_low=73.0, window_high=77.0, scroll_start=320.0,
              scroll_end=380.0, plate_target=6, treat_slots=5)
    L.pal = {"protein": ["egg", "drumstick"], "grains": ["corn", "bread"], "veg": ["apple", "banana", "carrot"],
             "treat": ["donut", "soda", "fries", "cake"], "lazy": ["tv", "bed"], "active": ["football", "dumbbell"]}
    L.obs_kinds, L.obs_rate = ["slider", "splitter", "slalom", "bumpers", "funnel", "kickers"], 0.7
    L.sign("GOOD BUBBLES AND BAD", gap=300)
    L.seq(lambda: L.snake(6, ["apple", "corn", "egg"], amp=170),
          lambda: L.capsule("sneakers", then="field"),
          lambda: L.pairs(4),
          lambda: L.capsule("sugar_crash", then="tempt"),
          lambda: L.lanes(4),
          lambda: L.capsule("golden", then="pile"),
          lambda: L.capsule("sugar_crash", then="tempt"),
          lambda: L.three_lanes(5),
          lambda: L.pairs(4),
          lambda: L.montage(),
          lambda: L.capsule("golden", then="pile"))
    L.weigh_in(6)
    return L


def level4():
    L = Level(4, "DINNER", 104, start_weight=0.0, window_low=73.0, window_high=77.0, scroll_start=330.0,
              scroll_end=390.0, plate_target=7, treat_slots=5)
    L.pal = {"protein": ["fish", "drumstick"], "grains": ["rice", "corn"], "veg": ["broccoli", "carrot"],
             "treat": ["burger", "fries", "cake"], "lazy": ["tv"], "active": ["football", "dumbbell"]}
    L.obs_kinds, L.obs_rate = ["slider", "splitter", "slalom", "bumpers", "funnel", "kickers", "twin", "twin"], 0.75
    L.sign("WALLS CLOSE IN", gap=300)
    L.seq(lambda: L.snake(6, ["broccoli", "rice", "fish"], amp=170),
          lambda: L.gate_walls(3),
          lambda: L.pairs(4),
          lambda: L.capsule("sneakers", then="field"),
          lambda: L.lanes(4),
          lambda: L.montage(),
          lambda: L.capsule("sugar_crash", then="tempt"),
          lambda: L.three_lanes(5),
          lambda: L.gate_walls(2),
          lambda: L.capsule("golden", then="pile"))
    L.weigh_in(6)
    return L


def level5():
    L = Level(5, "DESSERT", 105, start_weight=0.0, window_low=74.0, window_high=76.0, scroll_start=320.0,
              scroll_end=380.0, rush_speed=1.45, plate_target=8, treat_slots=5)
    L.pal = {"protein": ["egg", "fish"], "grains": ["bread", "rice"], "veg": ["banana", "apple"],
             "treat": ["cake", "donut", "soda"], "lazy": ["bed"], "active": ["football", "dumbbell"]}
    L.obs_kinds, L.obs_rate = ["slider", "splitter", "slalom", "bumpers", "funnel", "kickers", "twin"], 1.0
    L.sign("RUSH!", gap=300)
    L.seq(lambda: L.snake(6, ["banana", "bread", "egg"], amp=170),
          lambda: L.rush(lambda: L.scatter(10, good_share=0.6, step=120)),
          lambda: L.lanes(4),
          lambda: L.capsule("sneakers", then="field"),
          lambda: L.rush(lambda: (L.pairs(4, step=260), L.junk_rows(1, goods=2))),
          lambda: L.three_lanes(5),
          lambda: L.capsule("sugar_crash", then="tempt"),
          lambda: L.montage(),
          lambda: L.capsule("golden", then="pile"),
          lambda: L.rush(lambda: (L.funnel(gap_x=0), L.scatter(8, step=120))))
    L.weigh_in(6)
    return L


if __name__ == "__main__":
    root = sys.argv[1]
    which = [int(a) for a in sys.argv[2:]] or list(range(6))
    for n in which:
        [level0, level1, level2, level3, level4, level5][n]().write(root)
