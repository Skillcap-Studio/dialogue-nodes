@tool
class_name ScDialogueLabel
extends RichTextLabel


var wait_effect: RichTextWait


func _ready() -> void:
	_fetch_wait_effect()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	
	if not wait_effect:
		warnings.append("This node must have a RichTextWait effect")
	
	return warnings


func _set(property: StringName, value: Variant) -> bool:
	if property == &"custom_effects":
		custom_effects = value
		_fetch_wait_effect()
		
		return true
	
	return false


## Searches [param custom_effects] for a [RichTextWait] effect. 
## If present, it updates [member wait_effect].
func _fetch_wait_effect() -> void:
	var wait_effects := custom_effects.filter(
		func(item): return item is RichTextWait
	)
	wait_effect = wait_effects[0] if wait_effects.size() else null
	
	update_configuration_warnings()
