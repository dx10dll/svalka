extends Node
## Сохранение забега и постоянной прогрессии. Заглушка этапа 0: пишет и читает
## словарь в JSON, настоящая схема появится на этапе 5.

const PATH: String = "user://save.json"


func write(data: Dictionary) -> bool:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_error("Не удалось записать сохранение: %s" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(JSON.stringify(data, "\t"))
	return true


func read() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		return parsed
	return {}
