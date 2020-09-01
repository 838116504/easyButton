tool
#class_name EasyButton
extends Button

enum { PIVOT_LEFT_TOP = 0, PIVOT_TOP, PIVOT_RIGHT_TOP, 
		PIVOT_LEFT, PIVOT_CENTER, PIVOT_RIGHT,
		PIVOT_LEFT_BOTTOM, PIVOT_BOTTOM, PIVOT_RIGHT_BOTTOM }
enum { EFFECT_NONE = 0, EFFECT_MIX, EFFECT_SCALE, EFFECT_MIX_SCALE, EFFECT_FOLLOW }
const EFFECT_SHADER = preload("effect.shader")
const EFFECT_SHADER2 = preload("effect2.shader")
const DEFAULT_HOVER_EFFECT = EFFECT_MIX
const DEFAULT_PRESSED_EFFECT = EFFECT_SCALE
const DEFAULT_MIX = 0.2
const DEFAULT_MIX_COLOR = Color(0xFFFFFFFF)
const DEFAULT_SCALE = 0.8
const DEFAULT_SCALE_PIVOT = PIVOT_CENTER
const DEFAULT_MASK_ENABLE = false
const DEFAULT_MASK_THRESHOLD = 0.1
const DEFAULT_SOUND_VOLUME = 0.5
const COLOR_THEME_NAMES = { "hover_mix_color":DEFAULT_MIX_COLOR, "pressed_mix_color":DEFAULT_MIX_COLOR }
const BOOL_THEME_NAMES = { "mask_enable":DEFAULT_MASK_ENABLE }
const FLOAT_THEME_NAMES = { "hover_mix":DEFAULT_MIX, "hover_scale":DEFAULT_SCALE, "mask_threshold":DEFAULT_MASK_THRESHOLD, "pressed_mix":DEFAULT_MIX, "pressed_scale":DEFAULT_SCALE, "sound_volume":DEFAULT_SOUND_VOLUME }
const ENUM_THEME_NAMES = { "hover_effect":DEFAULT_HOVER_EFFECT, "hover_scale_pivot":DEFAULT_SCALE_PIVOT, "pressed_effect":DEFAULT_PRESSED_EFFECT, "pressed_scale_pivot":DEFAULT_SCALE_PIVOT }
const ENUM_THEME_OPTION_DICT = { 
		"Pivot":["Top left", "Top", "Top right",
		"Left", "Center", "Right",
		"Bottom left", "Bottom", "Bottom right"], 
		"Effect":["None", "Mix", "Scale", "Mix and scale", "Follow"]
		 }
const ENUM_THEME_PAIRS = { "hover_effect":"Effect", "hover_scale_pivot":"Pivot", "pressed_effect":"Effect", "pressed_scale_pivot":"Pivot" }
const SOUND_THEME_NAMES = { "mouse_enter_sound":Object(), "mouse_exit_sound":Object(), "mouse_press_sound":Object() }

var soundPlayer := AudioStreamPlayer.new()
var mask:BitMap = null
var hoverMaterial:ShaderMaterial = null
var pressMaterial:ShaderMaterial = null
var hoverPressMaterial:ShaderMaterial = null
var hoverPivotMode = null
var pressPivotMode = null
var hoverPressPivotMode = null
var hoverPressPivotMode2 = null
enum { FOLLOW_NONE = -1, FOLLOW_PRESSED, FOLLOW_HOVER }
var followStyle := FOLLOW_NONE
const FOLLOW_NAMES = [ "pressed", "hover" ]

func get_class() -> String:
	return "EasyButton"

func get_parent_class():
	return Button

static func get_parent_class_static():
	return Button

#func is_class(p_class:String) -> bool:
#	if p_class == get_class():
#		return true
#	return .is_class(p_class)

func _enter_tree():
	connect("mouse_entered", self, "_on_easy_button_mouse_entered")
	connect("mouse_exited", self, "_on_easy_button_mouse_exited")
	connect("button_down", self, "_on_easy_button_button_down")
	connect("button_up", self, "_on_easy_button_button_up")
	add_child(soundPlayer)
	_update_mask()
	_update_material()

func _exit_tree():
	disconnect("mouse_entered", self, "_on_easy_button_mouse_entered")
	disconnect("mouse_exited", self, "_on_easy_button_mouse_exited")
	disconnect("button_down", self, "_on_easy_button_button_down")
	disconnect("button_up", self, "_on_easy_button_button_up")

func _notification(what):
	if what == NOTIFICATION_THEME_CHANGED:
		var enable = ControlMethod.has_bool(self, "mask_enable")
		if (enable && (ControlMethod.get_bool(self, "mask_enable") != (mask != null))) || (!enable && (DEFAULT_MASK_ENABLE != (mask != null))):
			_update_mask()
		
		_update_material()
		
		minimum_size_changed()
	elif what == NOTIFICATION_RESIZED || what == NOTIFICATION_TRANSFORM_CHANGED:
		if hoverPivotMode:
			hoverMaterial.set_shader_param("scalePivot", rect_position + rect_size / 2.0 * Vector2(hoverPivotMode % 3, hoverPivotMode / 3))
		if pressPivotMode:
			pressMaterial.set_shader_param("scalePivot", rect_position + rect_size / 2.0 * Vector2(pressPivotMode % 3, pressPivotMode / 3))

func _update_mask():
	var alphaMask = ControlMethod.get_bool(self, "mask_enable") if ControlMethod.has_bool(self, "mask_enable") else DEFAULT_MASK_ENABLE
	if alphaMask:
		if !mask:
			mask = BitMap.new()
		var style = get_draw_stylebox()

		if style && style is StyleBoxTexture && style.texture:
			mask.create_from_image_alpha(style.texture.get_data(), ControlMethod.get_float(self, "mask_threshold") if ControlMethod.has_float(self, "mask_threshold") else DEFAULT_MASK_THRESHOLD)
	else:
		mask = null

func get_draw_stylebox() -> StyleBox:
	match get_draw_mode():
		DRAW_NORMAL:
			return get_stylebox("normal")
		DRAW_PRESSED, DRAW_HOVER_PRESSED:
			return get_stylebox("pressed")
		DRAW_HOVER:
			return get_stylebox("hover")
		DRAW_DISABLED:
			return get_stylebox("disabled")
	return null

func has_point(p_point):
	if mask == null:
		return Rect2(Vector2.ZERO, rect_size).has_point(p_point)
	var style = get_draw_stylebox()
	if !style || not style is StyleBoxTexture || !style.texture:
		return Rect2(Vector2.ZERO, rect_size).has_point(p_point)
	
	var target = p_point
	match style.axis_stretch_horizontal:
		StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH:
			target.x /= rect_size.x / mask.get_size().x
		StyleBoxTexture.AXIS_STRETCH_MODE_TILE:
			target.x = fmod(target.x, mask.get_size().x)
		StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT:
			var tileW = rect_size.x / round(rect_size.x / mask.get_size().x)
			target.x = fmod(target.x, tileW)
	match style.axis_stretch_vertical:
		StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH:
			target.y /= rect_size.y / mask.get_size().y
		StyleBoxTexture.AXIS_STRETCH_MODE_TILE:
			target.y = fmod(target.y, mask.get_size().y)
		StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT:
			var tileH = rect_size.y / round(rect_size.y / mask.get_size().y)
			target.y = fmod(target.y, tileH)
	
	return mask.get_bit(target)

func _pressed():
	if toggle_mode:
		return
	
	var sound = ControlMethod.get_sound(self, "mouse_press_sound")
	if sound:
		_set_sound(sound)

func _toggled(p_button_pressed):
	if p_button_pressed:
		var sound = ControlMethod.get_sound(self, "mouse_press_sound")
		if sound:
			_set_sound(sound)

func _set_sound(p_stream):
	soundPlayer.stream = p_stream
	if ControlMethod.has_float(self, "sound_volume"):
		soundPlayer.volume_db = linear2db(ControlMethod.get_float(self, "sound_volume"))
	else:
		soundPlayer.volume_db = linear2db(DEFAULT_SOUND_VOLUME)
	if p_stream && p_stream is AudioStream:
		soundPlayer.play()
	else:
		soundPlayer.stop()

func _update_material():
	if pressMaterial == hoverMaterial:
		pressMaterial = null
	var hoverEffect = ControlMethod.get_enum(self, "hover_effect") if ControlMethod.has_enum(self, "hover_effect") else DEFAULT_HOVER_EFFECT
	var pressEffect = ControlMethod.get_enum(self, "press_effect") if ControlMethod.has_enum(self, "press_effect") else DEFAULT_PRESSED_EFFECT
	var a = [hoverMaterial]
	if hoverEffect != EFFECT_FOLLOW:
		_set_effect("hover", a, hoverEffect)
	elif pressEffect == EFFECT_FOLLOW:
		_set_effect("hover", a, DEFAULT_HOVER_EFFECT)
	hoverMaterial = a[0]
	a = [pressMaterial]
	if pressEffect != EFFECT_FOLLOW:
		_set_effect("pressed", a, pressEffect)
		pressMaterial = a[0]
	elif hoverEffect == EFFECT_FOLLOW:
		_set_effect("pressed", a, DEFAULT_PRESSED_EFFECT)
		pressMaterial = a[0]
	else:
		pressMaterial = hoverMaterial
		pressPivotMode = null
	if hoverEffect == EFFECT_FOLLOW && pressEffect != EFFECT_FOLLOW:
		hoverMaterial = pressMaterial
		hoverPivotMode = null
	
	if hoverMaterial == null && pressMaterial == null:
		hoverPressMaterial = null
		hoverPressPivotMode = null
		hoverPressPivotMode2 = null
	elif hoverMaterial == null || hoverMaterial == pressMaterial:
		hoverPressMaterial = pressMaterial
		hoverPressPivotMode = null
		hoverPressPivotMode2 = null
	elif pressMaterial == null:
		hoverPressMaterial = hoverMaterial
		hoverPressPivotMode = null
		hoverPressPivotMode2 = null
	else:
		if hoverEffect == EFFECT_FOLLOW:
			hoverEffect = DEFAULT_HOVER_EFFECT
		if pressEffect == EFFECT_FOLLOW:
			pressEffect = DEFAULT_PRESSED_EFFECT
		hoverPressMaterial = ShaderMaterial.new()
		var mixUse := false
		var mix
		var mixColor
		if hoverEffect == EFFECT_MIX || hoverEffect == EFFECT_MIX_SCALE:
			mixUse = true
			mix = hoverMaterial.get_shader_param("mixRatio")
			mixColor = hoverMaterial.get_shader_param("mixColor")
			if pressEffect == EFFECT_MIX || pressEffect == EFFECT_MIX_SCALE:
				var pMix = pressMaterial.get_shader_param("mixRatio")
				var pMixColor = pressMaterial.get_shader_param("mixColor")
				var p1 = pMix - pMix * mix
				var p2 = mix
				var p3 = p1 + p2
				mixColor = Color((pMixColor.r * p1 + mixColor.r * p2)/p3, (pMixColor.g * p1 + mixColor.g * p2)/p3, (pMixColor.b * p1 + mixColor.b * p2)/p3)
				mix = p3
		elif pressEffect == EFFECT_MIX || pressEffect == EFFECT_MIX_SCALE:
			mixUse = true
			mix = pressMaterial.get_shader_param("mixRatio")
			mixColor = pressMaterial.get_shader_param("mixColor")
		
		if (hoverEffect == EFFECT_SCALE || hoverEffect == EFFECT_MIX_SCALE) && (pressEffect == EFFECT_SCALE || pressEffect == EFFECT_MIX_SCALE):
			hoverPressMaterial.shader = EFFECT_SHADER2
			hoverPressMaterial.set_shader_param("isMix", mixUse)
			if mixUse:
				hoverPressMaterial.set_shader_param("mixRatio", mix)
				hoverPressMaterial.set_shader_param("mixColor", mixColor)
			hoverPressMaterial.set_shader_param("scale", pressMaterial.get_shader_param("scale"))
			hoverPressMaterial.set_shader_param("scalePivot", pressMaterial.get_shader_param("scalePivot"))
			hoverPressMaterial.set_shader_param("scale2", hoverMaterial.get_shader_param("scale"))
			hoverPressMaterial.set_shader_param("scalePivot2", hoverMaterial.get_shader_param("scalePivot"))
		else:
			hoverPressMaterial.shader = EFFECT_SHADER
			hoverPressMaterial.set_shader_param("isMix", mixUse)
			if mixUse:
				hoverPressMaterial.set_shader_param("mixRatio", mix)
				hoverPressMaterial.set_shader_param("mixColor", mixColor)
			if pressEffect == EFFECT_SCALE || pressEffect == EFFECT_MIX_SCALE:
				hoverPressMaterial.set_shader_param("scale", pressMaterial.get_shader_param("scale"))
				hoverPressMaterial.set_shader_param("scalePivot", pressMaterial.get_shader_param("scalePivot"))
			elif hoverEffect == EFFECT_SCALE || hoverEffect == EFFECT_MIX_SCALE:
				hoverPressMaterial.set_shader_param("scale", hoverMaterial.get_shader_param("scale"))
				hoverPressMaterial.set_shader_param("scalePivot", hoverMaterial.get_shader_param("scalePivot"))


func _set_effect(p_themeHead:String, p_material:Array, p_effect:int):
#	var effect = ControlMethod.get_enum(self, p_themeHead + "_effect") if ControlMethod.has_enum(self, p_themeHead + "_effect") else p_defaultEffect
#	if effect == EFFECT_FOLLOW:
#		effect = p_defaultEffect
	match p_effect:
		EFFECT_MIX:
			if !p_material[0]:
				p_material[0] = ShaderMaterial.new()
				p_material[0].shader = EFFECT_SHADER
			
			p_material[0].set_shader_param("scale", 1.0)
			p_material[0].set_shader_param("isMix", true)
			p_material[0].set_shader_param("mixColor", get_color(p_themeHead + "_mix_color") if has_color(p_themeHead + "_mix_color") else DEFAULT_MIX_COLOR)
			p_material[0].set_shader_param("mixRatio", ControlMethod.get_float(self, p_themeHead + "_mix") if ControlMethod.has_float(self, p_themeHead + "_mix") else DEFAULT_MIX)
			if p_themeHead == "hover":
				hoverPivotMode = null
			else:
				pressPivotMode = null
		EFFECT_SCALE:
			if !p_material[0]:
				p_material[0] = ShaderMaterial.new()
				p_material[0].shader = EFFECT_SHADER
			
			p_material[0].set_shader_param("scale", ControlMethod.get_float(self, p_themeHead + "_scale") if ControlMethod.has_float(self, p_themeHead + "_scale") else DEFAULT_SCALE)
			var scalePivot = DEFAULT_SCALE_PIVOT
			if ControlMethod.has_enum(self, p_themeHead + "_scale_pivot"):
				scalePivot = ControlMethod.get_enum(self, p_themeHead + "_scale_pivot")
			p_material[0].set_shader_param("scalePivot", rect_position + rect_size / 2.0 * Vector2(scalePivot % 3, scalePivot / 3))
			p_material[0].set_shader_param("isMix", false)
			if p_themeHead == "hover":
				hoverPivotMode = scalePivot
			else:
				pressPivotMode = scalePivot
		EFFECT_MIX_SCALE:
			if !p_material[0]:
				p_material[0] = ShaderMaterial.new()
				p_material[0].shader = EFFECT_SHADER
			
			p_material[0].set_shader_param("scale", ControlMethod.get_float(self, p_themeHead + "_scale") if ControlMethod.has_float(self, p_themeHead + "_scale") else DEFAULT_SCALE)
			var scalePivot = DEFAULT_SCALE_PIVOT
			if ControlMethod.has_enum(self, p_themeHead + "_scale_pivot"):
				scalePivot = ControlMethod.get_enum(self, p_themeHead + "_scale_pivot")
			p_material[0].set_shader_param("scalePivot", rect_position + rect_size / 2.0 * Vector2(scalePivot % 3, scalePivot / 3))
			
			p_material[0].set_shader_param("isMix", true)
			p_material[0].set_shader_param("mixColor", get_color(p_themeHead + "_mix_color") if has_color(p_themeHead + "_mix_color") else DEFAULT_MIX_COLOR)
			p_material[0].set_shader_param("mixRatio", ControlMethod.get_float(self, p_themeHead + "_mix") if ControlMethod.has_float(self, p_themeHead + "_mix") else DEFAULT_MIX)
			if p_themeHead == "hover":
				hoverPivotMode = scalePivot
			else:
				pressPivotMode = scalePivot
		_:
			p_material[0] = null
			if p_themeHead == "hover":
				hoverPivotMode = null
			else:
				pressPivotMode = null

func _update_draw_mode():
	if followStyle != FOLLOW_NONE:
		add_stylebox_override(FOLLOW_NAMES[followStyle], StyleBoxEmpty.new())
		followStyle = FOLLOW_NONE
	match get_draw_mode():
		DRAW_NORMAL:
			material = null
		DRAW_PRESSED:
			if not get_draw_stylebox() is StyleBoxEmpty:
				material = null
			else:
				var normalStyle = get_stylebox("normal")
				if normalStyle:
					followStyle = FOLLOW_PRESSED
					add_stylebox_override(FOLLOW_NAMES[followStyle], normalStyle)
#				if ControlMethod.has_enum(self, "pressed_effect") && ControlMethod.get_enum(self, "pressed_effect") == EFFECT_FOLLOW && \
#						(!ControlMethod.has_enum(self, "hover_effect") || ControlMethod.get_enum(self, "hover_effect") != EFFECT_FOLLOW):
#					material = hoverMaterial
#				else:
				material = pressMaterial
		DRAW_HOVER_PRESSED:
			if not get_draw_stylebox() is StyleBoxEmpty:
				material = null
			else:
				var normalStyle = get_stylebox("normal")
				if normalStyle:
					followStyle = FOLLOW_PRESSED
					add_stylebox_override(FOLLOW_NAMES[followStyle], normalStyle)
				material = hoverPressMaterial
		DRAW_HOVER:
			if not get_draw_stylebox() is StyleBoxEmpty:
				material = null
			else:
				var normalStyle = get_stylebox("normal")
				if normalStyle:
					followStyle = FOLLOW_HOVER
					add_stylebox_override(FOLLOW_NAMES[followStyle], normalStyle)
#				if ControlMethod.has_enum(self, "hover_effect") && ControlMethod.get_enum(self, "hover_effect") == EFFECT_FOLLOW && \
#						(!ControlMethod.has_enum(self, "pressed_effect") || ControlMethod.get_enum(self, "pressed_effect") != EFFECT_FOLLOW):
#					material = pressMaterial
#				else:
				material = hoverMaterial
		DRAW_DISABLED:
			material = null
		_:
			material = null
	pass

func _on_easy_button_mouse_entered():
	var sound = ControlMethod.get_sound(self, "mouse_enter_sound")
	if sound:
		_set_sound(sound)
	
	yield(get_tree(), "idle_frame")
	_update_draw_mode()

func _on_easy_button_mouse_exited():
	var sound = ControlMethod.get_sound(self, "mouse_exit_sound")
	if sound:
		_set_sound(sound)
	
	yield(get_tree(), "idle_frame")
	_update_draw_mode()

func _on_easy_button_button_down():
	yield(get_tree(), "idle_frame")
	_update_draw_mode()

func _on_easy_button_button_up():
	yield(get_tree(), "idle_frame")
	_update_draw_mode()


func _get(p_property):
	var splitArray = p_property.split("/", true, 1)
	if splitArray.size() < 2 || splitArray[0] != get_class():
		return null
	
	if BOOL_THEME_NAMES.has(splitArray[1]):
		return ControlMethod.get_bool(self, splitArray[1]) if ControlMethod.has_bool_override(self, splitArray[1]) else BOOL_THEME_NAMES[splitArray[1]]
	if FLOAT_THEME_NAMES.has(splitArray[1]):
		return ControlMethod.get_float(self, splitArray[1]) if ControlMethod.has_float_override(self, splitArray[1]) else FLOAT_THEME_NAMES[splitArray[1]]
	if SOUND_THEME_NAMES.has(splitArray[1]):
		return ControlMethod.get_sound(self, splitArray[1]) if ControlMethod.has_sound_override(self, splitArray[1]) else SOUND_THEME_NAMES[splitArray[1]]
	if ENUM_THEME_NAMES.has(splitArray[1]):
		return ControlMethod.get_enum(self, splitArray[1]) if ControlMethod.has_enum_override(self, splitArray[1]) else ENUM_THEME_NAMES[splitArray[1]]
	if COLOR_THEME_NAMES.has(splitArray[1]):
		return get_color(splitArray[1]) if has_color_override(splitArray[1]) else COLOR_THEME_NAMES[splitArray[1]]
	return null

func _set(p_property, p_value):
	var splitArray = p_property.split("/", true, 1)
	if splitArray.size() < 2 || splitArray[0] != get_class():
		return false
	
	if BOOL_THEME_NAMES.has(splitArray[1]):
		if ControlMethod.has_bool_override(self, splitArray[1]) || p_value != null:
			ControlMethod.add_bool_override(self, splitArray[1], p_value)
		else:
			ControlMethod.add_bool_override(self, splitArray[1], BOOL_THEME_NAMES[splitArray[1]])
	elif FLOAT_THEME_NAMES.has(splitArray[1]):
		if ControlMethod.has_float_override(self, splitArray[1]) || p_value != null:
			ControlMethod.add_float_override(self, splitArray[1], p_value)
		else:
			ControlMethod.add_float_override(self, splitArray[1], FLOAT_THEME_NAMES[splitArray[1]])
	elif SOUND_THEME_NAMES.has(splitArray[1]):
		if ControlMethod.has_sound_override(self, splitArray[1]) || p_value != null:
			ControlMethod.add_sound_override(self, splitArray[1], p_value)
		else:
			ControlMethod.add_sound_override(self, splitArray[1], SOUND_THEME_NAMES[splitArray[1]])
	elif ENUM_THEME_NAMES.has(splitArray[1]):
		if ControlMethod.has_enum_override(self, splitArray[1]) || p_value != null:
			ControlMethod.add_enum_override(self, splitArray[1], p_value)
		else:
			ControlMethod.add_enum_override(self, splitArray[1], ENUM_THEME_NAMES[splitArray[1]])
	elif COLOR_THEME_NAMES.has(splitArray[1]):
		if has_color_override(splitArray[1]) || p_value != null:
			add_color_override(splitArray[1], p_value)
		else:
			add_color_override(splitArray[1], COLOR_THEME_NAMES[splitArray[1]])
	else:
		return false
	
	return true

func _get_property_list():
	var ret = []
	var uncheckedUsage := PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_CHECKABLE
	var checkedUsage := PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_CHECKABLE | PROPERTY_USAGE_CHECKED
	
#	for i in BOOL_THEME_NAMES.keys():
#		if ControlMethod.has_bool_override(self, i):
#			ret.append({ "name":get_class() + "/" + i, "type":TYPE_BOOL, "usage":checkedUsage })
#		else:
#			ret.append({ "name":get_class() + "/" + i, "type":TYPE_BOOL, "usage":uncheckedUsage })
#
#	for i in FLOAT_THEME_NAMES.keys():
#		if ControlMethod.has_float_override(self, i):
#			ret.append({ "name":get_class() + "/" + i, "type":TYPE_REAL, "usage":checkedUsage })
#		else:
#			ret.append({ "name":get_class() + "/" + i, "type":TYPE_REAL, "usage":uncheckedUsage })
#
#	for i in SOUND_THEME_NAMES.keys():
#		if ControlMethod.has_sound_override(self, i):
#			ret.append({ "name":get_class() + "/" + i, "type":TYPE_OBJECT, "hint":PROPERTY_HINT_RESOURCE_TYPE, "hint_string":"AudioStream", "usage":checkedUsage })
#		else:
#			ret.append({ "name":get_class() + "/" + i, "type":TYPE_OBJECT, "hint":PROPERTY_HINT_RESOURCE_TYPE, "hint_string":"AudioStream", "usage":uncheckedUsage })
#
#	for i in ENUM_THEME_NAMES.keys():
#		if ControlMethod.has_enum_override(self, i):
#			ret.append({ "name":get_class() + "/" + i, "type":TYPE_INT, "hint":PROPERTY_HINT_ENUM, "hint_string":ENUM_THEME_OPTION_DICT[ENUM_THEME_PAIRS[i]],"usage":checkedUsage })
#		else:
#			ret.append({ "name":get_class() + "/" + i, "type":TYPE_INT, "hint":PROPERTY_HINT_ENUM, "hint_string":ENUM_THEME_OPTION_DICT[ENUM_THEME_PAIRS[i]], "usage":uncheckedUsage })
#
#	for i in COLOR_THEME_NAMES.keys():
#		if has_color_override(i):
#			ret.append({ "name":get_class() + "/" + i, "type":TYPE_COLOR, "usage":checkedUsage })
#		else:
#			ret.append({ "name":get_class() + "/" + i, "type":TYPE_COLOR, "usage":uncheckedUsage })

	_property_list_add_sound(ret, "mouse_enter_sound")
	_property_list_add_sound(ret, "mouse_exit_sound")
	_property_list_add_sound(ret, "mouse_press_sound")
	if ControlMethod.has_float_override(self, "sound_volume"):
		ret.append({ "name":get_class() + "/sound_volume", "type":TYPE_REAL, "hint":PROPERTY_HINT_RANGE, "hint_string":"0,1","usage":checkedUsage })
	else:
		ret.append({ "name":get_class() + "/sound_volume", "type":TYPE_REAL, "hint":PROPERTY_HINT_RANGE, "hint_string":"0,1", "usage":uncheckedUsage })

	if ControlMethod.has_bool_override(self, "mask_enable"):
		ret.append({ "name":get_class() + "/mask_enable", "type":TYPE_BOOL, "usage":checkedUsage })
	else:
		ret.append({ "name":get_class() + "/mask_enable", "type":TYPE_BOOL, "usage":uncheckedUsage })
	if not ControlMethod.has_bool_override(self, "mask_enable") || ControlMethod.get_bool(self, "mask_enable"):
		_property_list_add_float(ret, "mask_threshold")

	_property_list_add_enum(ret, "hover_effect")
	if not ControlMethod.has_enum_override(self, "hover_effect"):
		_property_list_add_float(ret, "hover_mix")
		_property_list_add_color(ret, "hover_mix_color")
		_property_list_add_float(ret, "hover_scale")
		_property_list_add_enum(ret, "hover_scale_pivot")
	else:
		var effect = ControlMethod.get_enum(self, "hover_effect")
		if effect == EFFECT_MIX || effect == EFFECT_MIX_SCALE:
			_property_list_add_float(ret, "hover_mix")
			_property_list_add_color(ret, "hover_mix_color")
		if effect == EFFECT_SCALE || effect == EFFECT_MIX_SCALE:
			_property_list_add_float(ret, "hover_scale")
			_property_list_add_enum(ret, "hover_scale_pivot")

	_property_list_add_enum(ret, "pressed_effect")
	if not ControlMethod.has_enum_override(self, "pressed_effect"):
		_property_list_add_float(ret, "pressed_mix")
		_property_list_add_color(ret, "pressed_mix_color")
		_property_list_add_float(ret, "pressed_scale")
		_property_list_add_enum(ret, "pressed_scale_pivot")
	else:
		var effect = ControlMethod.get_enum(self, "pressed_effect")
		if effect == EFFECT_MIX || effect == EFFECT_MIX_SCALE:
			_property_list_add_float(ret, "pressed_mix")
			_property_list_add_color(ret, "pressed_mix_color")
		if effect == EFFECT_SCALE || effect == EFFECT_MIX_SCALE:
			_property_list_add_float(ret, "pressed_scale")
			_property_list_add_enum(ret, "pressed_scale_pivot")
	return ret

func _property_list_add_sound(p_list:Array, p_sound:String):
	if ControlMethod.has_sound_override(self, p_sound):
		p_list.append({ "name":get_class() + "/" + p_sound, "type":TYPE_OBJECT, "hint":PROPERTY_HINT_RESOURCE_TYPE, "hint_string":"AudioStream", "usage":PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_CHECKABLE | PROPERTY_USAGE_CHECKED })
	else:
		p_list.append({ "name":get_class() + "/" + p_sound, "type":TYPE_OBJECT, "hint":PROPERTY_HINT_RESOURCE_TYPE, "hint_string":"AudioStream", "usage":PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_CHECKABLE })

func _property_list_add_float(p_list:Array, p_float:String):
	if ControlMethod.has_float_override(self, p_float):
		p_list.append({ "name":get_class() + "/" + p_float, "type":TYPE_REAL, "usage":PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_CHECKABLE | PROPERTY_USAGE_CHECKED })
	else:
		p_list.append({ "name":get_class() + "/" + p_float, "type":TYPE_REAL, "usage":PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_CHECKABLE })

func _property_list_add_enum(p_list:Array, p_enum:String):
	var hintString:String = str(ENUM_THEME_OPTION_DICT[ENUM_THEME_PAIRS[p_enum]])
	hintString = hintString.trim_prefix("[").trim_suffix("]")
	hintString = " " + hintString
	if ControlMethod.has_enum_override(self, p_enum):
		p_list.append({ "name":get_class() + "/" + p_enum, "type":TYPE_INT, "hint":PROPERTY_HINT_ENUM, "hint_string":hintString,"usage":PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_CHECKABLE | PROPERTY_USAGE_CHECKED })
	else:
		p_list.append({ "name":get_class() + "/" + p_enum, "type":TYPE_INT, "hint":PROPERTY_HINT_ENUM, "hint_string":hintString, "usage":PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_CHECKABLE })

func _property_list_add_color(p_list:Array, p_color:String):
	if has_color_override(p_color):
		p_list.append({ "name":get_class() + "/" + p_color, "type":TYPE_COLOR, "usage":PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_CHECKABLE | PROPERTY_USAGE_CHECKED })
	else:
		p_list.append({ "name":get_class() + "/" + p_color, "type":TYPE_COLOR, "usage":PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_CHECKABLE })

func _register_default_theme(p_theme:MyTheme):
	for i in BOOL_THEME_NAMES.keys():
		p_theme.set_bool(i, get_class(), BOOL_THEME_NAMES[i])

	for i in FLOAT_THEME_NAMES.keys():
		p_theme.set_float(i, get_class(), FLOAT_THEME_NAMES[i])

	for i in SOUND_THEME_NAMES.keys():
		p_theme.set_sound(i, get_class(), SOUND_THEME_NAMES[i])

	for i in ENUM_THEME_NAMES.keys():
		p_theme.set_enum(i, get_class(), ENUM_THEME_NAMES[i], ENUM_THEME_OPTION_DICT[ENUM_THEME_PAIRS[i]])

	for i in COLOR_THEME_NAMES.keys():
		p_theme.set_color(i, get_class(), COLOR_THEME_NAMES[i])
