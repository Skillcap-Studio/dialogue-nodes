@tool
class_name ScDialogueBubble
extends Control


## Triggered when a dialogue has started.
## Passes [param id] of the dialogue tree as defined in the StartNode.
signal dialogue_started(id: String)
## Triggered when a single dialogue block has been processed.
## Passes [param speaker] which can be a [String] or a [param Character] resource,
## a [param dialogue] containing the text to be displayed
## and an [param options] list containing the texts for each option.
signal dialogue_processed(speaker: Variant, dialogue: String, options: Array[String])
## Triggered when an option is selected
signal option_selected(idx: int)
## Triggered when a SignalNode is encountered while processing the dialogue.
## Passes a [param value] of type [String] that is defined in the SignalNode in
## the dialogue tree.
signal dialogue_signal(value: String)
## Triggered when a variable value is changed.
## Passes the [param variable_name] along with it"s [param value]
signal variable_changed(variable_name: String, value)
## Triggered when a dialogue tree has ended processing and reached the end of
## the dialogue.
## The [ScDialogueBubble] may hide based on the [member hide_on_dialogue_end] property.
signal dialogue_ended

@export_group("Data")
## Contains the [param DialogueData] resource created using the Dialogue Nodes editor.
@export var data: DialogueData:
	set(value):
		data = value
		if _dialogue_parser:
			_dialogue_parser.data = value
			variables = _dialogue_parser.variables
			characters = _dialogue_parser.characters
## The default start ID to begin dialogue from.
## This is the value you set in the Dialogue Nodes editor.
@export var start_id := &"START"

@export_group("Dialogue")
## Speed of scroll when using joystick/keyboard input.
@export var scroll_speed := 4
## Input action used to skip dialogue animation.
@export var skip_input_action := &"ui_cancel"

@export_group("Misc")
## Hide dialogue box at the end of a dialogue.
@export var hide_on_dialogue_end := true

## Contains the variable data from the [param DialogueData] parsed in an easy
## to access dictionary.[br]
## Example: [code]{ "COINS": 10, "NAME": "Obama", "ALIVE": true }[/code]
var variables: Dictionary
## Contains all the [param Character] resources loaded from the path in the [member data].
var characters: Array[Character]
var _wait_effect: RichTextWait

@onready var panel: Panel = %Panel
@onready var dialogue_label: RichTextLabel = %DialogueLabel
@onready var options: BoxContainer = %Options
@onready var speaker_label: Label = %SpeakerLabel
@onready var _dialogue_parser: DialogueParser = %DialogueParser


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	
	_dialogue_parser.dialogue_started.connect(_on_dialogue_started)
	_dialogue_parser.dialogue_processed.connect(_on_dialogue_processed)
	_dialogue_parser.option_selected.connect(_on_option_selected)
	_dialogue_parser.dialogue_signal.connect(_on_dialogue_signal)
	_dialogue_parser.variable_changed.connect(_on_variable_changed)
	_dialogue_parser.dialogue_ended.connect(_on_dialogue_ended)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	for effect in dialogue_label.custom_effects. \
			filter(func(item): return item is RichTextWait):
		_wait_effect = effect
		_wait_effect.wait_finished.connect(_on_wait_effect_wait_finished)
		break
	
	hide()


func _process(delta: float) -> void:
	if not is_running():
		return
	
	# Enable dynamic vertical size with RichTextLabel
	panel.size = dialogue_label.size
	panel.size.y = dialogue_label.size.y + options.size.y
	
	# Scrolling for longer dialogues
	var scroll_amt := Input.get_axis(&"ui_up", &"ui_down")
	if scroll_amt:
		dialogue_label.get_v_scroll_bar().value += int(scroll_amt * scroll_speed)


func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed(skip_input_action) and is_running():
		if _wait_effect and not _wait_effect.skip:
			_wait_effect.skip = true
			await get_tree().process_frame
			_on_wait_effect_wait_finished()


## Starts processing the dialogue [member data], starting with the Start Node
## with its ID set to [param start_id].
func start(id: StringName = start_id) -> void:
	if not _dialogue_parser:
		return
	
	_dialogue_parser.start(id)


## Stops processing the dialogue tree.
func stop() -> void:
	if not _dialogue_parser:
		return
	
	_dialogue_parser.stop()


## Continues processing the dialogue tree from the node connected to
## the option at [param idx].
func select_option(idx: int) -> void:
	if not _dialogue_parser:
		return
	
	_dialogue_parser.select_option(idx)


## Returns [code]true[/code] if the [ScDialogueBubble] is processing a dialogue tree.
func is_running() -> bool:
	return _dialogue_parser.is_running()


func _on_dialogue_started(id: String) -> void:
	speaker_label.text = ""
	dialogue_label.text = ""
	show()
	dialogue_started.emit(id)


func _on_dialogue_processed(
	speaker: Variant, dialogue: String, options: Array[String]
) -> void:
	# set speaker
	if speaker is Character:
		speaker_label.text = speaker.name
	elif speaker is String:
		speaker_label.text = speaker
	else:
		print("Invalid speaker type!")
	
	# set dialogue
	dialogue_label.text = _dialogue_parser._update_wait_tags(dialogue_label, dialogue)
	dialogue_label.get_v_scroll_bar().set_value_no_signal(0)
	for effect in dialogue_label.custom_effects:
		if effect is RichTextWait:
			effect.skip = false
			break
	
	dialogue_processed.emit(speaker, dialogue, options)


func _on_option_selected(idx: int) -> void:
	option_selected.emit(idx)


func _on_dialogue_signal(value: String) -> void:
	dialogue_signal.emit(value)


func _on_variable_changed(variable_name: String, value) -> void:
	variable_changed.emit(variable_name, value)


func _on_dialogue_ended() -> void:
	if hide_on_dialogue_end:
		hide()
	dialogue_ended.emit()


## Triggered each time a dialogue text is fully shown.
func _on_wait_effect_wait_finished() -> void:
	pass
