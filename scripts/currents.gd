class_name Currents
extends RefCounted
## Gemeinsame Abfrage aller Strömungen eines Levels (CurrentArea, RiverChannel).
## Das Level meldet seine Quellen beim Start an; Boote, KI und Darstellung fragen hier.

static var _sources: Array = []


static func set_sources(sources: Array) -> void:
	_sources = sources
	for s in _sources:
		s.prepare_current()


static func clear() -> void:
	_sources = []


static func has_any() -> bool:
	return not _sources.is_empty()


## Strömung an Weltposition p (m/s, Richtung in die das Wasser fließt)
static func at(p: Vector2) -> Vector2:
	var c := Vector2.ZERO
	for s in _sources:
		c += s.current_at(p)
	return c
