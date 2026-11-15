#!/bin/sh
# Серия снимков из игры без монитора (облако): xvfb + программный Vulkan.
# Использование: tools/shots.sh ПАПКА [сценарий]   (GODOT — путь к Godot со сборкой под X11)
set -e
out="${1:?нужна папка для снимков}"
mkdir -p "$out"
only="${2:+--only=$2}"
xvfb-run -a -s "-screen 0 1280x720x24" "${GODOT:-godot}" --path "$(dirname "$0")/.." \
  --rendering-driver vulkan --resolution 1280x720 --fixed-fps 60 \
  res://tests/visual/shots.tscn -- "--out=$out" $only
