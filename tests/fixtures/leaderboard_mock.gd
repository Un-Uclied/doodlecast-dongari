extends "res://scripts/leaderboard.gd"

var responses: Array = []
var requests: Array = []

func _http(url: String, method: int, data: Variant = null, authorized := false, form := false) -> Dictionary:
	requests.append({"url": url, "method": method, "data": data, "authorized": authorized, "form": form})
	assert(not responses.is_empty(), "Unexpected ranking HTTP request: " + url)
	return responses.pop_front()
