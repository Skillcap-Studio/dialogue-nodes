@tool
class_name ScDialogueBubble
extends Control
# TODO: check if we need multiple options
# TODO: add support for animated icon when user interaction is needed to advance
# TODO: input blocking
# TODO: support for tail, with multiple, configurable setups


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
		if is_node_ready():
			_dialogue_parser.data = value
			variables = _dialogue_parser.variables
			characters = _dialogue_parser.characters
## The default start ID to begin dialogue from.
## This is the value you set in the Dialogue Nodes editor.
@export var start_id := &"START"

@export_group("Auto Advance", "auto_advance_")
## If [code]true[/code], the dialogue will advance automatically unless there are options.
@export var auto_advance_enabled := false:
	set(value):
		auto_advance_enabled = value
		notify_property_list_changed()
## Base delay. It will be applied regardless of the text size.
@export var auto_advance_base_delay := 0.15
## Additional delay per character.
@export var auto_advance_character_delay := 0.04

@export_group("Input Handling")
## Input action used to skip dialogue animation.
@export var skip_input_action := &"ui_select"
## Determines whether the dialogue box will intercept all inputs or not.
@export var input_blocking := false

@export_group("Font Sizes", "font_size_")
@export var font_size_speaker := 24:
	set = _set_font_size_speaker
@export var font_size_dialogue_text := 10:
	set = _set_font_size_dialogue_text

@export_group("Visuals")
## The maximum number of characters allowed in a single line.
## This will determine the width of the dialogue bubble.
@export var max_chars_per_line := 25

@export_group("Misc")
## Hide dialogue box at the end of a dialogue.
@export var hide_on_dialogue_end := true
# TODO: check if we're gonna need this (ATM there's no scrolling enabled)
## Speed of scroll when using joystick/keyboard input.
@export var scroll_speed := 4

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
@onready var _lifetime_timer: Timer = %LifetimeTimer


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_dialogue_parser.dialogue_started.connect(_on_dialogue_started)
	_dialogue_parser.dialogue_processed.connect(_on_dialogue_processed)
	_dialogue_parser.option_selected.connect(_on_option_selected)
	_dialogue_parser.dialogue_signal.connect(_on_dialogue_signal)
	_dialogue_parser.variable_changed.connect(_on_variable_changed)
	_dialogue_parser.dialogue_ended.connect(_on_dialogue_ended)
	
	for effect in dialogue_label.custom_effects. \
			filter(func(item): return item is RichTextWait):
		_wait_effect = effect
		_wait_effect.wait_finished.connect(_on_wait_effect_wait_finished)
		break
	if not _wait_effect:
		printerr("RichTextWait effect is missing!")
	
	hide()


func _process(delta: float) -> void:
	# Enable dynamic vertical size with RichTextLabel
	panel.size = dialogue_label.size
	panel.size.y = dialogue_label.size.y + options.size.y
	size = panel.size
	
	if not is_running():
		return
	
	# Scrolling for longer dialogues
	var scroll_amt := Input.get_axis(&"ui_up", &"ui_down")
	if scroll_amt:
		dialogue_label.get_v_scroll_bar().value += int(scroll_amt * scroll_speed)


func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed(skip_input_action) and is_running():
		if not _wait_effect.skip:
			# Skip dialogue, i.e. show it fully
			_wait_effect.skip = true
		else:
			# Advance dialogue
			select_option(0)


func _validate_property(property: Dictionary) -> void:
	match property.name:
		"auto_advance_base_delay":
			if auto_advance_enabled:
				property.usage = PROPERTY_USAGE_DEFAULT
			else:
				property.usage = PROPERTY_USAGE_NO_EDITOR | PROPERTY_USAGE_STORAGE
		"auto_advance_character_delay":
			if auto_advance_enabled:
				property.usage = PROPERTY_USAGE_DEFAULT
			else:
				property.usage = PROPERTY_USAGE_NO_EDITOR | PROPERTY_USAGE_STORAGE


#region Public Methods
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
#endregion


#region Fluent Interfaces
func set_auto_advance_enabled(enabled: bool) -> ScDialogueBubble:
	auto_advance_enabled = enabled
	return self


func set_auto_advance_base_delay(base_delay: float) -> ScDialogueBubble:
	auto_advance_base_delay = base_delay
	return self


func set_auto_advance_character_delay(character_delay: float) -> ScDialogueBubble:
	auto_advance_character_delay = character_delay
	return self


func set_input_blocking(blocking: bool) -> ScDialogueBubble:
	input_blocking = blocking
	return self
#endregion


#region Private methods
func _calculate_bubble_width(dialogue_length: int) -> int:
	# Calculate average char width using a common character
	var avg_char_width := dialogue_label.get_theme_font(&"normal_font") \
			.get_string_size("A").x
	
	var chars_per_line := mini(dialogue_length, max_chars_per_line)
	return roundi(avg_char_width * chars_per_line)


func _on_dialogue_started(id: String) -> void:
	speaker_label.text = ""
	dialogue_label.text = ""
	show()
	dialogue_started.emit(id)


func _on_dialogue_processed(
	speaker: Variant, dialogue: String, options: Array[String]
) -> void:
	# Set speaker
	if speaker is Character:
		speaker_label.text = speaker.name
	elif speaker is String:
		speaker_label.text = speaker
	else:
		printerr("Invalid speaker type!")
	
	# Set width dynamically
	panel.custom_minimum_size.x = _calculate_bubble_width(dialogue.length())
	
	# Set dialogue
	dialogue_label.text = _dialogue_parser._update_wait_tags(dialogue_label, dialogue)
	dialogue_label.get_v_scroll_bar().set_value_no_signal(0)
	_wait_effect.skip = false
	
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
	# Check auto-advance
	if auto_advance_enabled:
		var lifetime := auto_advance_base_delay \
				+ dialogue_label.text.length() * auto_advance_character_delay
		_lifetime_timer.timeout.connect(func(): select_option(0),
				CONNECT_ONE_SHOT)
		_lifetime_timer.start(lifetime)
#endregion


#region Setters
## Updates the font size for the speaker label.
func _set_font_size_speaker(value: int) -> void:
	font_size_speaker = value
	if not is_node_ready():
		return
	
	if speaker_label.label_settings:
		speaker_label.label_settings.font_size = font_size_speaker
	else:
		speaker_label.add_theme_font_size_override(&"font_size", font_size_speaker)


## Updates the font size for the dialogue text.
func _set_font_size_dialogue_text(value: int) -> void:
	font_size_dialogue_text = value
	if not is_node_ready():
		return
	
	dialogue_label.add_theme_font_size_override(&"bold_italics_font_size",
			font_size_dialogue_text)
	dialogue_label.add_theme_font_size_override(&"italics_font_size",
			font_size_dialogue_text)
	dialogue_label.add_theme_font_size_override(&"mono_font_size",
			font_size_dialogue_text)
	dialogue_label.add_theme_font_size_override(&"normal_font_size",
			font_size_dialogue_text)
	dialogue_label.add_theme_font_size_override(&"bold_font_size",
			font_size_dialogue_text)
#endregion
