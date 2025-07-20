extends Node
var db := SQLite.new()

func _ready():
	# 1) Asigna la ruta y abre la DB
	db.path = "user://TestDB.db"
	if not db.open_db():
		Console.log("ERROR abriendo la DB")
		return
	Console.log("¡DB abierta correctamente!")

	# 2) Crea tabla e inserta fila
	db.query("CREATE TABLE IF NOT EXISTS prueba(id INTEGER PRIMARY KEY, valor TEXT);")
	db.query("INSERT INTO prueba(valor) VALUES('hola');")

	# 3) Ejecuta el SELECT y luego toma el resultado de query_result
	db.query("SELECT * FROM prueba;")
	var filas = db.query_result

	# 4) Muestra el array de filas en la consola in-game
	Console.log("Filas: %s" % str(filas))
