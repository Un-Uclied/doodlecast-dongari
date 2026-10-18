class_name PatternCatalog
extends Resource

@export var patterns: Array[PatternDefinition] = []
@export_range(0.0, 0.25, 0.005) var ambiguity_margin := 0.035
