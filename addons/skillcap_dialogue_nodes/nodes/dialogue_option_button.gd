extends Button


const WHITE_BULLET := "◦"
const BULLET := "•"


func _ready() -> void:
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)


func _set(property: StringName, value: Variant) -> bool:
	if property == &"text":
		var button_text := "{symbol} {text}".format({
			"symbol": WHITE_BULLET,
			"text": value,
		})
		text = button_text
		return true
	
	return false


func _on_focus_entered() -> void:
	text = text.replace(WHITE_BULLET, BULLET)


func _on_focus_exited() -> void:
	text = text.replace(BULLET, WHITE_BULLET)
