extends Node
## Настройки игрока: язык, чувствительность, громкость. Хранятся в user://settings.cfg.
## Заглушка этапа 0: меню настроек появится на этапе 10, но читать значения можно уже сейчас.

signal changed(section: String, key: String)

const PATH: String = "user://settings.cfg"

const DEFAULTS: Dictionary = {
	"game": {"locale": "ru"},
	"controls": {"mouse_sensitivity": 0.0022, "pad_sensitivity": 2.6, "invert_y": false},
	"audio": {"master": 1.0, "voice": 1.0, "music": 0.7},
	"video": {"retro_filter": false, "fullscreen": false},
	"voice": {"push_to_talk": false, "allow_gul_echo": true},
}

var _cfg := ConfigFile.new()


func _ready() -> void:
	_cfg.load(PATH)  # нет файла — работаем на значениях по умолчанию
	TranslationServer.set_locale(get_value("game", "locale"))


func get_value(section: String, key: String) -> Variant:
	return _cfg.get_value(section, key, DEFAULTS[section][key])


func set_value(section: String, key: String, value: Variant) -> void:
	_cfg.set_value(section, key, value)
	_cfg.save(PATH)
	if section == "game" and key == "locale":
		TranslationServer.set_locale(value)
	changed.emit(section, key)
