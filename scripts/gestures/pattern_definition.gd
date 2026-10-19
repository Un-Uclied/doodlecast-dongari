class_name PatternDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var samples: Array[PackedVector2Array] = []
@export var closed := false
@export var rotation_invariant := false
@export_range(0.0, 0.3, 0.01) var min_concavity := 0.0
@export var single_concavity := false
@export_range(0.01, 0.5, 0.005) var max_error := 0.12
