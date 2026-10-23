class_name NetLag
extends RefCounted
## Pretend the network is slow, for testing on one computer. Net keeps two:
## one holds messages on the way out, one on the way in, each for half the
## round trip (so one copy with lag set feels all of it), plus up to half the
## jitter more. Unreliable messages can be lost (`loss`) and overtake each
## other; reliable ones never drop and keep their order, as ENet does.

var lag_ms := 0.0 # the round trip to pretend
var jitter_ms := 0.0 # up to this much more, at random, per round trip
var loss := 0.0 # 0..1: the chance an unreliable message is lost, each way

var _queue: Array = [] # [due usec, item]
var _last_due := {} # stream -> the last reliable item's due time


func active() -> bool:
	return lag_ms > 0.0 or jitter_ms > 0.0 or loss > 0.0


## Nothing waiting: with no lag, a message can go straight through without overtaking any.
func empty() -> bool:
	return _queue.is_empty()


## Hold `item` until its time comes (or lose it). Reliable items of one `stream` (a peer) keep their order.
func push(item: Variant, reliable: bool, stream: int) -> void:
	if not reliable and randf() < loss:
		return
	var due := Time.get_ticks_usec() + int((lag_ms + randf() * jitter_ms) * 500.0)
	if reliable:
		due = maxi(due, _last_due.get(stream, 0))
		_last_due[stream] = due
	_queue.append([due, item])


## The items whose time has come, oldest first.
func pop_due() -> Array:
	if _queue.is_empty():
		return []
	var now := Time.get_ticks_usec()
	var due: Array = []
	var later: Array = []
	for e: Array in _queue:
		(due if e[0] <= now else later).append(e)
	_queue = later
	due.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	return due.map(func(e: Array) -> Variant: return e[1])


func clear() -> void:
	_queue.clear()
	_last_due.clear()
