@tool
extends Button


## If enabled, the text will be outlined on focus.
@export var outline_on_focus_enabled := true:
	set(value):
		outline_on_focus_enabled = value
		notify_property_list_changed()
## The size (in pixels) of the outline.
@export var outline_size := 2

const BULLET := "•"


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)


func _validate_property(property: Dictionary) -> void:
	match property.name:
		"outline_size":
			if outline_on_focus_enabled:
				property.usage = PROPERTY_USAGE_DEFAULT
			else:
				property.usage = PROPERTY_USAGE_NO_EDITOR | PROPERTY_USAGE_STORAGE


func _set(property: StringName, value: Variant) -> bool:
	if Engine.is_editor_hint():
		return false
	
	if property == &"text":
		var button_text := "{symbol} {text}".format({
			"symbol": BULLET,
			"text": value,
		})
		text = button_text
		return true
	
	return false


func _on_focus_entered() -> void:
	if outline_on_focus_enabled:
		add_theme_constant_override(&"outline_size", outline_size)


func _on_focus_exited() -> void:
	if outline_on_focus_enabled:
		remove_theme_constant_override(&"outline_size")
