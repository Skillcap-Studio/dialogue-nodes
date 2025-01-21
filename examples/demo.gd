extends Control


@export var demos: Array[DialogueData]

@onready var dialogue_box_old: DialogueBox = $DialogueBoxOld
@onready var dialogue_box_new: ScDialogueBubble = $DialogueBoxNew
@onready var dialogue_box = dialogue_box_new
@onready var particles = $Particles


func _ready():
	for demo in demos:
		var label = demo.resource_path.split('/')[-1].split('.')[0]
		$DemoSelector.add_item(label)
	
	dialogue_box.data = demos[0]
	$CheckButton.set_pressed_no_signal(dialogue_box_new.auto_advance_enabled)


func explode(_a=0):
	particles.emitting = true


func _on_Button_pressed():
	if not dialogue_box.is_running():
		dialogue_box.start()


func _on_dialogue_signal(value):
	match(value):
		'explode': explode()


func _on_demo_selected(index):
	dialogue_box.data = demos[index]
	$StartButton.release_focus()


func _on_locale_selected(index):
	match index:
		0:
			# English
			TranslationServer.set_locale('en')
		1:
			# Japanese
			TranslationServer.set_locale('ja')
			


func _on_check_button_pressed() -> void:
	dialogue_box_new.auto_advance_enabled = $CheckButton.button_pressed
