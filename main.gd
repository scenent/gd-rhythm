extends Node2D

# 스크린 상에서 눌러야 하는 완벽한 y좌표
const PERFECT_YPOS : float = 500
# 마지막 노트가 끝난 후 이 여백동안 대기했다가 게임이 끝남
const ENDPOS_BIAS : float = +2.0
# 보조선 간격(초)
const SUBLINE_LENGTH : float = 1.0
# 자동 플레이 플래그
const AUTOPLAY : bool = false
# 4채널 각각의 키코드(input map에서 추가 가능)
@export var keycodes : PackedStringArray
# 오디오 플레이어 노드 경로
@export_node_path("AudioStreamPlayer") var audio
# 노트 씬 미리 로드
@onready var noteScene : Note = preload("res://note.tscn").instantiate()
# 노트가 (y=0) 부터 (y=PERFECT_YPOS) 까지 내려오는 시간
var speed : float = 1.0
# 4개의 채널에 해당하는 노트 정보
var noteArray      : Array = [
							[[5.5, 7], [15.3, 3], [20.5], [21.4], [24.3, 0.3]],
							[[6.3], [7.0], [11.2], [11.9, 0.6], [12.8], [14.35, 0.4], [17.2], [19.7], [21.8], [23.1], [23.4], [24.9, 0.3], [25.4], [25.6, 3.0]],
							[[7.8], [8.7, 3.9], [13.2, 0.4], [14, 0.4], [14.9], [17.1], [18.8, 6.9]],
							[[9.6], [10.4], [13.6, 0.4], [15.3, 3], [20], [22.2], [22.8], [23.9, 0.3]]
							]
# 보조선 정보
var subLineArray   : Array = []
# 현재 음원 재생 시간(초)
var currentSongPos : float   = 0.0
# 1프레임 당 노트가 내려오는 y좌표값
var coordPerFrame  : float
# 게임이 끝나는 시간(초)
var endPos         : float   = 0.0

# 현재 유효한 노트 씬이 담긴 4개의 큐
var queue          : Array   = [[], [], [], []]
# 각 채널의 눌린 상태 확인
var pressed        : Array   = [false, false, false, false]
# 현재 누르고 있어야 하는지 확인
var shouldPress    : Array   = [false, false, false, false]
# 현재 누르고 있는 롱노트가 끝나는 시간 
var shouldPressEnd : Array   = [-1.0, -1.0, -1.0, -1.0]
# 게임이 끝났는지 확인하는 플래그
var done           : bool    = false
# 현재 콤보 수
var combo          : int     = 0
# 최대 콤보 수
var comboMax       : int     = 0
# 현재 점수
var currentScore   : float   = 0.0
# 얻을 수 있는 최대 점수
var maximumScore   : float   = 0.0
# 노트 시간 정보의 가장 끝 값을 얻는다.
func getEndPos(array : Array, sp : float, bias : float) -> float:
	var result : float  = -1.0
	for noteInfo in array:
		if (len(noteInfo) == 1):
			if (result < noteInfo[0]):
				result = noteInfo[0]
		elif (len(noteInfo) == 2):
			if (result < noteInfo[0] + noteInfo[1]):
				result = noteInfo[0] + noteInfo[1]
	return result + sp + bias
# 1프레임 당 노트가 내려와야 하는 좌표값을 얻는다.
func getCoordPerFrame(sp : float, perfectYpos : float) -> float:
	if (sp != 1.0):
		perfectYpos /= sp
		sp          /= sp
	perfectYpos /= 60.0
	return perfectYpos
# 모든 노트 시간 정보에 대해 speed값만큼 빼준다.
func getCorrectArr(array : Array, sp : float) -> Array:
	var result : Array = []
	for noteInfo in array:
		noteInfo[0] -= sp
		result.append(noteInfo)
	return result
# 보조선 리스트를 얻는다.
func getSubLineArr(endpos : float, sp : float, sec : float) -> Array:
	var arr : Array = []
	var index : float = sec
	while (index < endpos):
		arr.append(index)
		index += sec
	for i in range(len(arr)):
		arr[i] -= sp
	while (arr[0] < sp):
		arr.pop_front()
	return arr
# 얻을 수 있는 최대 점수를 얻는다.
func getMaximumScore(notearr : Array) -> float:
	var result : float = 0.0
	for i in notearr:
		for note in i:
			if (len(note) == 1):
				result += 1.0
			else:
				result += note[1] * 10.0
	return result
# 콤보를 더한다.
func addCombo(score : String) -> void:
	combo += 1
	if combo > comboMax:
		comboMax = combo
	if (score == "Perfect"):
		currentScore += 1.0
	elif (score == "Good"):
		currentScore += 0.7
	$combo.text = str(combo)
	$anim.play(score)
	await $anim.animation_finished
	$anim.play("combo")
	await $anim.animation_finished
# 콤보를 리셋한다.
func resetCombo() -> void:
	combo = 0
	$combo.text = str(combo)
	$anim.play("Bad")
	await $anim.animation_finished
	$anim.play("combo")
	await $anim.animation_finished

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	set_physics_process(false)
	var noteStart : float = INF
	for i in range(0, 4):
		if len(noteArray[i]) > 0:
			if (noteStart > noteArray[i][0][0]):
				noteStart = noteArray[i][0][0]
	if (noteStart <= speed):
		OS.alert("There is no enough space in front of note info")
	if (len(keycodes) != 4):
		OS.alert("All of keycode has not been assigned")
	for key in keycodes:
		if key == "":
			OS.alert("Please assign a keycode")
			break
	if (audio == null):
		OS.alert("Please assign a AudioStreamPlayer node")
	if (get_node(audio).stream == null):
		OS.alert("Please assign a music")
	for i in range(0, 4):
		noteArray[i] = getCorrectArr(noteArray[i], speed)
	coordPerFrame = getCoordPerFrame(speed, PERFECT_YPOS)
	for i in range(0, 4): 
		if getEndPos(noteArray[i], speed, ENDPOS_BIAS) > endPos:
			endPos = getEndPos(noteArray[i], speed, ENDPOS_BIAS)
	if (get_node(audio).stream.get_length() < endPos):
		OS.alert("Please add enough space after the music, or decrease the ENDPOS_BIAS")
	subLineArray = getSubLineArr(endPos, speed, SUBLINE_LENGTH)
	maximumScore = getMaximumScore(noteArray)
	if (AUTOPLAY):
		$isautoplay.visible = true
		print("AUTO PLAYING...")
	await get_tree().create_timer(1.0).timeout
	print("Game Start")
	get_node(audio).play()
	set_physics_process(true)

func _process(_delta) -> void:
	# 현재 음원 재생 시간 얻기
	currentSongPos = get_node(audio).get_playback_position()
	currentSongPos -= AudioServer.get_output_latency()
	# 게임 종료 확인
	if (currentSongPos >= endPos):
		done = true
		for i in range(1, 5): get_node("pressed" + str(i)).visible = false
		for i in $sublinecontainer.get_children(): i.free()
		print("Game Finished")
		print("Score : ", snapped(currentScore / maximumScore * 100.0, 0.1), "%")
		print("Maximum Combo : ", comboMax)
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		set_physics_process(false)
		return
	# 롱노트 완료 확인
	for i in range(0, 4):
		if shouldPressEnd[i] != -1.0 and shouldPressEnd[i] <= currentSongPos:
			shouldPress[i] = false
			shouldPressEnd[i] = -1.0
			queue[i].pop_front()
	# 노트 생성
	for i in range(0, 4):
		if (noteArray[i] and noteArray[i][0][0] <= currentSongPos):
			var note : Note = noteScene.duplicate()
			var info : Array = noteArray[i].pop_front()
			if (len(info) == 1):
				# 일반 노트 생성
				note.setNote(i+1, speed, coordPerFrame)
			else:
				# 롱노트 생성
				note.setNote(i+1, speed, coordPerFrame, info[1])
			var container = get_node("container" + str(i+1))
			container.add_child(note)
			container.get_child(container.get_child_count()-1).global_position.x = 100 * (i+1)
			container.get_child(container.get_child_count()-1).global_position.y += coordPerFrame * (currentSongPos - info[0]) / 60
			queue[i].append(container.get_child(container.get_child_count()-1))
	# 보조선 생성
	if (subLineArray and subLineArray[0] <= currentSongPos):
		subLineArray.pop_front()
		var line : Line2D = Line2D.new()
		line.width = 1
		line.points = [Vector2(100, 0), Vector2(500, 0)]
		$sublinecontainer.add_child(line)
	# 보조선 이동 & 삭제
	for line in $sublinecontainer.get_children():
		if line.position.y >= PERFECT_YPOS:
			line.queue_free()
		line.position.y += coordPerFrame
	# 자동 플레이 확인
	if (AUTOPLAY):
		autoplay()
		killGarbage()
		return
	# 큐 안의 모든 노트들에게 점수 부여
	updateQueue()
	# 입력 확인 및 [롱노트 누르고 있던 도중 실패] 처리
	updateInputState()
	# [아예 누르지 못해 일반 노트 및 롱노트 실패] 처리
	dequeue()
	# 스크린 밖으로 나간 모든 노트를 삭제
	killGarbage()

func autoplay():
	for i in range(0, 4):
		if (queue[i] and queue[i][0] == null):
			queue[i].pop_front()
		if (queue[i] and queue[i][0].isLongnote == false):
			if (queue[i][0].global_position.y >= PERFECT_YPOS):
				queue[i][0].score = "Perfect"
				addCombo(queue[i][0].score)
				queue[i][0].free()
				queue[i].pop_front()
		elif (queue[i] and queue[i][0].isLongnote == true and queue[i][0].longnoteScore == ""):
			if (queue[i][0].global_position.y >= PERFECT_YPOS):
				queue[i][0].score = "Perfect"
				shouldPress[i] = true
				shouldPressEnd[i] = currentSongPos + queue[i][0].longnoteTime
				queue[i][0].longnoteStart()
# i번째 채널 키가 눌렸을 시 호출됨
func keyPressed(i : int) -> void:
	# 만약 해당 채널의 첫 번째 노트에 점수가 부여된 경우
	if len(queue[i]) != 0 and queue[i][0].score != "Default":
		if queue[i][0].score == "Bad":
			resetCombo()
			if queue[i][0].isLongnote == false:
				# 일반 노트 실패
				queue[i][0].free()
			else:
				# 롱노트 실패
				queue[i][0].longnoteFailed()
			queue[i].pop_front()
		else:
			if (queue[i][0].isLongnote == false):
				# 일반노트 완료
				addCombo(queue[i][0].score)
				queue[i][0].free()
				queue[i].pop_front()
			else:
				# 롱노트 정상진입
				shouldPress[i] = true
				shouldPressEnd[i] = currentSongPos + queue[i][0].longnoteTime
				queue[i][0].longnoteStart()
func updateQueue() -> void:
	for q in queue:
		for n in q:
			var m = n.global_position.y
			if (m < 400): continue
			if (400 <= m and m < 440): 
				n.score = "Bad"
			elif (440 <= m and m < 480):
				n.score = "Good"
			elif (480 <= m and m < 520):
				n.score = "Perfect"
func updateInputState() -> void:
	for i in range(0, 4):
		get_node("pressed" + str(i+1)).visible = pressed[i]
		if (Input.is_action_just_pressed(keycodes[i])):
			pressed[i] = true
			keyPressed(i)
		if (Input.is_action_just_released(keycodes[i])):
			pressed[i] = false
		if (pressed[i] == false and shouldPress[i]):
			# 롱노트 누르던 도중 실패
			resetCombo()
			queue[i][0].longnoteFailed()
			queue[i].pop_front()
			shouldPressEnd[i] = -1.0
			shouldPress[i] = false
func dequeue() -> void:
	for i in range(0, 4):
		if (len(queue[i]) != 0 and queue[i][0] != null and queue[i][0].global_position.y >= 520):
			# 롱노트일 경우
			if (queue[i][0].isLongnote == true):
				# 애초에 누르지 않았다면
				if (not shouldPress[i]):
					queue[i][0].longnoteFailed()
					queue[i].pop_front()
					resetCombo()
			# 일반 노트일 경우
			else:
				queue[i].pop_front()
				resetCombo()
func killGarbage() -> void:
	for i in range(1, 5):
		for n in get_node("container" + str(i)).get_children():
			if (n.global_position.y - n.effect.size.y >= 600):
				n.free()
