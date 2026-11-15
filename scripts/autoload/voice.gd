extends Node
## Голос по близости. Заглушка этапа 0, настоящая работа — этап 8.

signal loudness_changed(peer_id: int, loudness: float)


## Громкость речи игрока 0..1 (двигает челюсть). Пока всегда тишина.
func loudness(_peer_id: int) -> float:
	return 0.0
