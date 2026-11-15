class_name PlayerInput
extends RefCounted
## Ввод игрока за один физический тик. Контроллер не читает клавиатуру сам,
## он получает эту структуру: так же потом придёт ввод по сети или от теста.

## Движение: x — вправо, y — вперёд, длина не больше 1
var move: Vector2 = Vector2.ZERO
var jump_pressed: bool = false
var jump_held: bool = false
var crouch_held: bool = false
var sprint_held: bool = false
## Нарочно упасть рэгдоллом (клавиша Q)
var flop_pressed: bool = false
