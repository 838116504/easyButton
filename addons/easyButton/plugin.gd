tool
extends EditorPlugin


func _enter_tree():
	add_custom_type("EasyButton", "Button", preload("easyButton.gd"), get_editor_interface().get_base_control().get_icon("Button", "EditorIcons"))


func _exit_tree():
	remove_custom_type("EasyButton")
