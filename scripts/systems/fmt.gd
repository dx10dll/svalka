class_name Fmt
extends RefCounted
## Форматирование чисел для интерфейса.


## 1200 -> "1 200 ₽" (разряды через неразрывный пробел).
static func rub(amount: int) -> String:
	var digits: String = str(absi(amount))
	var out: String = ""
	for i: int in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += " "
		out += digits[i]
	return ("−" if amount < 0 else "") + out + " ₽"


## 24.6 -> "25 кг", 4.2 -> "4,2 кг"
static func kg(mass: float) -> String:
	var unit: String = TranslationServer.translate("UNIT_KG")
	if mass >= 10.0:
		return "%d %s" % [roundi(mass), unit]
	return ("%.1f %s" % [mass, unit]).replace(".", ",")
