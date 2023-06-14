extends Node2D
class_name Note

# 채널값
var channel : int
# 1프레임 당 노트가 내려오는 y좌표값
var coordPerFrame : float
# 노트 상태
var score : String = "Default"
# 롱노트인지 확인 플래그
var isLongnote : bool = false
# 롱노트 시간
var longnoteTime : float = -1.0
# 현재 노트가 PERFECT_YPOS까지 내려오는 동안 걸리는 시간
var speed : float
# 롱노트 이펙트 노드
var effect : Object

# 롱노트를 눌렀을 때의 점수
var longnoteScore : String = ""
# 롱노트 콤보에 해당하는 좌표 큐
var longnoteComboQueue : Array = []

func setNote(_channel : int, _speed : float, _coordPerFrame : float, _longnoteTime : float = -1.0) -> void:
	self.global_position.y = 0.0
	channel = _channel
	speed = _speed
	coordPerFrame = _coordPerFrame
	effect = $LN_Effect
	# 롱노트 설정
	if (_longnoteTime != -1.0):
		isLongnote = true
		longnoteTime = _longnoteTime
		var size : float = float((60.0 * coordPerFrame) * longnoteTime)
		$LN_Effect.position.y = -size
		$LN_Effect.size.y = size
		$LN_EffectEnd.position.y = -size
		$LN_EffectEnd.visible = true

func longnoteStart():
	longnoteScore = score
	var longnoteStartPos = global_position.y
	var step = 10 / speed
	var index = snapped(longnoteStartPos, 1)
	var tempComboQueue = []
	# 1초 기준 50개 원소의 콤보 큐를 생성한다.
	while (index <= longnoteStartPos + effect.size.y):
		tempComboQueue.append(index)
		index += step
	# 만약 콤보 큐 원소의 개수가 2의 배수가 아니라면 뒤에서 하나를 제거한다.
	if (len(tempComboQueue) != snapped(len(tempComboQueue), 2)):
		tempComboQueue.pop_back()
	# 1초 기준 50개였던 콤보 큐 중 10개를 뽑아 지정한다.
	for i in range(1, len(tempComboQueue), 5):
		longnoteComboQueue.append(tempComboQueue[i-1])

func longnoteFailed():
	longnoteComboQueue.clear()
	$LN_Effect.color = Color("d38b8e")

func _physics_process(_delta):
	self.global_position.y += coordPerFrame
	# 롱노트이고 콤보 큐가 비어있지 않다면 콤보를 더한다.
	if (isLongnote and longnoteComboQueue != []):
		if (global_position.y >= longnoteComboQueue[0]):
			longnoteComboQueue.pop_front()
			get_parent().get_parent().addCombo(longnoteScore)
