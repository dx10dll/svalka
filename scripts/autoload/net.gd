extends Node
## Сеть. Заглушка этапа 0: одиночная игра, мы всегда хост.
## Игровой код уже сейчас спрашивает Net.is_host() перед тем, как менять мир,
## чтобы на этапе 7 транспорт (ENet, потом Steam) лёг сверху без переписывания.

signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)

const LOCAL_PEER: int = 1

## Искусственная задержка для тестов (мс), задаётся из отладочного меню
var simulated_ping_ms: int = 0


func is_host() -> bool:
	return true


func local_peer() -> int:
	return LOCAL_PEER


func peers() -> PackedInt32Array:
	return PackedInt32Array([LOCAL_PEER])
