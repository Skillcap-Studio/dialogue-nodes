@tool
@icon("res://addons/skillcap_dialogue_nodes/icons/DialogueBubble.svg")
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
## Passes the [param variable_name] along with its [param value].
signal variable_changed(variable_name: String, value)
## Triggered when a dialogue tree has ended processing and reached the end of
## the dialogue.
## The [ScDialogueBubble] may hide of get freed based on the [member end_action]
## property.
signal dialogue_ended

## What happens when the dialogue ends.
enum EndAction {
	## Free the object.
	FREE,
	## Hide the object.
	HIDE,
}

@export_group("Data")
## Contains the [param DialogueData] resource created using the Dialogue Nodes editor.
@export var data: DialogueData:
	set = _set_data
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
@export var font_size_option_buttons := 10:
	set = _set_font_size_option_buttons

@export_group("Visuals")
## The maximum number of characters allowed in a single line.
## This will determine the width of the dialogue bubble.
@export var max_chars_per_line := 25
## The minimum width of the bubble, in pixels.
@export var minimum_width := 100
## The maximum number of options to show in the dialogue box.
@export_range(1, 4) var max_options_count := 2:
	set = _set_max_options_count
@export_range(0.0, 1.0, 0.01) var opacity := 0.7:
	set = _set_opacity
## Icon displayed when no text options are available.
@export var next_icon: Texture2D

@export_group("End")
## Whether the dialogue will be ended automatically or not.
@export var auto_end_enabled := true
## The behavior when the dialogue ends.
@export var end_action := EndAction.FREE

@export_group("Misc")
# TODO: check if we're gonna need this (ATM there's no scrolling enabled)
## Speed of scroll when using joystick/keyboard input.
@export var scroll_speed := 4

## Contains the variable data from the [param DialogueData] parsed in an easy
## to access dictionary.[br]
## Example: [code]{ "COINS": 10, "NAME": "Obama", "ALIVE": true }[/code]
var variables: Dictionary
## Contains all the [param Character] resources loaded from the path in the [member data].
var characters: Array[Character]
## The node representing the speaking entity. It will be used to determine the
## dialogue box's position in the game world.
var speaker_node: Node2D
var _wait_effect: RichTextWait
var _option_buttons: Array[Button] = []
## Processed on each dialogue. If [code]true[/code], the current dialogue has options.
var _has_options := false

@onready var panel: PanelContainer = %Panel
@onready var dialogue_label: RichTextLabel = %DialogueLabel
@onready var options_container: BoxContainer = %Options
@onready var speaker_label: Label = %SpeakerLabel
@onready var _dialogue_parser: DialogueParser = %DialogueParser
@onready var _lifetime_timer: Timer = %LifetimeTimer


#region Built-in Virtual Methods
func _ready() -> void:
	for i: int in range(options_container.get_child_count()):
		var option: Button = options_container.get_child(i)
		_option_buttons.append(option)
	
	# Reset the panel's size when [member dialogue_label] or 
	# [member options_container] resize
	dialogue_label.resized.connect(func(): panel.size = Vector2.ZERO)
	options_container.resized.connect(func(): panel.size = Vector2.ZERO)
	
	_set_data(data)
	_set_max_options_count(max_options_count)
	_set_font_size_speaker(font_size_speaker)
	_set_font_size_dialogue_text(font_size_dialogue_text)
	_set_font_size_option_buttons(font_size_option_buttons)
	
	if Engine.is_editor_hint():
		return
	
	_dialogue_parser.dialogue_started.connect(_on_dialogue_started)
	_dialogue_parser.dialogue_processed.connect(_on_dialogue_processed)
	_dialogue_parser.option_selected.connect(_on_option_selected)
	_dialogue_parser.dialogue_signal.connect(_on_dialogue_signal)
	_dialogue_parser.variable_changed.connect(_on_variable_changed)
	_dialogue_parser.dialogue_ended.connect(_on_dialogue_ended)
	
	# Initialize option buttons
	for i: int in range(_option_buttons.size()):
		var option: Button = _option_buttons[i]
		option.pressed.connect(select_option.bind(i))
	
	for effect in dialogue_label.custom_effects. \
			filter(func(item): return item is RichTextWait):
		_wait_effect = effect
		_wait_effect.wait_finished.connect(_on_wait_effect_wait_finished)
		break
	if not _wait_effect:
		printerr("RichTextWait effect is missing!")
	
	options_container.hide()
	hide()


# TODO: should this be handled in the physics process?
func _process(delta: float) -> void:
	if not is_running():
		return
	
	# Update position
	global_position = _get_target_position()
	
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
#endregion


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


## Executes the ending action based on [member end_action].
func end() -> void:
	if is_running():
		stop()
	
	match end_action:
		EndAction.FREE:
			queue_free()
		EndAction.HIDE:
			hide()


## Continues processing the dialogue tree from the node connected to
## the option at [param idx].
func select_option(idx: int) -> void:
	if not _dialogue_parser:
		return
	
	_dialogue_parser.select_option(idx)


## Returns [code]true[/code] if the [ScDialogueBubble] is processing a dialogue tree.
func is_running() -> bool:
	return _dialogue_parser.is_running()


func get_panel_size() -> Vector2:
	return panel.size
#endregion


#region Fluent Interfaces
func set_dialogue_data(data_: DialogueData) -> ScDialogueBubble:
	data = data_
	return self


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


func set_max_chars_per_line(max_chars_per_line_: int) -> ScDialogueBubble:
	max_chars_per_line = max_chars_per_line_
	return self


func set_minimum_width(minimum_width_: int) -> ScDialogueBubble:
	minimum_width = minimum_width_
	return self


func set_opacity(opacity_: float) -> ScDialogueBubble:
	opacity = opacity_
	return self


func set_auto_end_enabled(auto_end_enabled_: bool) -> ScDialogueBubble:
	auto_end_enabled = auto_end_enabled_
	return self


func set_end_action(end_action_: EndAction) -> ScDialogueBubble:
	end_action = end_action_
	return self
#endregion


#region Private methods
## Returns the bubble width by calculating the average character's width, 
## using a common character.[br]
## The returned value will never exceed [member max_chars_per_line].
func _calculate_bubble_width(dialogue_length: int) -> int:
	var avg_char_width := dialogue_label.get_theme_font(&"normal_font") \
			.get_string_size("A").x
	
	var chars_per_line := mini(dialogue_length, max_chars_per_line)
	return roundi(avg_char_width * chars_per_line)


## Returns the bubble's position based on [member speaker_node].
func _get_target_position() -> Vector2:
	return global_position if not speaker_node \
		else speaker_node.get_global_transform_with_canvas().origin


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
	var calculated_width := _calculate_bubble_width(dialogue.length())
	panel.custom_minimum_size.x = maxi(minimum_width, calculated_width)
	
	# Set dialogue
	dialogue_label.text = _dialogue_parser._update_wait_tags(dialogue_label, dialogue)
	dialogue_label.get_v_scroll_bar().set_value_no_signal(0)
	_wait_effect.skip = false
	
	# Set options
	for i: int in range(_option_buttons.size()):
		var option: Button = _option_buttons[i]
		option.icon = null
		if i >= options.size():
			option.hide()
		else:
			option.text = options[i].replace("[br]", "\n")
			option.show()
	_has_options = options.size() > 1
	
	# Auto-advance only if there are no options, otherwise show button/label
	if options.size() == 1 and options[0].is_empty():
		if auto_advance_enabled:
			var lifetime := auto_advance_base_delay \
					+ dialogue_label.text.length() * auto_advance_character_delay
			_lifetime_timer.timeout.connect(func(): select_option(0),
					CONNECT_ONE_SHOT)
			_lifetime_timer.start(lifetime)
		else:
			var advance_btn: Button = _option_buttons[0]
			advance_btn.icon = next_icon
	
	options_container.hide()
	dialogue_processed.emit(speaker, dialogue, options)


func _on_option_selected(idx: int) -> void:
	option_selected.emit(idx)


func _on_dialogue_signal(value: String) -> void:
	dialogue_signal.emit(value)


func _on_variable_changed(variable_name: String, value) -> void:
	variable_changed.emit(variable_name, value)


func _on_dialogue_ended() -> void:
	dialogue_ended.emit()
	
	if auto_end_enabled:
		end()


## Triggered each time a dialogue text is fully shown.
func _on_wait_effect_wait_finished() -> void:
	# Check if one or more buttons should be displayed
	if not auto_advance_enabled or _has_options:
		options_container.show()
		_option_buttons[0].grab_focus()
#endregion


#region Setters
func _set_data(value: DialogueData) -> void:
	data = value
	if not is_node_ready():
		return
	
	_dialogue_parser.data = value
	variables = _dialogue_parser.variables
	characters = _dialogue_parser.characters


func _set_max_options_count(value: int) -> void:
	max_options_count = value
	if not is_node_ready():
		return
	
	for option in _option_buttons:
		option.hide()
	
	for i: int in range(max_options_count):
		_option_buttons[i].show()


func _set_opacity(value: float) -> void:
	opacity = value


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


## Updates the font size in all option buttons.
func _set_font_size_option_buttons(value: int) -> void:
	font_size_option_buttons = value
	if not is_node_ready():
		return
	
	for button in _option_buttons:
		button.add_theme_font_size_override(&"font_size", font_size_option_buttons)
#endregion
