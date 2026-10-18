extends Node

const MOCK := preload("res://tests/fixtures/leaderboard_mock.gd")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(10.0).timeout.connect(func(): get_tree().quit(1))
	call_deferred("test_ranking")

func test_ranking() -> void:
	GameRun.set_player_info("11013", "홍길동")
	GameRun.begin_run(1)
	var run_id := GameRun.run_id
	GameRun.combat_score = 2500
	GameRun.elapsed_seconds = 12.399
	GameRun.health = 3
	GameRun.defeated = 8
	var record := GameRun.ranking_result(false)
	assert(record.run_id.length() == 32 and record.participant_key == "11013".sha256_text())
	assert(record.score == 2377 and record.duration_ms == 12399 and record.time_penalty == 123 and record.hits == 2)
	assert(record.display_name == "학번 **013 · 홍*동" and "11013" not in JSON.stringify(record) and "홍길동" not in JSON.stringify(record))
	GameRun.level_number = 2
	assert(GameRun.ranking_result(false).run_id == run_id, "All six levels must share one run ID")
	GameRun.begin_run(0)
	assert(GameRun.run_id != run_id)
	var client = MOCK.new()
	client.storage_dir = "user://leaderboard-test-" + str(Time.get_ticks_usec())
	client.enabled = false
	add_child(client)
	client.enabled = true
	client.responses = [{"code": 200, "body": {"localId": "test-uid", "refreshToken": "test-refresh", "idToken": "test-token", "expiresIn": "3600"}}, {"code": 0, "body": {}}]
	client.queue_result(record)
	assert(client.pending.size() == 1 and FileAccess.file_exists(client.storage_dir + "/pending.json"))
	assert(client.requests.size() == 2 and client.requests[0].url.contains("accounts:signUp"), "A fresh PC must sign in automatically, without station setup")
	assert(client.requests[1].data.writes[0].currentDocument.exists == false)
	assert(client.requests[1].data.writes[0].updateTransforms[0].setToServerValue == "REQUEST_TIME")
	assert(client.requests[1].data.writes[0].update.fields.owner_uid.stringValue == "test-uid")
	client.queue_result(record)
	assert(client.pending.size() == 1 and client.requests.size() == 2, "Repeated game-over callbacks must not duplicate the queued run")
	var fields: Dictionary = client.requests[1].data.writes[0].update.fields
	client.responses = [{"code": 409, "body": {}}, {"code": 200, "body": {"fields": fields}}]
	await client.sync()
	assert(client.pending.is_empty() and JSON.parse_string(FileAccess.get_file_as_string(client.storage_dir + "/pending.json")).is_empty(), "A lost response followed by retry must recognize the saved run")
	var next_record := record.duplicate(true)
	next_record.run_id = "a".repeat(32)
	client.responses = [{"code": 403, "body": {}}]
	client.queue_result(next_record)
	assert(client.pending.size() == 1 and client.status.contains("권한"))
	var storage: String = client.storage_dir
	client.free()
	client = MOCK.new()
	client.storage_dir = storage
	client.enabled = false
	add_child(client)
	assert(client.pending.size() == 1 and client._session.uid == "test-uid", "Pending records and the anonymous login must survive a restart")
	client.enabled = true
	client.responses = [{"code": 200, "body": {"user_id": "test-uid", "refresh_token": "test-refresh", "id_token": "renewed", "expires_in": "3600"}}, {"code": 200, "body": {}}]
	await client.sync()
	assert(client.pending.is_empty() and client.requests[0].url.contains("securetoken") and client.requests[0].form)
	# A different result under the same ID is never silently discarded.
	client.responses = [{"code": 409, "body": {}}, {"code": 200, "body": {"fields": {}}}]
	client.queue_result(record)
	assert(client.pending.size() == 1)
	client.enabled = false
	client.free()
	print("PASS: anonymous first-run login, masked identity, six-level run ID, result totals, durable queue/restart, token refresh, retry idempotency, duplicate callback and conflicting record preservation")
	get_tree().quit()
