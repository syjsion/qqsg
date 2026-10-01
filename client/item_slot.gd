class_name ItemSlot
extends Button

signal chosen(key: String)
signal activated(key: String)
signal context_requested(key: String)

var entry: Dictionary = {}
var icon_group = "items"
var icon_id = ""
var badge = ""
var key_hint = ""
var marked = false
var cooldown = 0.0
var cooldown_max = 1.0
var locked = false

func _init() -> void:
	custom_minimum_size = Vector2(58, 58)
	focus_mode = Control.FOCUS_NONE
	for state in ["normal","hover","pressed","disabled","focus"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
	tooltip_text = "空格"
	pressed.connect(func(): chosen.emit(str(entry.get("key", icon_id))))

func _gui_input(event: InputEvent) -> void:
	if disabled: return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			context_requested.emit(str(entry.get("key", icon_id)))
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
			chosen.emit(str(entry.get("key", icon_id)))
			activated.emit(str(entry.get("key", icon_id)))
			accept_event()

func _draw() -> void:
	var background = UIArt.texture("ui", "slot_selected" if marked else "slot_empty" if icon_id == "" else "slot")
	if background: draw_texture_rect(background, Rect2(Vector2.ZERO, size), false)
	var icon = UIArt.texture(icon_group, icon_id)
	if icon: draw_texture_rect(icon, Rect2(Vector2(7, 7), size - Vector2(14,14)), false, Color(0.5,0.5,0.5) if disabled or locked else Color.WHITE)
	if entry.has("item") and Catalog.table("items").get(entry.item,{}).get("quality", "") == "fine":
		draw_rect(Rect2(Vector2(2,2),size-Vector2(4,4)), Color("73c8ff"), false, 2)
	if marked: draw_rect(Rect2(Vector2(1,1),size-Vector2(2,2)), Color("ffe192"), false, 2)
	if cooldown > 0:
		var height = (size.y - 4) * clampf(cooldown / maxf(0.01,cooldown_max),0,1)
		draw_rect(Rect2(Vector2(2,size.y-2-height),Vector2(size.x-4,height)),Color(0.02,0.05,0.08,0.72))
	var font = get_theme_font("font")
	var color = Color("ffedb2")
	if key_hint != "": _text(font, key_hint, Vector2(5,16), 13, color)
	var bottom = "%.1f" % cooldown if cooldown > 0 else badge
	if locked: bottom = "未解锁"
	if bottom != "": _text(font, bottom, Vector2(size.x-font.get_string_size(bottom,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x-5,size.y-6), 13,color)
	if entry.has("gear") and int(entry.gear.enhance) > 0: _text(font,"+%d" % entry.gear.enhance,Vector2(5,16),13,color)

func _text(font: Font, value: String, point: Vector2, px: int, color: Color) -> void:
	draw_string_outline(font, point, value, HORIZONTAL_ALIGNMENT_LEFT,-1,px,3,Color("10232c"))
	draw_string(font,point,value,HORIZONTAL_ALIGNMENT_LEFT,-1,px,color)

func _make_custom_tooltip(for_text: String) -> Object:
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel",UIArt.frame(14))
	var line = HBoxContainer.new(); panel.add_child(line)
	if icon_id != "": line.add_child(UIArt.image(icon_group,icon_id,Vector2(44,44)))
	var caption = Label.new(); caption.text = for_text
	caption.custom_minimum_size.x = 280
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_size_override("font_size",14)
	line.add_child(caption)
	return panel
