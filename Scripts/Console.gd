extends Node
signal new_line(text: String)

func log(msg: String) -> void:
	Console.emit_signal("new_line", msg)
