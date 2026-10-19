class_name FatBody
extends RefCounted
## What the buddy in Don't Get Fat! has eaten and built, and what the run's
## upgrades change about it. Buddy.feed() hands every catch to eat(), which
## says how much weight it really adds and keeps the counts:
## - the plate (servings of protein, grains, veg) and the treat meter;
## - workouts: they take weight off by how far the buddy is from the middle
##   of the window (gentle when it's light, strong when it's heavy:
##   workout_scale()) and build muscle;
## - muscle: kept for the whole run (FatRun.muscle). Each point raises the
##   top of the window (MUSCLE_KG, up to MUSCLE_MAX_KG) and the burn
##   (MUSCLE_BURN), so a muscly buddy has more room but needs more food;
## - rest: each bed caught this level. Every point of rest makes each
##   workout build REST_BONUS more muscle.
## The mode makes one per level and sets the upgrade fields from the run.

const WORKOUT_KG := 2.5 # what a workout takes off at the middle of the window
const MUSCLE_KG := 0.05 # the top of the window goes up this much per point of muscle...
const MUSCLE_MAX_KG := 4.0 # ...up to this much
const MUSCLE_BURN := 0.0005 # kg/s more burnt per point of muscle, up to MUSCLE_MAX_KG's worth of points
const REST_BONUS := 0.25 # more muscle per workout for each point of rest

var plate: Array[int] = [0, 0, 0] # servings eaten, by HealthItem.Group: protein, grains, veg
var treats := 0 # treats eaten (not while golden)
var muscle := 0.0
var muscle_start := 0.0 # what it came into the level with
var rest := 0 # beds caught this level
var workouts := 0 # caught this level
var target := 4 # servings that fill a third (for Balanced bonus)

# From the run's upgrades (and leftovers), set by the mode.
var free_treats := 0 # the next this many treats weigh nothing and don't count (Iron stomach)
var treat_scale := 1.0 # treats' kg, times this (Insulin boost, Clean streak, Fibre)
var reps_floor := false # workouts never take it below the window (Healthy reps)
var muscle_per_rep := 1.0 # muscle a workout builds before rest (Gym membership)
var rest_per_bed := 1 # (Deep sleep)
var protein_muscle := 0.0 # muscle per protein serving (Protein shake)
var recovery := 0 # this many workouts build double muscle (leftover protein)
var sleepwalker := false # a bed is a workout too (Olympic sleepwalker)
var power_nap := false # beds weigh nothing and give sneakers (Power nap)
var tv_workouts := false # a TV is a workout instead of lazing (Workout videos)
var balanced_bonus := false # a full third's food weighs 25% less (Balanced bonus)
var water_chaser := false # water takes a treat back off the meter (Water chaser)
var runners_high := false # a workout makes every blob faster for a moment (Runner's high)


## kg the top of the window is raised by the muscle.
func muscle_room() -> float:
	return minf(muscle * MUSCLE_KG, MUSCLE_MAX_KG)


## kg/s burnt on top of the buddy's own burn, for the muscle.
func muscle_burn() -> float:
	return minf(muscle, MUSCLE_MAX_KG / MUSCLE_KG) * MUSCLE_BURN


## How strong a workout is for `buddy` now: 12% weaker per kg under the middle
## of the window, 12% stronger per kg over it, from 0.35x to 1.8x.
func workout_scale(buddy: Buddy) -> float:
	var mid := (buddy.low + buddy.top()) * 0.5
	return clampf(1.0 + 0.12 * (buddy.weight - mid), 0.35, 1.8)


## A catch of HealthItem.Kind `kind` (group `group`, `servings` on the plate)
## landing on `buddy`, which would add `kg` (`golden`: caught while golden).
## Returns [the kg it really adds, a word to pop up or ""].
func eat(buddy: Buddy, kind: int, group: int, kg: float, golden: bool, servings := 1) -> Array:
	var note := ""
	var workout := group == HealthItem.Group.ACTIVE
	var off := -kg if workout else WORKOUT_KG # what a workout takes off, before scaling
	if kind == HealthItem.Kind.BED:
		rest += rest_per_bed
		note = "REST %d" % rest
		workout = workout or sleepwalker
		if power_nap:
			kg = 0.0
			buddy.boost("sneakers", 3.0)
	elif kind == HealthItem.Kind.TV and tv_workouts:
		kg = 0.0
		workout = true
	if group == HealthItem.Group.TREAT and not golden:
		if free_treats > 0:
			free_treats -= 1
			kg = 0.0
			note = "FREE!"
		else:
			kg *= treat_scale
			treats += 1
	if group >= 0 and group < plate.size():
		if balanced_bonus and plate[group] >= target:
			kg *= 0.75
		plate[group] += servings
		if group == HealthItem.Group.PROTEIN:
			muscle += protein_muscle * servings
	if kind == HealthItem.Kind.WATER and water_chaser and treats > 0:
		treats -= 1
		note = "TREAT WASHED DOWN"
	if workout:
		if group == HealthItem.Group.ACTIVE:
			kg = 0.0
		var to := buddy.weight + kg - off * workout_scale(buddy)
		if reps_floor:
			to = maxf(to, minf(buddy.weight + kg, buddy.low))
		kg = to - buddy.weight
		var gain := (muscle_per_rep + REST_BONUS * rest) * (2.0 if recovery > 0 else 1.0)
		recovery = maxi(recovery - 1, 0)
		muscle += gain
		if runners_high:
			buddy.boost("runners_high", 3.0)
		workouts += 1
		note = "+%s MUSCLE" % String.num(gain, 2)
	return [kg, note]
