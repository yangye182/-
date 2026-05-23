## 双色能量系统：体力（红）+ 精神力（蓝）
## 红：每回合回满，回合结束清零
## 蓝：每回合固定获得，可跨回合累积，有上限
class_name DualEnergy
extends RefCounted

signal energy_changed

var max_red: int = 3
var max_blue: int = 4
var blue_gain_per_turn: int = 1

var current_red: int = 0
var current_blue: int = 0


func reset_for_battle(red: int, blue_max: int, blue_gain: int) -> void:
	max_red = red
	max_blue = blue_max
	blue_gain_per_turn = blue_gain
	current_red = max_red
	current_blue = 0
	energy_changed.emit()


## 新玩家回合开始：红回满，蓝获得固定增量（不超过上限）
func on_player_turn_start() -> void:
	current_red = max_red
	current_blue = mini(current_blue + blue_gain_per_turn, max_blue)
	energy_changed.emit()


## 回合结束：红清零，蓝保留
func on_player_turn_end() -> void:
	current_red = 0
	energy_changed.emit()


func can_pay(red: int, blue: int) -> bool:
	return current_red >= red and current_blue >= blue


func pay(red: int, blue: int) -> bool:
	if not can_pay(red, blue):
		return false
	current_red -= red
	current_blue -= blue
	energy_changed.emit()
	return true


func add_blue(amount: int) -> void:
	current_blue = mini(current_blue + amount, max_blue)
	energy_changed.emit()


func drain_blue(amount: int) -> void:
	current_blue = maxi(current_blue - amount, 0)
	energy_changed.emit()


## 本回合内获得额外红能量（可超出 max_red）
func add_red(amount: int) -> void:
	current_red += amount
	energy_changed.emit()
