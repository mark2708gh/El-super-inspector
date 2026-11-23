@tool
extends Node3D
class_name CasaChilenaGreybox

@export_group("Generador Arquitectura Chilena 2 Pisos")
@export var generar_casa_ahora: bool = false:
	set(value):
		if value:
			generar_estructura_completa()
		generar_casa_ahora = false

@export var mostrar_techo: bool = true:
	set(value):
		mostrar_techo = value
		var techo := get_node_or_null("04_TechoYCubierta") as Node3D
		if techo:
			techo.visible = value

@export var mostrar_mobiliario: bool = true:
	set(value):
		mostrar_mobiliario = value
		var muebles := get_node_or_null("07_MobiliarioBase") as Node3D
		if muebles:
			muebles.visible = value

# Materiales arquitectónicos
var mat_tierra: StandardMaterial3D
var mat_pasto: StandardMaterial3D
var mat_radier: StandardMaterial3D
var mat_piso_madera: StandardMaterial3D
var mat_ceramica: StandardMaterial3D
var mat_albanileria: StandardMaterial3D
var mat_siding: StandardMaterial3D
var mat_volcanita: StandardMaterial3D
var mat_cortafuego: StandardMaterial3D
var mat_techo_zinc: StandardMaterial3D
var mat_madera_marco: StandardMaterial3D
var mat_madera_escalera: StandardMaterial3D
var mat_fierro_negro: StandardMaterial3D
var mat_vidrio: StandardMaterial3D
var mat_mueble_gris: StandardMaterial3D
var mat_artefacto_blanco: StandardMaterial3D
var mat_gas_naranjo: StandardMaterial3D

func _ready() -> void:
	if not Engine.is_editor_hint() and get_child_count() == 0:
		generar_estructura_completa()

func generar_estructura_completa() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	_inicializar_materiales()

	# 1. Losas, pisos y terreno (CSG separado para evitar fallos booleanos)
	var csg_losas := CSGCombiner3D.new()
	csg_losas.name = "01_PisosYLosas"
	csg_losas.use_collision = true
	add_child(csg_losas)
	_construir_pisos_y_losas(csg_losas)

	# 2. Muros Primer Piso (Y = 0.15 a 2.75)
	var csg_muros_1p := CSGCombiner3D.new()
	csg_muros_1p.name = "02_MurosPrimerPiso"
	csg_muros_1p.use_collision = true
	add_child(csg_muros_1p)
	_construir_muros_primer_piso(csg_muros_1p)

	# 3. Muros Segundo Piso (Y = 3.00 a 5.40)
	var csg_muros_2p := CSGCombiner3D.new()
	csg_muros_2p.name = "03_MurosSegundoPiso"
	csg_muros_2p.use_collision = true
	add_child(csg_muros_2p)
	_construir_muros_segundo_piso(csg_muros_2p)

	# 4. Techumbre a dos aguas, aleros y cortafuego
	var csg_techo := CSGCombiner3D.new()
	csg_techo.name = "04_TechoYCubierta"
	csg_techo.use_collision = true
	csg_techo.visible = mostrar_techo
	add_child(csg_techo)
	_construir_techumbre(csg_techo)

	# 5. Escalera con rampa ConvexPolygonShape3D exacta + barandas
	_construir_sistema_escalera()

	# 6. Marcos de puertas, ventanas con vidrio y reja chilena exterior
	_construir_carpinteria_y_exterior()

	# 7. Mobiliario y artefactos base (Cocina, Baños, Camas, Calefont)
	_construir_mobiliario_base()

	# 8. Puntos de Spawn y Riesgos para El Inspector
	_crear_marcadores_juego()

	if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
		_asignar_owner_recursivo(self, get_tree().edited_scene_root)

	print("[CasaChilenaGreybox] Arquitectura 10x9m de dos pisos generada correctamente.")

# ==============================================================================
# 1. TERRENO, RADIER Y LOSA DE ENTREPISO
# ==============================================================================
func _construir_pisos_y_losas(parent: CSGCombiner3D) -> void:
	# Terreno general (14m ancho x 18m fondo)
	_add_box(parent, "TerrenoPasto", Vector3(-1.0, -0.15, -4.5), Vector3(13.0, 0.0, 13.5), CSGShape3D.OPERATION_UNION, mat_pasto)
	# Pastelones de acceso peatonal y entrada de auto
	_add_box(parent, "AccesoPeatonal", Vector3(2.2, -0.02, -4.5), Vector3(3.6, 0.02, 0.0), CSGShape3D.OPERATION_UNION, mat_radier)
	_add_box(parent, "HuellaAuto", Vector3(6.8, -0.02, -4.5), Vector3(9.6, 0.02, 0.0), CSGShape3D.OPERATION_UNION, mat_radier)
	_add_box(parent, "PeldañoEntrada", Vector3(2.1, 0.0, -0.6), Vector3(3.7, 0.15, 0.0), CSGShape3D.OPERATION_UNION, mat_radier)

	# Radier Primer Piso (10.0m x 9.0m, Y = 0.0 a 0.15m)
	_add_box(parent, "RadierCasa1P", Vector3(0.0, 0.0, 0.0), Vector3(10.0, 0.15, 9.0), CSGShape3D.OPERATION_UNION, mat_piso_madera)
	# Piso cerámico en Cocina y Baño 1P (sobrenivel milimétrico para color)
	_add_box(parent, "PisoCeramicoServicios1P", Vector3(6.0, 0.14, 0.2), Vector3(9.8, 0.155, 8.8), CSGShape3D.OPERATION_UNION, mat_ceramica)
	# Radier Loggia y Terraza Trasera
	_add_box(parent, "RadierLoggia", Vector3(10.0, 0.0, 5.4), Vector3(11.6, 0.12, 9.0), CSGShape3D.OPERATION_UNION, mat_radier)
	_add_box(parent, "TerrazaPatio", Vector3(0.5, 0.0, 9.0), Vector3(5.5, 0.10, 10.8), CSGShape3D.OPERATION_UNION, mat_radier)

	# Losa Entrepiso Segundo Piso (Y = 2.75 a 3.00m)
	_add_box(parent, "LosaEntrepiso2P", Vector3(0.0, 2.75, 0.0), Vector3(10.0, 3.00, 9.0), CSGShape3D.OPERATION_UNION, mat_piso_madera)

	# Recorte exacto de la Caja de Escalera en la Losa (X: 8.35 a 9.80, Z: 1.50 a 4.60)
	# Deja libre Z=0.20 a 1.50 como descanso firme de llegada en el 2° piso
	_add_box(parent, "HuecoCajaEscalera", Vector3(8.35, 2.70, 1.50), Vector3(9.80, 3.05, 4.60), CSGShape3D.OPERATION_SUBTRACTION, mat_radier)

# ==============================================================================
# 2. MUROS Y VANOS DEL PRIMER PISO (Y = 0.15 a 2.75m)
# ==============================================================================
func _construir_muros_primer_piso(parent: CSGCombiner3D) -> void:
	var y0 := 0.15
	var y1 := 2.75

	# Perímetro de Albañilería (0.20m espesor)
	_add_box(parent, "MuroCortafuegoOeste_1P", Vector3(0.0, y0, 0.0), Vector3(0.20, y1, 9.0), CSGShape3D.OPERATION_UNION, mat_cortafuego)
	_add_box(parent, "FachadaNorteFrontal_1P", Vector3(0.20, y0, 0.0), Vector3(10.0, y1, 0.20), CSGShape3D.OPERATION_UNION, mat_albanileria)
	_add_box(parent, "FachadaSurPatio_1P", Vector3(0.20, y0, 8.80), Vector3(10.0, y1, 9.0), CSGShape3D.OPERATION_UNION, mat_albanileria)
	_add_box(parent, "FachadaEsteDerecha_1P", Vector3(9.80, y0, 0.20), Vector3(10.0, y1, 8.80), CSGShape3D.OPERATION_UNION, mat_albanileria)

	# Tabiques Interiores Primer Piso (0.12m espesor)
	# Eje central X=6.0: separa Living-Comedor (Oeste) de Baño/Hall/Cocina (Este)
	_add_box(parent, "TabiqueCentral_1P", Vector3(5.94, y0, 0.20), Vector3(6.06, y1, 8.80), CSGShape3D.OPERATION_UNION, mat_volcanita)
	# Tabique Sur de Baño de Visitas (Z=3.0, X=6.06 a 8.35)
	_add_box(parent, "TabiqueSurBanoVisitas", Vector3(6.06, y0, 2.94), Vector3(8.35, y1, 3.06), CSGShape3D.OPERATION_UNION, mat_volcanita)
	# Tabique Lateral de Escalera / Bodega bajo escalera (X=8.35, Z=0.20 a 3.60)
	_add_box(parent, "TabiqueCostadoEscalera_1P", Vector3(8.25, y0, 0.20), Vector3(8.37, y1, 3.60), CSGShape3D.OPERATION_UNION, mat_volcanita)
	# Tabique Norte de Cocina (Z=5.4, X=6.06 a 9.80) - separa Hall Escalera de Cocina
	_add_box(parent, "TabiqueNorteCocina", Vector3(6.06, y0, 5.34), Vector3(9.80, y1, 5.46), CSGShape3D.OPERATION_UNION, mat_volcanita)

	# Loggia Exterior Adosada (X=10.0 a 11.6, Z=5.4 a 9.0)
	_add_box(parent, "LoggiaMuroNorte", Vector3(10.0, 0.12, 5.40), Vector3(11.6, 2.50, 5.52), CSGShape3D.OPERATION_UNION, mat_albanileria)
	_add_box(parent, "LoggiaMuroEste", Vector3(11.48, 0.12, 5.52), Vector3(11.6, 2.50, 8.88), CSGShape3D.OPERATION_UNION, mat_albanileria)
	_add_box(parent, "LoggiaMuroSur", Vector3(10.0, 0.12, 8.88), Vector3(11.6, 2.50, 9.00), CSGShape3D.OPERATION_UNION, mat_albanileria)

	# --- SUSTRACCIÓN DE PUERTAS PRIMER PISO ---
	# P1: Puerta Principal en Fachada Frontal (X=2.4 a 3.4, Z=0.0)
	_add_box(parent, "Vano_P1_AccesoPrincipal", Vector3(2.40, y0, -0.10), Vector3(3.40, y0 + 2.15, 0.30), CSGShape3D.OPERATION_SUBTRACTION, mat_volcanita)
	# Pórtico Living a Hall de Escalera (X=6.0, Z=3.25 a 4.55)
	_add_box(parent, "Vano_PorticoHallEscalera", Vector3(5.80, y0, 3.25), Vector3(6.20, y0 + 2.20, 4.55), CSGShape3D.OPERATION_SUBTRACTION, mat_volcanita)
	# Arco Comedor a Cocina (X=6.0, Z=6.30 a 7.70)
	_add_box(parent, "Vano_ArcoComedorCocina", Vector3(5.80, y0, 6.30), Vector3(6.20, y0 + 2.20, 7.70), CSGShape3D.OPERATION_SUBTRACTION, mat_volcanita)
	# Paso Hall Escalera a Cocina (Z=5.4, X=6.60 a 7.55)
	_add_box(parent, "Vano_PasoHallCocina", Vector3(6.60, y0, 5.20), Vector3(7.55, y0 + 2.15, 5.60), CSGShape3D.OPERATION_SUBTRACTION, mat_volcanita)
	# P2: Puerta Baño de Visitas (Z=3.0, X=6.65 a 7.50)
	_add_box(parent, "Vano_P2_BanoVisitas", Vector3(6.65, y0, 2.80), Vector3(7.50, y0 + 2.10, 3.20), CSGShape3D.OPERATION_SUBTRACTION, mat_volcanita)
	# P3: Puerta Cocina a Loggia (X=10.0, Z=6.00 a 6.90)
	_add_box(parent, "Vano_P3_CocinaLoggia", Vector3(9.70, y0, 6.00), Vector3(10.10, y0 + 2.10, 6.90), CSGShape3D.OPERATION_SUBTRACTION, mat_volcanita)
	# P4: Puerta Loggia a Patio (Z=9.0, X=10.35 a 11.25)
	_add_box(parent, "Vano_P4_LoggiaPatio", Vector3(10.35, 0.12, 8.75), Vector3(11.25, 2.22, 9.15), CSGShape3D.OPERATION_SUBTRACTION, mat_volcanita)

	# --- SUSTRACCIÓN DE VENTANAS PRIMER PISO ---
	# V1: Ventanal Living Frontal (Z=0.0, X=0.60 a 2.00)
	_add_box(parent, "Vano_V1_LivingFrontal", Vector3(0.60, y0 + 0.55, -0.10), Vector3(2.00, y0 + 2.15, 0.30), CSGShape3D.OPERATION_SUBTRACTION, mat_volcanita)
	# V_ComedorLat: Ventanal Comedor al Patio (Z=9.0, X=1.00 a 4.60)
	_add_box(parent, "Vano_V2_VentanalPatio", Vector3(1.00, y0, 8.70), Vector3(4.60, y0 + 2.15, 9.10), CSGShape3D.OPERATION_SUBTRACTION, mat_volcanita)
	# V3: Celosía Baño de Visitas (Z=0.0, X=6.70 a 7.60)
	_add_box(parent, "Vano_V3_BanoVisitas", Vector3(6.70, y0 + 1.55, -0.10), Vector3(7.60, y0 + 2.15, 0.30), CSGShape3D.OPERATION_SUBTRACTION, mat_volcanita)
	# V_Cocina: Ventana sobre lavaplatos (Z=9.0, X=6.80 a 8.80)
	_add_box(parent, "Vano_VCocina_Patio", Vector3(6.80, y0 + 1.05, 8.70), Vector3(8.80, y0 + 2.15, 9.10), CSGShape3D.OPERATION_SUBTRACTION, mat_volcanita)
	# Celosía ventilación Loggia (X=11.5, Z=5.80 a 8.50)
	_add_box(parent, "Vano_CelosiaLoggia", Vector3(11.35, 1.15, 5.80), Vector3(11.75, 2.25, 8.50), CSGShape3D.OPERATION_SUBTRACTION, mat_volcanita)

# ==============================================================================
# 3. MUROS Y VANOS DEL SEGUNDO PISO (Y = 3.00 a 5.40m)
# ==============================================================================
func _construir_muros_segundo_piso(parent: CSGCombiner3D) -> void:
	var y0 := 3.00
	var y1 := 5.40

	# Perímetro Siding Segundo Piso (0.16m espesor)
	_add_box(parent, "MuroCortafuegoOeste_2P", Vector3(0.0, y0, 0.0), Vector3(0.20, y1, 9.0), CSGShape3D.OPERATION_UNION, mat_cortafuego)
	_add_box(parent, "FachadaNorteFrontal_2P", Vector3(0.20, y0, 0.0), Vector3(10.0, y1, 0.16), CSGShape3D.OPERATION_UNION, mat_siding)
	_add_box(parent, "FachadaSurPatio_2P", Vector3(0.20, y0, 8.84), Vector3(10.0, y1, 9.0), CSGShape3D.OPERATION_UNION, mat_siding)
	_add_box(parent, "FachadaEsteDerecha_2P", Vector3(9.84, y0, 0.16), Vector3(10.0, y1, 8.84), CSGShape3D.OPERATION_UNION, mat_siding)

	# --- TABIQUES DEL PASILLO EN "L" Y HABITACIONES (0.12m espesor) ---
	# 1. Muro Oeste del Pasillo Central (X=4.2, de Z=0.16 a 8.84)
	_add_box(parent, "TabiquePasilloOeste_2P", Vector3(4.14, y0, 0.16), Vector3(4.26, y1, 8.84), CSGShape3D.OPERATION_UNION, mat_volcanita)
	# 2. Muro Este del Pasillo Central (X=5.6, de Z=1.50 a 8.84) -> Deja abierto Z=0.16..1.50 para venir de la escalera
	_add_box(parent, "TabiquePasilloEste_2P", Vector3(5.54, y0, 1.50), Vector3(5.66, y1, 8.84), CSGShape3D.OPERATION_UNION, mat_volcanita)
	# 3. División entre Dormitorio 1 (Noroeste) y Dormitorio 2 (Suroeste) en Z=4.5
	_add_box(parent, "TabiqueDivDormsOeste_2P", Vector3(0.20, y0, 4.44), Vector3(4.14, y1, 4.56), CSGShape3D.OPERATION_UNION, mat_volcanita)
	# 4. Muro Norte del Baño Principal (Z=1.50, de X=5.54 a 8.35) -> Separa el pasillo de llegada de la escalera del Baño Ppal
	_add_box(parent, "TabiqueNorteBanoPpal_2P", Vector3(5.54, y0, 1.44), Vector3(8.35, y1, 1.56), CSGShape3D.OPERATION_UNION, mat_volcanita)
	# 5. Muro Este del Baño Principal (X=8.35, de Z=1.50 a 4.60) -> Separa Baño Ppal del hueco de la escalera
	_add_box(parent, "TabiqueBanoEscalera_2P", Vector3(8.23, y0, 1.50), Vector3(8.35, y1, 4.60), CSGShape3D.OPERATION_UNION, mat_volcanita)
	# 6. Muro Norte de Dormitorio 3 (Z=4.60, de X=5.66 a 9.84) -> Cierra el Baño Ppal y el borde sur de la caja de escalera
	_add_box(parent, "TabiqueNorteDorm3_2P", Vector3(5.66, y0, 4.54), Vector3(9.84, y1, 4.66), CSGShape3D.OPERATION_UNION, mat_volcanita)

	# --- SUSTRACCIÓN DE PUERTAS SEGUNDO PISO (Cero superposiciones) ---
	# P5: Dormitorio 1 Matrimonial (en muro X=4.2, Z=2.00 a 2.90)
	_add_box(parent, "Vano_P5_Dorm1", Vector3(4.00, y0, 2.00), Vector3(4.40, y0 + 2.10, 2.90), CSGShape3D.OPERATION_SUBTRACTION, mat_volcanita)
	# P6: Dormitorio 2 Suroeste (en muro X=4.2, Z=5.50 a 6.40)
	_add_box(parent, "Vano_P6_Dorm2", Vector3(4.00, y0, 5.50), Vector3(4.40, y0 + 2.10, 6.40), CSGShape3D.OPERATION_SUBTRACTION, mat_volcanita)
	# P7: Baño Principal (en muro X=5.6, Z=2.60 a 3.45)
	_add_box(parent, "Vano_P7_BanoPpal", Vector3(5.40, y0, 2.60), Vector3(5.80, y0 + 2.10, 3.45), CSGShape3D.OPERATION_SUBTRACTION, mat_volcanita)
	# P8: Dormitorio 3 Sureste (en muro X=5.6, Z=5.50 a 6.40)
	_add_box(parent, "Vano_P8_Dorm3", Vector3(5.40, y0, 5.50), Vector3(5.80, y0 + 2.10, 6.40), CSGShape3D.OPERATION_SUBTRACTION, mat_volcanita)

	# --- SUSTRACCIÓN DE VENTANAS SEGUNDO PISO ---
	# V4: Dormitorio 1 Frontal (Z=0.0, X=1.20 a 3.20)
	_add_box(parent, "Vano_V4_Dorm1", Vector3(1.20, y0 + 0.85, -0.10), Vector3(3.20, y0 + 2.05, 0.30), CSGShape3D.OPERATION_SUBTRACTION, mat_volcanita)
	# V8: Ventana Pasillo Norte (Z=0.0, X=4.45 a 5.35)
	_add_box(parent, "Vano_V8_PasilloNorte", Vector3(4.45, y0 + 0.85, -0.10), Vector3(5.35, y0 + 2.05, 0.30), CSGShape3D.OPERATION_SUBTRACTION, mat_volcanita)
	# V9: Ventana Llegada Escalera (Z=0.0, X=6.80 a 8.80)
	_add_box(parent, "Vano_V9_Desembarco", Vector3(6.80, y0 + 0.85, -0.10), Vector3(8.80, y0 + 2.05, 0.30), CSGShape3D.OPERATION_SUBTRACTION, mat_volcanita)
	# V_EscLat: Ventana Lateral Caja Escalera (X=10.0, Z=2.20 a 3.80)
	_add_box(parent, "Vano_VEscaleraEste", Vector3(9.70, y0 + 0.40, 2.20), Vector3(10.10, y0 + 1.90, 3.80), CSGShape3D.OPERATION_SUBTRACTION, mat_volcanita)
	# V5: Dormitorio 2 Posterior (Z=9.0, X=1.20 a 3.20)
	_add_box(parent, "Vano_V5_Dorm2", Vector3(1.20, y0 + 0.85, 8.70), Vector3(3.20, y0 + 2.05, 9.10), CSGShape3D.OPERATION_SUBTRACTION, mat_volcanita)
	# V10: Ventana Pasillo Sur (Z=9.0, X=4.45 a 5.35)
	_add_box(parent, "Vano_V10_PasilloSur", Vector3(4.45, y0 + 0.85, 8.70), Vector3(5.35, y0 + 2.05, 9.10), CSGShape3D.OPERATION_SUBTRACTION, mat_volcanita)
	# V6: Dormitorio 3 Posterior (Z=9.0, X=6.80 a 8.80)
	_add_box(parent, "Vano_V6_Dorm3", Vector3(6.80, y0 + 0.85, 8.70), Vector3(8.80, y0 + 2.05, 9.10), CSGShape3D.OPERATION_SUBTRACTION, mat_volcanita)

# ==============================================================================
# 4. TECHUMBRE A DOS AGUAS, CORTAFUEGO Y TECHO LOGGIA
# ==============================================================================
func _construir_techumbre(parent: CSGCombiner3D) -> void:
	# Cielo raso 2° Piso (Y = 5.40 a 5.50m)
	_add_box(parent, "CieloRaso2P", Vector3(0.0, 5.40, 0.0), Vector3(10.0, 5.50, 9.0), CSGShape3D.OPERATION_UNION, mat_volcanita)

	# Cubierta principal de Zinc a dos aguas con aleros de 0.45m
	var techo_ppal := CSGPolygon3D.new()
	techo_ppal.name = "CubiertaPrincipalZinc"
	techo_ppal.polygon = PackedVector2Array([
		Vector2(-0.45, 5.45),
		Vector2(4.50, 6.75),
		Vector2(9.45, 5.45)
	])
	techo_ppal.depth = 10.35
	techo_ppal.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	techo_ppal.position = Vector3(0.15, 0.0, 0.0)
	techo_ppal.material = mat_techo_zinc
	parent.add_child(techo_ppal)

	# Muro Cortafuego Superior Normativo (sobresale 0.35m sobre la cumbrera en X=0.0..0.22)
	var cortafuego_cumbrera := CSGPolygon3D.new()
	cortafuego_cumbrera.name = "CortafuegoSuperior"
	cortafuego_cumbrera.polygon = PackedVector2Array([
		Vector2(0.0, 5.40),
		Vector2(0.0, 5.80),
		Vector2(4.50, 7.10),
		Vector2(9.0, 5.80),
		Vector2(9.0, 5.40)
	])
	cortafuego_cumbrera.depth = 0.24
	cortafuego_cumbrera.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	cortafuego_cumbrera.position = Vector3(0.0, 0.0, 0.0)
	cortafuego_cumbrera.material = mat_cortafuego
	parent.add_child(cortafuego_cumbrera)

	# Techo inclinado de la Loggia (X=10.0 a 11.75, Z=5.3 a 9.1)
	var techo_loggia := CSGBox3D.new()
	techo_loggia.name = "TechoLoggia"
	techo_loggia.size = Vector3(1.85, 0.10, 3.80)
	techo_loggia.position = Vector3(10.85, 2.58, 7.20)
	techo_loggia.rotation_degrees = Vector3(0.0, 0.0, -8.0)
	techo_loggia.material = mat_techo_zinc
	parent.add_child(techo_loggia)

	# Cobertizo Porche Entrada Principal
	_add_box(parent, "TechoPorcheEntrada", Vector3(1.80, 2.55, -1.10), Vector3(4.00, 2.68, 0.05), CSGShape3D.OPERATION_UNION, mat_madera_marco)
	_add_box(parent, "PilarPorcheIzq", Vector3(1.90, 0.0, -1.00), Vector3(2.02, 2.55, -0.88), CSGShape3D.OPERATION_UNION, mat_madera_marco)
	_add_box(parent, "PilarPorcheDer", Vector3(3.78, 0.0, -1.00), Vector3(3.90, 2.55, -0.88), CSGShape3D.OPERATION_UNION, mat_madera_marco)

# ==============================================================================
# 5. ESCALERA (Sube de Z=4.50 [Y=0.15] hacia Z=1.50 [Y=3.00] en X=8.37..9.80)
# ==============================================================================
func _construir_sistema_escalera() -> void:
	var raiz_esc := Node3D.new()
	raiz_esc.name = "05_SistemaEscalera"
	add_child(raiz_esc)

	var csg_peldanos := CSGCombiner3D.new()
	csg_peldanos.name = "PeldanosYBarandaVisual"
	csg_peldanos.use_collision = false
	raiz_esc.add_child(csg_peldanos)

	var num_peldanos := 16
	var z_sur_abajo := 4.50
	var z_norte_arriba := 1.50
	var y_abajo := 0.15
	var y_arriba := 3.00
	var huella := (z_sur_abajo - z_norte_arriba) / float(num_peldanos) # 0.1875m
	var contrahuella := (y_arriba - y_abajo) / float(num_peldanos)     # 0.1781m

	for i in range(num_peldanos):
		var z_frente := z_sur_abajo - (i * huella)
		var z_fondo := z_frente - huella
		var y_top := y_abajo + ((i + 1) * contrahuella)
		var y_base := y_abajo + (i * contrahuella) - 0.04
		# Peldaño de madera sólida con nariz
		_add_box(csg_peldanos, "Peldano_%02d" % (i + 1), Vector3(8.38, y_base, z_fondo - 0.02), Vector3(9.78, y_top, z_frente), CSGShape3D.OPERATION_UNION, mat_madera_escalera)

	# Rampa física exacta mediante ConvexPolygonShape3D (imposible que quede invertida)
	var body_rampa := StaticBody3D.new()
	body_rampa.name = "ColisionRampaExacta"
	raiz_esc.add_child(body_rampa)

	var col_shape := CollisionShape3D.new()
	col_shape.name = "ConvexRampShape"
	var convex := ConvexPolygonShape3D.new()
	convex.points = PackedVector3Array([
		Vector3(8.38, y_abajo, z_sur_abajo),
		Vector3(9.78, y_abajo, z_sur_abajo),
		Vector3(8.38, y_abajo - 0.10, z_sur_abajo),
		Vector3(9.78, y_abajo - 0.10, z_sur_abajo),
		Vector3(8.38, y_arriba, z_norte_arriba),
		Vector3(9.78, y_arriba, z_norte_arriba),
		Vector3(8.38, y_arriba - 0.12, z_norte_arriba),
		Vector3(9.78, y_arriba - 0.12, z_norte_arriba)
	])
	col_shape.shape = convex
	body_rampa.add_child(col_shape)

# ==============================================================================
# 6. CARPINTERÍA (MARCOS, VIDRIOS) Y REJA CHILENA DE ANTEJARDÍN
# ==============================================================================
func _construir_carpinteria_y_exterior() -> void:
	var nodo_ext := Node3D.new()
	nodo_ext.name = "06_CarpinteriaYExterior"
	add_child(nodo_ext)

	var csg_decor := CSGCombiner3D.new()
	csg_decor.name = "MarcosYVidriosSinColision"
	csg_decor.use_collision = false
	nodo_ext.add_child(csg_decor)

	# Cristales translúcidos y alféizares en ventanas exteriores
	# Fachada Frontal (Z = 0.08)
	_crear_ventana_con_marco(csg_decor, "Ventana_V1_Living", Vector3(0.60, 0.70, 0.05), Vector3(2.00, 2.30, 0.15))
	_crear_ventana_con_marco(csg_decor, "Ventana_V3_Bano1P", Vector3(6.70, 1.70, 0.05), Vector3(7.60, 2.30, 0.15))
	_crear_ventana_con_marco(csg_decor, "Ventana_V4_Dorm1", Vector3(1.20, 3.85, 0.04), Vector3(3.20, 5.05, 0.12))
	_crear_ventana_con_marco(csg_decor, "Ventana_V8_Pasillo", Vector3(4.45, 3.85, 0.04), Vector3(5.35, 5.05, 0.12))
	_crear_ventana_con_marco(csg_decor, "Ventana_V9_Escalera", Vector3(6.80, 3.85, 0.04), Vector3(8.80, 5.05, 0.12))

	# Fachada Posterior (Z = 8.88)
	_crear_ventana_con_marco(csg_decor, "Ventana_VCocina", Vector3(6.80, 1.20, 8.85), Vector3(8.80, 2.30, 8.95))
	_crear_ventana_con_marco(csg_decor, "Ventana_V5_Dorm2", Vector3(1.20, 3.85, 8.86), Vector3(3.20, 5.05, 8.96))
	_crear_ventana_con_marco(csg_decor, "Ventana_V10_PasilloSur", Vector3(4.45, 3.85, 8.86), Vector3(5.35, 5.05, 8.96))
	_crear_ventana_con_marco(csg_decor, "Ventana_V6_Dorm3", Vector3(6.80, 3.85, 8.86), Vector3(8.80, 5.05, 8.96))

	# Reja Chilena de Antejardín y Panderetas con colisión real
	var csg_cierros := CSGCombiner3D.new()
	csg_cierros.name = "RejaYPanderetasColision"
	csg_cierros.use_collision = true
	nodo_ext.add_child(csg_cierros)

	# Panderetas perimetrales del sitio
	_add_box(csg_cierros, "PanderetaOeste", Vector3(-0.20, 0.0, -4.0), Vector3(0.0, 2.10, 13.0), CSGShape3D.OPERATION_UNION, mat_radier)
	_add_box(csg_cierros, "PanderetaEste", Vector3(12.0, 0.0, -4.0), Vector3(12.20, 2.10, 13.0), CSGShape3D.OPERATION_UNION, mat_radier)
	_add_box(csg_cierros, "PanderetaFondoPatio", Vector3(-0.20, 0.0, 12.80), Vector3(12.20, 2.10, 13.0), CSGShape3D.OPERATION_UNION, mat_radier)

	# Reja Frontal en Z = -4.0 (deja abierto el acceso peatonal en X = 2.2 a 3.6)
	_add_box(csg_cierros, "ZocaloRejaIzq", Vector3(0.0, 0.0, -4.05), Vector3(2.20, 0.45, -3.90), CSGShape3D.OPERATION_UNION, mat_cortafuego)
	_add_box(csg_cierros, "ZocaloRejaDer", Vector3(3.60, 0.0, -4.05), Vector3(12.0, 0.45, -3.90), CSGShape3D.OPERATION_UNION, mat_cortafuego)
	_add_box(csg_cierros, "PilarReja1", Vector3(2.05, 0.0, -4.10), Vector3(2.25, 1.90, -3.85), CSGShape3D.OPERATION_UNION, mat_cortafuego)
	_add_box(csg_cierros, "PilarReja2", Vector3(3.55, 0.0, -4.10), Vector3(3.75, 1.90, -3.85), CSGShape3D.OPERATION_UNION, mat_cortafuego)
	_add_box(csg_cierros, "PilarReja3", Vector3(6.65, 0.0, -4.10), Vector3(6.85, 1.90, -3.85), CSGShape3D.OPERATION_UNION, mat_cortafuego)
	_add_box(csg_cierros, "BarrotesSuperioresIzq", Vector3(0.0, 0.45, -4.00), Vector3(2.05, 1.80, -3.95), CSGShape3D.OPERATION_UNION, mat_fierro_negro)
	_add_box(csg_cierros, "BarrotesSuperioresDer", Vector3(3.75, 0.45, -4.00), Vector3(12.0, 1.80, -3.95), CSGShape3D.OPERATION_UNION, mat_fierro_negro)

# ==============================================================================
# 7. MOBILIARIO Y ARTEFACTOS BASE (Da escala humana a cada habitación)
# ==============================================================================
func _construir_mobiliario_base() -> void:
	var csg_muebles := CSGCombiner3D.new()
	csg_muebles.name = "07_MobiliarioBase"
	csg_muebles.use_collision = true
	csg_muebles.visible = mostrar_mobiliario
	add_child(csg_muebles)

	var y1 := 0.15
	var y2 := 3.00

	# --- LIVING - COMEDOR (1° Piso) ---
	_add_box(csg_muebles, "SofaPrincipal", Vector3(0.40, y1, 1.40), Vector3(1.30, y1 + 0.80, 3.80), CSGShape3D.OPERATION_UNION, mat_mueble_gris)
	_add_box(csg_muebles, "MesaCentroLiving", Vector3(1.80, y1, 2.00), Vector3(2.60, y1 + 0.45, 3.20), CSGShape3D.OPERATION_UNION, mat_madera_marco)
	_add_box(csg_muebles, "EstufaChilena", Vector3(5.20, y1, 1.80), Vector3(5.80, y1 + 0.90, 2.40), CSGShape3D.OPERATION_UNION, mat_fierro_negro)
	_add_box(csg_muebles, "MesaComedor", Vector3(2.00, y1, 5.80), Vector3(3.80, y1 + 0.78, 7.60), CSGShape3D.OPERATION_UNION, mat_madera_escalera)

	# --- COCINA Y LOGGIA (1° Piso) ---
	_add_box(csg_muebles, "MesonCocinaSur", Vector3(6.20, y1, 8.15), Vector3(9.75, y1 + 0.90, 8.78), CSGShape3D.OPERATION_UNION, mat_mueble_gris)
	_add_box(csg_muebles, "Cocina4Platos", Vector3(9.10, y1, 7.10), Vector3(9.75, y1 + 0.92, 7.90), CSGShape3D.OPERATION_UNION, mat_artefacto_blanco)
	_add_box(csg_muebles, "Refrigerador", Vector3(8.95, y1, 5.55), Vector3(9.75, y1 + 1.80, 6.25), CSGShape3D.OPERATION_UNION, mat_artefacto_blanco)
	_add_box(csg_muebles, "TableroElectricoTDA", Vector3(8.18, y1 + 1.35, 3.15), Vector3(8.26, y1 + 1.85, 3.55), CSGShape3D.OPERATION_UNION, mat_artefacto_blanco)
	_add_box(csg_muebles, "CalefontLoggia", Vector3(10.02, 1.35, 7.30), Vector3(10.25, 2.05, 7.75), CSGShape3D.OPERATION_UNION, mat_artefacto_blanco)
	_add_box(csg_muebles, "BalonGas15Kg", Vector3(10.15, 0.12, 8.10), Vector3(10.55, 0.85, 8.50), CSGShape3D.OPERATION_UNION, mat_gas_naranjo)

	# --- BAÑO VISITAS (1° Piso) Y BAÑO PRINCIPAL (2° Piso) ---
	_add_box(csg_muebles, "Lavamanos1P", Vector3(6.15, y1, 1.20), Vector3(6.65, y1 + 0.85, 1.80), CSGShape3D.OPERATION_UNION, mat_artefacto_blanco)
	_add_box(csg_muebles, "WC_1P", Vector3(7.50, y1, 0.30), Vector3(8.05, y1 + 0.75, 0.95), CSGShape3D.OPERATION_UNION, mat_artefacto_blanco)
	_add_box(csg_muebles, "TinaBano2P", Vector3(7.50, y2, 1.60), Vector3(8.20, y2 + 0.55, 3.20), CSGShape3D.OPERATION_UNION, mat_artefacto_blanco)
	_add_box(csg_muebles, "Lavamanos2P", Vector3(6.20, y2, 1.60), Vector3(7.10, y2 + 0.85, 2.15), CSGShape3D.OPERATION_UNION, mat_artefacto_blanco)
	_add_box(csg_muebles, "WC_2P", Vector3(7.40, y2, 3.70), Vector3(8.05, y2 + 0.75, 4.35), CSGShape3D.OPERATION_UNION, mat_artefacto_blanco)

	# --- CAMAS SEGUNDO PISO ---
	_add_box(csg_muebles, "CamaMatrimonial_Dorm1", Vector3(0.30, y2, 1.30), Vector3(2.30, y2 + 0.60, 2.90), CSGShape3D.OPERATION_UNION, mat_artefacto_blanco)
	_add_box(csg_muebles, "Cama_Dorm2", Vector3(0.30, y2, 6.20), Vector3(2.20, y2 + 0.60, 7.40), CSGShape3D.OPERATION_UNION, mat_artefacto_blanco)
	_add_box(csg_muebles, "Cama_Dorm3", Vector3(7.70, y2, 6.20), Vector3(9.70, y2 + 0.60, 7.40), CSGShape3D.OPERATION_UNION, mat_artefacto_blanco)
	_add_box(csg_muebles, "Escritorio_Dorm3", Vector3(6.20, y2, 8.15), Vector3(7.60, y2 + 0.75, 8.75), CSGShape3D.OPERATION_UNION, mat_madera_marco)

# ==============================================================================
# 8. MARCADORES DE SPAWN Y RIESGOS DOMÉSTICOS ("EL INSPECTOR")
# ==============================================================================
func _crear_marcadores_juego() -> void:
	var contenedor := Node3D.new()
	contenedor.name = "08_PuntosInspeccionYSpawn"
	add_child(contenedor)

	var puntos := {
		"SpawnJugador_Antejardin": Vector3(2.90, 0.20, -2.50),
		"Riesgo_1P_Living_EstufaEncendida": Vector3(5.50, 0.85, 2.10),
		"Riesgo_1P_Hall_TableroElectricoAbierto": Vector3(8.10, 1.60, 3.35),
		"Riesgo_1P_BanoVisitas_FugaFlexible": Vector3(6.40, 0.55, 1.50),
		"Riesgo_1P_Cocina_QuemadorSinSupervision": Vector3(9.40, 1.15, 7.50),
		"Riesgo_1P_Loggia_CalefontSinDucto": Vector3(10.15, 1.75, 7.50),
		"Riesgo_1P_Loggia_MangueraGasVencida": Vector3(10.35, 0.65, 8.30),
		"Riesgo_2P_Escalera_ObjetoEnPeldano": Vector3(9.10, 1.65, 2.95),
		"Riesgo_2P_Dorm1_AlargadorSobrecargado": Vector3(1.30, 3.25, 0.50),
		"Riesgo_2P_BanoPpal_SecadorJuntoATina": Vector3(7.40, 3.70, 2.20),
		"Riesgo_2P_Dorm2_CortinaSobreCalefactor": Vector3(2.20, 3.60, 8.60),
		"Riesgo_2P_Dorm3_BateriaLitioEnCama": Vector3(8.70, 3.70, 6.80)
	}

	for nombre in puntos.keys():
		var marker := Marker3D.new()
		marker.name = nombre
		marker.position = puntos[nombre]
		marker.gizmo_extents = 0.40
		contenedor.add_child(marker)

# ==============================================================================
# UTILIDADES INTERNAS Y MATERIALES
# ==============================================================================
func _crear_ventana_con_marco(parent: CSGCombiner3D, win_name: String, min_pt: Vector3, max_pt: Vector3) -> void:
	# Cristal semitransparente
	_add_box(parent, win_name + "_Vidrio", min_pt, max_pt, CSGShape3D.OPERATION_UNION, mat_vidrio)
	# Alféizar inferior de madera
	var sill_min := Vector3(min_pt.x - 0.05, min_pt.y - 0.06, min_pt.z - 0.06)
	var sill_max := Vector3(max_pt.x + 0.05, min_pt.y + 0.02, max_pt.z + 0.06)
	_add_box(parent, win_name + "_Alfeizar", sill_min, sill_max, CSGShape3D.OPERATION_UNION, mat_madera_marco)

func _add_box(parent: Node3D, box_name: String, min_pt: Vector3, max_pt: Vector3, op: CSGShape3D.Operation, mat: Material) -> CSGBox3D:
	var box := CSGBox3D.new()
	box.name = box_name
	box.size = (max_pt - min_pt).abs()
	box.position = (min_pt + max_pt) * 0.5
	box.operation = op
	box.material = mat
	parent.add_child(box)
	return box

func _inicializar_materiales() -> void:
	mat_tierra = _crear_mat(Color(0.38, 0.32, 0.25))
	mat_pasto = _crear_mat(Color(0.24, 0.42, 0.22))
	mat_radier = _crear_mat(Color(0.52, 0.53, 0.55))
	mat_piso_madera = _crear_mat(Color(0.62, 0.45, 0.28), 0.55)
	mat_ceramica = _crear_mat(Color(0.78, 0.80, 0.82), 0.35)
	mat_albanileria = _crear_mat(Color(0.90, 0.82, 0.68))
	mat_siding = _crear_mat(Color(0.62, 0.70, 0.78))
	mat_volcanita = _crear_mat(Color(0.94, 0.94, 0.92))
	mat_cortafuego = _crear_mat(Color(0.64, 0.30, 0.22))
	mat_techo_zinc = _crear_mat(Color(0.26, 0.29, 0.32), 0.45)
	mat_madera_marco = _crear_mat(Color(0.36, 0.22, 0.12))
	mat_madera_escalera = _crear_mat(Color(0.55, 0.36, 0.20), 0.50)
	mat_fierro_negro = _crear_mat(Color(0.15, 0.16, 0.18), 0.40)
	mat_mueble_gris = _crear_mat(Color(0.32, 0.35, 0.40))
	mat_artefacto_blanco = _crear_mat(Color(0.96, 0.97, 0.98), 0.25)
	mat_gas_naranjo = _crear_mat(Color(0.88, 0.42, 0.12), 0.40)

	mat_vidrio = StandardMaterial3D.new()
	mat_vidrio.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_vidrio.albedo_color = Color(0.55, 0.78, 0.92, 0.28)
	mat_vidrio.roughness = 0.10

func _crear_mat(color: Color, rough: float = 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m

func _asignar_owner_recursivo(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		_asignar_owner_recursivo(child, root)
