class_name PatternDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var samples: Array[PackedVector2Array] = []
@export var closed := false
@export var rotation_invariant := false
@export_range(0.01, 0.5, 0.005) var max_error := 0.12
