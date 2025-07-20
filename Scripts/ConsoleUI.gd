extends CanvasLayer

@onready var log_text: TextEdit = $PanelContainer/LogText

func _ready():
	# Conecta la señal del singleton Console
	Console.connect("new_line", Callable(self, "_on_new_line"))

func _on_new_line(text: String) -> void:
	# 1) Añade la línea al final
	log_text.text += text + "\n"

	# 2) Scrollea a la última línea
	log_text.scroll_vertical = log_text.get_line_count()
