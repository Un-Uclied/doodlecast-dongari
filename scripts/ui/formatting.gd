extends RefCounted

static func format_number(value: int) -> String:
	var text := str(absi(value))
	for index in range(text.length() - 3, 0, -3):
		text = text.insert(index, ",")
	return ("-" if value < 0 else "") + text

static func format_duration(seconds: float) -> String:
	var tenths := floori(maxf(seconds, 0.0) * 10.0 + 0.000001)
	return "%02d:%02d.%d" % [tenths / 600, (tenths / 10) % 60, tenths % 10]
