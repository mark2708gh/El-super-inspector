extends CharacterBody3D
class_name InspectorPlayer

@export_group("Movimiento y Físicas - El Inspector")
@export var velocidad_caminar: float = 3.6
@export var aceleracion: float = 12.0
@export var friccion: float = 15.0
@export var gravedad: float = 14.0

@export_group("Cámara 360° y Visión Periférica 180°")
@export var sensibilidad_tactil: float = 0.24
## Campo visual horizontal de la cámara (sobre 125° genera efecto ojo de pez en proyección perspectiva)
@export_range(75.0, 140.0, 1.0) var fov_horizontal: float = 115.0
## Arco horizontal frontal de detección periférica (180° = -90° izq. a +90° der. mirando a un lado)
@export_range(90.0, 180.0, 1.0) var angulo_vision_periferica: float = 180.0
@export var limite_vertical_arriba: float = 85.0
@export var limite_vertical_abajo: float = 85.0

@export_group("Inspección de Riesgos")
@export var distancia_periferica: float = 6.0
@export var distancia_inspeccion: float = 2.6

# Nodos autogenerados
var _pivote_cabeza: Node3D
var _camara: Camera3D
var _hud_layer: CanvasLayer
var _overlay_ui: Control
var _label_estado: Label
var _boton_inspeccionar: Button

# Estado de cámara y balanceo
var _pitch_camara_deg: float = 0.0
var _balanceo_tiempo: float = 0.0

# Estado Multi-Touch y Mouse para pruebas en PC
var _touch_idx_joy: int = -1
var _touch_idx_cam: int = -1
var _joy_centro: Vector2 = Vector2.ZERO
var _joy_pos_actual: Vector2 = Vector2.ZERO
var _joy_radio_max: float = 85.0
var _input_joystick: Vector2 = Vector2.ZERO
var _arrastrando_mouse_izq: bool = false
var _arrastrando_mouse_der: bool = false

# Estado de detección (Zona focal + Periferia 180°)
var _riesgo_focal: String = ""
var _alerta_periferica_izq: bool = false
var _alerta_periferica_der: bool = false
var _cantidad_en_periferia: int = 0

func _ready() -> void:
	_configurar_fisicas_escalera()
	_construir_nodos_jugador()
	_construir_hud_tactil()
	_posicionar_en_spawn_casa()

# ==============================================================================
# 1. FÍSICAS PARA ESCALERA DE CASA 10x9m Y CÁMARA GRAN ANGULAR
# ==============================================================================
func _configurar_fisicas_escalera() -> void:
	floor_max_angle = deg_to_rad(52.0)
	floor_snap_length = 0.18
	floor_stop_on_slope = true
	floor_constant_speed = true
	floor_block_on_wall = true

func _construir_nodos_jugador() -> void:
	if not has_node("ColisionInspector"):
		var col := CollisionShape3D.new()
		col.name = "ColisionInspector"
		var capsula := CapsuleShape3D.new()
		capsula.radius = 0.34
		capsula.height = 1.75
		col.shape = capsula
		col.position = Vector3(0.0, 0.875, 0.0)
		add_child(col)

	_pivote_cabeza = Node3D.new()
	_pivote_cabeza.name = "PivoteCabeza"
	_pivote_cabeza.position = Vector3(0.0, 1.60, 0.0)
	add_child(_pivote_cabeza)

	_camara = Camera3D.new()
	_camara.name = "CamaraInspector"
	# KEEP_WIDTH hace que `fov` controle el ángulo HORIZONTAL en cualquier celular
	_camara.keep_aspect = Camera3D.KEEP_WIDTH
	_camara.fov = fov_horizontal
	_camara.near = 0.05
	_camara.current = true
	_pivote_cabeza.add_child(_camara)

func _posicionar_en_spawn_casa() -> void:
	if global_position.length_squared() < 0.01 and get_tree() and get_tree().current_scene:
		var marker_spawn := get_tree().current_scene.find_child("SpawnJugador_Antejardin", true, false) as Node3D
		if marker_spawn:
			global_position = marker_spawn.global_position
			# Orientar hacia +Z (puerta principal P1 de la casa)
			rotation.y = PI

# ==============================================================================
# 2. HUD TÁCTIL CON JOYSTICK Y ALERTAS PERIFÉRICAS DE 180°
# ==============================================================================
func _construir_hud_tactil() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "HUD_InspectorMovil"
	add_child(_hud_layer)

	_overlay_ui = Control.new()
	_overlay_ui.name = "OverlayTactil"
	_overlay_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_ui.draw.connect(_dibujar_ui_tactil)
	_hud_layer.add_child(_overlay_ui)

	_label_estado = Label.new()
	_label_estado.position = Vector2(24.0, 20.0)
	_label_estado.add_theme_font_size_override("font_size", 18)
	_label_estado.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98))
	_label_estado.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	_label_estado.add_theme_constant_override("shadow_offset_x", 2)
	_label_estado.add_theme_constant_override("shadow_offset_y", 2)
	_hud_layer.add_child(_label_estado)

	_boton_inspeccionar = Button.new()
	_boton_inspeccionar.text = "INSPECCIONAR RIESGO"
	_boton_inspeccionar.custom_minimum_size = Vector2(260.0, 56.0)
	_boton_inspeccionar.visible = false
	_boton_inspeccionar.pressed.connect(_on_boton_inspeccionar_pressed)
	_hud_layer.add_child(_boton_inspeccionar)

	get_viewport().size_changed.connect(_actualizar_posiciones_hud)
	_actualizar_posiciones_hud()

func _actualizar_posiciones_hud() -> void:
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	_joy_centro = Vector2(150.0, vp_size.y - 150.0)
	if _touch_idx_joy == -1 and not _arrastrando_mouse_izq:
		_joy_pos_actual = _joy_centro
	if _boton_inspeccionar:
		_boton_inspeccionar.position = Vector2((vp_size.x - 260.0) * 0.5, vp_size.y - 110.0)
	if _overlay_ui:
		_overlay_ui.queue_redraw()

func _dibujar_ui_tactil() -> void:
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var centro: Vector2 = vp_size * 0.5

	# 1. Joystick virtual izquierdo
	_overlay_ui.draw_circle(_joy_centro, _joy_radio_max, Color(0.10, 0.12, 0.15, 0.45))
	_overlay_ui.draw_arc(_joy_centro, _joy_radio_max, 0.0, TAU, 48, Color(0.85, 0.90, 0.95, 0.65), 3.0)
	_overlay_ui.draw_circle(_joy_pos_actual, 36.0, Color(0.90, 0.55, 0.15, 0.85))
	_overlay_ui.draw_arc(_joy_pos_actual, 36.0, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.90), 2.5)

	# 2. Retícula central (Zona focal)
	var hay_foco: bool = (_riesgo_focal != "")
	var color_mira: Color = Color(1.0, 0.35, 0.15, 0.95) if hay_foco else Color(0.90, 0.95, 1.0, 0.75)
	var radio_mira: float = 7.5 if hay_foco else 4.0
	_overlay_ui.draw_circle(centro, radio_mira, color_mira)
	_overlay_ui.draw_arc(centro, 16.0, 0.0, TAU, 24, Color(1.0, 1.0, 1.0, 0.35), 1.5)

	# 3. Indicadores de visión periférica 180° en los bordes laterales de la pantalla
	var color_alerta: Color = Color(1.0, 0.65, 0.10, 0.80)
	if _alerta_periferica_izq:
		_overlay_ui.draw_arc(Vector2(0.0, centro.y), 90.0, deg_to_rad(-65.0), deg_to_rad(65.0), 24, color_alerta, 8.0)
	if _alerta_periferica_der:
		_overlay_ui.draw_arc(Vector2(vp_size.x, centro.y), 90.0, deg_to_rad(115.0), deg_to_rad(245.0), 24, color_alerta, 8.0)

# ==============================================================================
# 3. INPUT MULTI-TOUCH Y MOUSE (LIBERA DEDOS DE FORMA SEGURA)
# ==============================================================================
func _input(event: InputEvent) -> void:
	# Capturar siempre cuando se suelta el dedo o botón para no dejar el joystick pegado
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not touch.pressed:
			if touch.index == _touch_idx_joy:
				_touch_idx_joy = -1
				_resetear_joystick()
			elif touch.index == _touch_idx_cam:
				_touch_idx_cam = -1
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			if _arrastrando_mouse_izq:
				_arrastrando_mouse_izq = false
				_resetear_joystick()
			_arrastrando_mouse_der = false

func _unhandled_input(event: InputEvent) -> void:
	var vp_width: float = get_viewport().get_visible_rect().size.x

	# A. Controles táctiles reales (celular / tablet)
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if touch.position.x < vp_width * 0.45 and _touch_idx_joy == -1:
				_touch_idx_joy = touch.index
				_actualizar_vector_joystick(touch.position)
			elif touch.position.x >= vp_width * 0.45 and _touch_idx_cam == -1:
				_touch_idx_cam = touch.index

	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_idx_joy:
			_actualizar_vector_joystick(drag.position)
		elif drag.index == _touch_idx_cam:
			_aplicar_giro_360(drag.relative)

	# B. Mouse en PC (sin interferir con toques reales)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if mb.position.x < vp_width * 0.45:
				_arrastrando_mouse_izq = true
				_actualizar_vector_joystick(mb.position)
			else:
				_arrastrando_mouse_der = true

	elif event is InputEventMouseMotion and _touch_idx_cam == -1 and _touch_idx_joy == -1:
		var mm := event as InputEventMouseMotion
		if _arrastrando_mouse_izq:
			_actualizar_vector_joystick(mm.position)
		elif _arrastrando_mouse_der:
			_aplicar_giro_360(mm.relative)

func _actualizar_vector_joystick(pos_toque: Vector2) -> void:
	var delta_vec: Vector2 = pos_toque - _joy_centro
	if delta_vec.length() > _joy_radio_max:
		delta_vec = delta_vec.normalized() * _joy_radio_max
	_joy_pos_actual = _joy_centro + delta_vec
	_input_joystick = delta_vec / _joy_radio_max
	_overlay_ui.queue_redraw()

func _resetear_joystick() -> void:
	_joy_pos_actual = _joy_centro
	_input_joystick = Vector2.ZERO
	_overlay_ui.queue_redraw()

# ==============================================================================
# 4. GIRO CORPORAL LIBRE EN 360° (QUIETO O EN MOVIMIENTO)
# ==============================================================================
func _aplicar_giro_360(delta_rel: Vector2) -> void:
	# Rota el cuerpo completo sin límites horizontales
	rotate_y(deg_to_rad(-delta_rel.x * sensibilidad_tactil))

	# Inclinación vertical de la cabeza (arriba/abajo)
	_pitch_camara_deg = clampf(
		_pitch_camara_deg - delta_rel.y * sensibilidad_tactil,
		-limite_vertical_abajo,
		limite_vertical_arriba
	)
	_camara.rotation_degrees.x = _pitch_camara_deg

# ==============================================================================
# 5. MOVIMIENTO DEL PERSONAJE
# ==============================================================================
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravedad * delta

	var input_teclado := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): input_teclado.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): input_teclado.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): input_teclado.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): input_teclado.y += 1.0

	var vector_mov: Vector2 = _input_joystick + input_teclado
	if vector_mov.length() > 1.0:
		vector_mov = vector_mov.normalized()

	var dir_adelante: Vector3 = Vector3(global_transform.basis.z.x, 0.0, global_transform.basis.z.z).normalized()
	var dir_derecha: Vector3 = Vector3(global_transform.basis.x.x, 0.0, global_transform.basis.x.z).normalized()
	var direccion_deseada: Vector3 = (dir_derecha * vector_mov.x + dir_adelante * vector_mov.y).normalized()

	if direccion_deseada.length() > 0.05:
		velocity.x = move_toward(velocity.x, direccion_deseada.x * velocidad_caminar, aceleracion * delta)
		velocity.z = move_toward(velocity.z, direccion_deseada.z * velocidad_caminar, aceleracion * delta)
		_balanceo_tiempo += delta * 9.0
		_camara.position.y = sin(_balanceo_tiempo) * 0.022
	else:
		velocity.x = move_toward(velocity.x, 0.0, friccion * delta)
		velocity.z = move_toward(velocity.z, 0.0, friccion * delta)
		_camara.position.y = move_toward(_camara.position.y, 0.0, delta * 0.2)

	move_and_slide()
	_escanear_vision_180()
	_actualizar_texto_hud()

# ==============================================================================
# 6. PERCEPCIÓN PERIFÉRICA DE 180° (CON BLOQUEO REAL POR MUROS)
# ==============================================================================
func _escanear_vision_180() -> void:
	_riesgo_focal = ""
	_alerta_periferica_izq = false
	_alerta_periferica_der = false
	_cantidad_en_periferia = 0

	if not get_tree() or not get_tree().current_scene:
		return

	var nodo_puntos := get_tree().current_scene.find_child("08_PuntosInspeccionYSpawn", true, false)
	if not nodo_puntos:
		return

	var origen_ojos: Vector3 = _camara.global_position
	var vector_vista_3d: Vector3 = -_camara.global_transform.basis.z
	var frente_xz: Vector3 = Vector3(-global_transform.basis.z.x, 0.0, -global_transform.basis.z.z).normalized()
	var derecha_xz: Vector3 = Vector3(global_transform.basis.x.x, 0.0, global_transform.basis.x.z).normalized()
	# Para 180° completos, cos(90°) = 0.0 (todo el hemisferio frontal)
	var umbral_periferico: float = cos(deg_to_rad(angulo_vision_periferica * 0.5))
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var menor_dist_focal: float = INF

	for child in nodo_puntos.get_children():
		var marker_riesgo := child as Marker3D
		if not marker_riesgo or not marker_riesgo.name.begins_with("Riesgo_"):
			continue

		var hacia_riesgo: Vector3 = marker_riesgo.global_position - origen_ojos
		var dist: float = hacia_riesgo.length()
		if dist > distancia_periferica or absf(hacia_riesgo.y) > 2.2:
			continue

		var dir_xz: Vector3 = Vector3(hacia_riesgo.x, 0.0, hacia_riesgo.z).normalized()
		# Verificar si está dentro del arco frontal de 180°
		if frente_xz.dot(dir_xz) < umbral_periferico:
			continue

		# Verificar que ningún muro bloquee la línea de visión (con tolerancia al mueble que contiene el marker)
		var query := PhysicsRayQueryParameters3D.create(origen_ojos, marker_riesgo.global_position)
		query.exclude = [get_rid()]
		var impacto: Dictionary = space_state.intersect_ray(query)
		if not impacto.is_empty():
			var pos_impacto: Vector3 = impacto["position"] as Vector3
			if pos_impacto.distance_to(marker_riesgo.global_position) > 0.60:
				continue

		_cantidad_en_periferia += 1

		# Zona focal (centro de la pantalla) vs. Zona periférica (bordes izquierdo/derecho)
		var dot_foco: float = vector_vista_3d.dot(hacia_riesgo.normalized())
		if dist <= distancia_inspeccion and dot_foco > 0.94 and dist < menor_dist_focal:
			menor_dist_focal = dist
			_riesgo_focal = marker_riesgo.name
		else:
			if derecha_xz.dot(dir_xz) < 0.0:
				_alerta_periferica_izq = true
			else:
				_alerta_periferica_der = true

	if _boton_inspeccionar:
		_boton_inspeccionar.visible = (_riesgo_focal != "")
		if _riesgo_focal != "":
			_boton_inspeccionar.text = "INSPECCIONAR:\n" + _riesgo_focal.replace("Riesgo_", "").replace("_", " ")
	_overlay_ui.queue_redraw()

func _actualizar_texto_hud() -> void:
	var piso_str: String = "2° Piso" if global_position.y > 1.8 else "1° Piso"
	var rumbo_deg: int = roundi(fposmod(rad_to_deg(-rotation.y), 360.0))
	var texto: String = "%s | Rumbo: %03d° | En visión 180°: %d" % [piso_str, rumbo_deg, _cantidad_en_periferia]
	if _riesgo_focal != "":
		texto += "\n[!] EN MIRA: " + _riesgo_focal
	_label_estado.text = texto

func _on_boton_inspeccionar_pressed() -> void:
	if _riesgo_focal != "":
		print("[El Inspector] Riesgo inspeccionado: ", _riesgo_focal)
		var marker := get_tree().current_scene.find_child(_riesgo_focal, true, false)
		if marker:
			marker.name = "Inspeccionado_" + marker.name
		_riesgo_focal = ""
		_boton_inspeccionar.visible = false
