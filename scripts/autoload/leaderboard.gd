extends Node

signal status_changed

const CONFIG_PATH := "res://resources/leaderboard.json"
var storage_dir := "user://leaderboard"
var enabled := OS.get_environment("DOODLECAST_OFFLINE") != "1"
var status := "게임 종료 후 순위에 기록됩니다."
var pending: Array = []
var _config: Dictionary
var _session: Dictionary = {}
var _token := ""
var _expires_at := 0.0
var _busy := false
var tutorials: Dictionary = {}
var _tutorial_storage_ok := true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_config = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	DirAccess.make_dir_recursive_absolute(storage_dir)
	if FileAccess.file_exists(storage_dir + "/tutorials.json"):
		var progress = JSON.parse_string(FileAccess.get_file_as_string(storage_dir + "/tutorials.json"))
		if _valid_tutorial_cache(progress):
			tutorials = progress.completed
		else:
			_tutorial_storage_ok = false
			_set_status("튜토리얼 기록 파일을 읽지 못했습니다. 파일을 보존합니다.")
	if FileAccess.file_exists(storage_dir + "/auth.json"):
		var saved = JSON.parse_string(FileAccess.get_file_as_string(storage_dir + "/auth.json"))
		if saved is Dictionary:
			_session = saved
	if FileAccess.file_exists(storage_dir + "/pending.json"):
		var saved = JSON.parse_string(FileAccess.get_file_as_string(storage_dir + "/pending.json"))
		if saved is Array:
			pending = saved
		else:
			enabled = false
			_set_status("대기 기록 파일을 읽지 못했습니다. 파일을 보존합니다.")
	var retry := Timer.new()
	retry.wait_time = 10.0
	retry.timeout.connect(sync)
	add_child(retry)
	retry.start()
	if not pending.is_empty():
		call_deferred("sync")

func queue_result(record: Dictionary) -> void:
	if not enabled:
		return
	for saved in pending:
		if saved.run_id == record.run_id:
			return
	pending.append(record.duplicate(true))
	if not _save_json("pending.json", pending):
		_set_status("기록 파일 저장 실패 · 10초 후 재시도합니다.")
		return
	_set_status("순위 기록 전송 중…")
	sync()

func sync() -> void:
	if not enabled or _busy or pending.is_empty():
		return
	_busy = true
	if not _save_json("pending.json", pending):
		_set_status("기록 파일 저장 실패 · 10초 후 재시도합니다.")
	elif await _authenticate():
		while not pending.is_empty():
			if not await _send_result(pending[0]):
				break
			var remaining := pending.slice(1)
			if not _save_json("pending.json", remaining):
				_set_status("전송 완료 · 로컬 기록 정리는 재시도합니다.")
				break
			pending = remaining
		if pending.is_empty():
			_set_status("순위에 기록되었습니다.")
	_busy = false

func tutorial_completed(identifier: String) -> bool:
	if not _valid_student_id(identifier):
		return false
	var key := identifier.sha256_text()
	if tutorials.get(key, 0) == 1:
		return true
	if not enabled:
		return false
	var completed := false
	var query := {"structuredQuery": {"from": [{"collectionId": "doodlecast_runs"}], "select": {"fields": [{"fieldPath": "participant_key"}]}, "where": {"fieldFilter": {"field": {"fieldPath": "participant_key"}, "op": "EQUAL", "value": {"stringValue": key}}}, "limit": 1}}
	var response := await _http(_documents_url() + ":runQuery", HTTPClient.METHOD_POST, query)
	if response.code == 200 and response.body is Array:
		for row in response.body:
			if row is Dictionary and row.get("document", {}).get("fields", {}).get("participant_key", {}).get("stringValue", "") == key:
				completed = true
	if completed:
		tutorials[key] = 1
		_save_tutorials()
	return completed

func complete_tutorial(identifier: String) -> void:
	if not _valid_student_id(identifier):
		return
	var key := identifier.sha256_text()
	tutorials[key] = 1
	_save_tutorials()

static func _valid_student_id(identifier: String) -> bool:
	return RegEx.create_from_string("^[0-9]{5}$").search(identifier) != null

func _save_tutorials() -> bool:
	return _tutorial_storage_ok and _save_json("tutorials.json", {"completed": tutorials})

func _valid_tutorial_cache(progress: Variant) -> bool:
	if not progress is Dictionary or not progress.get("completed") is Dictionary:
		return false
	for key in progress.completed:
		if not key is String or key.length() != 64 or not key.is_valid_hex_number(false) or progress.completed[key] != 1:
			return false
	return true

func _authenticate() -> bool:
	if not _token.is_empty() and Time.get_unix_time_from_system() < _expires_at:
		return true
	var response: Dictionary
	if _session.has("refresh_token"):
		response = await _http("https://securetoken.googleapis.com/v1/token?key=" + _config.apiKey, HTTPClient.METHOD_POST, "grant_type=refresh_token&refresh_token=" + str(_session.refresh_token).uri_encode(), false, true)
	else:
		response = await _http("https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=" + _config.apiKey, HTTPClient.METHOD_POST, {"returnSecureToken": true})
	if response.code != 200:
		_set_status("순위 서버 로그인 대기 · 10초 후 재시도합니다.")
		return false
	var body: Dictionary = response.body
	var session := {"uid": body.get("localId", body.get("user_id", "")), "refresh_token": body.get("refreshToken", body.get("refresh_token", ""))}
	var token: String = body.get("idToken", body.get("id_token", ""))
	if session.uid.is_empty() or session.refresh_token.is_empty() or token.is_empty() or not _save_json("auth.json", session):
		_set_status("순위 로그인 저장 실패 · 기존 기록을 보존합니다.")
		return false
	_session = session
	_token = token
	_expires_at = Time.get_unix_time_from_system() + float(body.get("expiresIn", body.get("expires_in", 3600))) - 60.0
	return true

func _send_result(record: Dictionary) -> bool:
	var values := record.duplicate(true)
	values.erase("run_id")
	values.owner_uid = _session.uid
	var name := "projects/%s/databases/(default)/documents/doodlecast_runs/%s" % [_config.projectId, record.run_id]
	var payload := {"writes": [{"update": {"name": name, "fields": encode_fields(values)}, "currentDocument": {"exists": false}, "updateTransforms": [{"fieldPath": "finished_at", "setToServerValue": "REQUEST_TIME"}]}]}
	var response := await _http(_documents_url() + ":commit", HTTPClient.METHOD_POST, payload, true)
	if response.code == 200:
		return true
	if response.code == 409:
		# A timeout can hide a successful commit; the same run must never be counted twice.
		var existing := await _http(_documents_url() + "/doodlecast_runs/" + record.run_id, HTTPClient.METHOD_GET, null, true)
		if existing.code == 200:
			var fields := encode_fields(values)
			var saved: Dictionary = existing.body.get("fields", {})
			var matches := true
			for key in fields:
				if saved.get(key) != fields[key]:
					matches = false
			if matches:
				return true
	if response.code == 401:
		_token = ""
	_set_status("순위 전송 권한 확인 필요 · 기록을 보관합니다." if response.code == 403 else "순위 전송 대기 · 기록을 보관하고 재시도합니다.")
	return false

func _documents_url() -> String:
	return "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents" % _config.projectId

static func encode_fields(values: Dictionary) -> Dictionary:
	var fields := {}
	for key in values:
		if values[key] is int or values[key] is float:
			assert(float(values[key]) == floorf(float(values[key])))
			fields[key] = {"integerValue": str(int(values[key]))}
		else:
			assert(values[key] is String)
			fields[key] = {"stringValue": values[key]}
	return fields

func _http(url: String, method: int, data: Variant = null, authorized := false, form := false) -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = 8.0
	add_child(request)
	var headers := PackedStringArray(["Content-Type: application/x-www-form-urlencoded" if form else "Content-Type: application/json"])
	if authorized:
		headers.append("Authorization: Bearer " + _token)
	var body := "" if data == null else (str(data) if form else JSON.stringify(data))
	var error := request.request(url, headers, method, body)
	if error != OK:
		request.queue_free()
		return {"code": 0, "body": {}}
	var result: Array = await request.request_completed
	request.queue_free()
	var parsed = JSON.parse_string(result[3].get_string_from_utf8())
	return {"code": result[1] if result[0] == HTTPRequest.RESULT_SUCCESS else 0, "body": parsed if parsed is Dictionary or (parsed is Array and url.ends_with(":runQuery")) else {}}

func _save_json(filename: String, value: Variant) -> bool:
	var path := storage_dir + "/" + filename
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value))
	file.flush()
	var error := file.get_error()
	file.close()
	return error == OK and DirAccess.rename_absolute(path + ".tmp", path) == OK

func _set_status(message: String) -> void:
	status = message
	status_changed.emit()
