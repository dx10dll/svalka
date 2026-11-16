#!/usr/bin/env python3
"""Синтез звуков игры: удары по материалам, шаги, падения, бросок.

Все звуки собираются из затухающих синусов (моды «звона») и шума, поэтому
ничего чужого в репозитории нет и любой звук можно перегенерировать.
Запуск: python3 tools/gen_sounds.py   (нужен numpy)
Результат: assets/audio/sfx/*.wav, 22050 Гц, моно, 16 бит.
"""

from __future__ import annotations

import wave
from pathlib import Path

import numpy as np

RATE = 22050
OUT = Path(__file__).resolve().parents[1] / "assets" / "audio" / "sfx"


def _t(seconds: float) -> np.ndarray:
    return np.arange(int(RATE * seconds)) / RATE


def modes(seconds: float, partials: list[tuple[float, float, float]], rng: np.random.Generator,
          detune: float = 0.02) -> np.ndarray:
    """Сумма затухающих синусов. partials: (частота Гц, громкость, время затухания с)."""
    t = _t(seconds)
    out = np.zeros_like(t)
    for freq, amp, decay in partials:
        f = freq * (1.0 + rng.uniform(-detune, detune))
        out += amp * np.sin(2 * np.pi * f * t + rng.uniform(0, 6.28)) * np.exp(-t / decay)
    return out


def noise(seconds: float, decay: float, rng: np.random.Generator, low: float = 0.0, high: float = 1.0) -> np.ndarray:
    """Шумовой щелчок с затуханием. low/high — границы полосы в долях от половины частоты записи."""
    n = int(RATE * seconds)
    spec = np.fft.rfft(rng.standard_normal(n))
    k = np.linspace(0.0, 1.0, spec.size)
    spec *= (k >= low) & (k <= high)
    return np.fft.irfft(spec, n) * np.exp(-_t(seconds) / decay)


def finish(x: np.ndarray, attack: float = 0.002, peak: float = 0.89) -> np.ndarray:
    a = max(int(RATE * attack), 1)
    x = x.copy()
    x[:a] *= np.linspace(0.0, 1.0, a)
    tail = min(int(RATE * 0.02), x.size)
    x[-tail:] *= np.linspace(1.0, 0.0, tail)
    return x / max(np.abs(x).max(), 1e-9) * peak


def save(name: str, x: np.ndarray) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())


def pad(a: np.ndarray, n: int) -> np.ndarray:
    return np.pad(a, (0, max(n - a.size, 0)))[:n] if a.size != n else a


def mix(*parts: np.ndarray) -> np.ndarray:
    n = max(p.size for p in parts)
    return sum(pad(p, n) for p in parts)


def build() -> None:
    for i in range(3):
        rng = np.random.default_rng(100 + i)
        k = 1.0 + 0.07 * (i - 1)
        # чугун: глухой тяжёлый удар с коротким низким звоном
        save(f"metal_heavy_{i + 1}", finish(mix(
            modes(0.7, [(96 * k, 1.0, 0.16), (212 * k, 0.7, 0.2), (447 * k, 0.5, 0.14), (890 * k, 0.3, 0.1),
                        (1630 * k, 0.18, 0.07)], rng),
            0.9 * noise(0.12, 0.018, rng, 0.0, 0.25))))
        # пустой железный ящик (холодильник, стиралка): гулкий «бум» с дребезгом
        save(f"metal_hollow_{i + 1}", finish(mix(
            modes(0.9, [(68 * k, 1.0, 0.22), (131 * k, 0.8, 0.3), (203 * k, 0.5, 0.26), (377 * k, 0.4, 0.2),
                        (742 * k, 0.25, 0.12), (1210 * k, 0.15, 0.09)], rng, 0.05),
            0.7 * noise(0.25, 0.05, rng, 0.02, 0.35))))
        # латунь, мелкий цветмет: звонкий удар
        save(f"metal_ring_{i + 1}", finish(mix(
            modes(1.1, [(523 * k, 0.6, 0.35), (1244 * k, 1.0, 0.5), (2093 * k, 0.6, 0.4), (3310 * k, 0.4, 0.25),
                        (4870 * k, 0.25, 0.15)], rng),
            0.6 * noise(0.05, 0.008, rng, 0.2, 0.9))))
        # пластиковый корпус телевизора
        save(f"plastic_{i + 1}", finish(mix(
            modes(0.35, [(152 * k, 1.0, 0.06), (318 * k, 0.6, 0.05), (640 * k, 0.3, 0.035)], rng, 0.06),
            0.8 * noise(0.1, 0.02, rng, 0.03, 0.4))))
        # дерево: ящики
        save(f"wood_{i + 1}", finish(mix(
            modes(0.3, [(187 * k, 1.0, 0.05), (410 * k, 0.7, 0.04), (905 * k, 0.35, 0.025)], rng, 0.05),
            0.6 * noise(0.06, 0.012, rng, 0.05, 0.5))))
    for i in range(2):
        rng = np.random.default_rng(200 + i)
        # мягкое: бухта кабеля, мешки
        save(f"soft_{i + 1}", finish(mix(
            modes(0.25, [(72 + 9 * i, 1.0, 0.05), (140 + 14 * i, 0.4, 0.04)], rng),
            0.9 * noise(0.2, 0.04, rng, 0.0, 0.18)), attack=0.006))
        # звон стекла: кинескоп
        t = _t(1.3)
        shards = np.zeros_like(t)
        for _ in range(26):
            start = int(rng.uniform(0.0, 0.5) ** 1.6 * RATE)
            f = rng.uniform(2200, 7800)
            seg = modes(0.25, [(f, rng.uniform(0.2, 1.0), rng.uniform(0.02, 0.09))], rng)
            end = min(start + seg.size, shards.size)
            shards[start:end] += seg[: end - start]
        save(f"glass_break_{i + 1}", finish(mix(
            shards, 2.2 * noise(0.5, 0.07, rng, 0.25, 1.0), 1.5 * modes(0.3, [(130, 1.0, 0.05)], rng))))
        # тело шлёпнулось на землю
        save(f"body_fall_{i + 1}", finish(mix(
            modes(0.4, [(58 + 6 * i, 1.0, 0.08), (97 + 8 * i, 0.5, 0.06)], rng),
            0.8 * noise(0.3, 0.05, rng, 0.0, 0.14)), attack=0.004))
    for i in range(4):
        rng = np.random.default_rng(300 + i)
        # шаг по сухой земле с мусором: хруст и глухой толчок
        crunch = noise(0.16, 0.035, rng, 0.08, 0.6) * (0.6 + 0.4 * np.sin(2 * np.pi * rng.uniform(30, 55) * _t(0.16)))
        save(f"step_dirt_{i + 1}", finish(mix(
            0.8 * crunch, modes(0.14, [(84 + 7 * i, 0.9, 0.03)], rng)), attack=0.004, peak=0.7))
    rng = np.random.default_rng(400)
    save("land_1", finish(mix(
        modes(0.3, [(64, 1.0, 0.06), (118, 0.4, 0.05)], rng), 0.7 * noise(0.22, 0.045, rng, 0.02, 0.35)), attack=0.003))
    # взмах при броске: шум, полоса которого «проезжает» вверх и обратно
    t = _t(0.32)
    env = np.sin(np.pi * t / 0.32) ** 2
    sweep = noise(0.32, 10.0, rng, 0.03, 0.22) * env
    save("whoosh_1", finish(sweep, attack=0.03, peak=0.6))
    save("grab_1", finish(mix(noise(0.07, 0.014, rng, 0.05, 0.4), 0.5 * modes(0.08, [(210, 1.0, 0.02)], rng)),
                          attack=0.004, peak=0.5))
    # куча предупреждает: скрип «залипает и срывается», высота плывёт
    for i in range(2):
        rng = np.random.default_rng(500 + i)
        t = _t(1.0)
        freq = 150 + 60 * i + 90 * np.sin(2 * np.pi * (0.7 + 0.3 * i) * t) + 40 * rng.standard_normal(t.size).cumsum() / 60
        phase = 2 * np.pi * np.cumsum(freq) / RATE
        saw = 2 * ((phase / (2 * np.pi)) % 1.0) - 1
        slip = (np.sin(2 * np.pi * (9 + 3 * i) * t + 3 * np.sin(2 * np.pi * 1.3 * t)) > -0.2).astype(float)
        env = np.sin(np.pi * t / 1.0) ** 0.6
        save(f"creak_{i + 1}", finish(mix(saw * slip * env, 0.5 * noise(1.0, 0.5, rng, 0.02, 0.2) * env),
                                      attack=0.02, peak=0.6))
    # завал: долгий низкий грохот с россыпью ударов
    for i in range(2):
        rng = np.random.default_rng(600 + i)
        t = _t(2.2)
        body = noise(2.2, 0.7, rng, 0.0, 0.08) * (1 - np.exp(-t / 0.05))
        hits = np.zeros_like(t)
        for _ in range(14):
            start = int(rng.uniform(0.0, 1.2) * RATE)
            seg = modes(0.3, [(rng.uniform(60, 220), 1.0, rng.uniform(0.04, 0.1))], rng) \
                + 0.6 * noise(0.3, 0.03, rng, 0.0, 0.3)
            end = min(start + seg.size, hits.size)
            hits[start:end] += seg[: end - start] * rng.uniform(0.3, 1.0)
        save(f"rumble_{i + 1}", finish(mix(2.0 * body, hits), attack=0.01))
    # костёр: ровный шум пламени с редкими щелчками, зацикленный без шва
    rng = np.random.default_rng(700)
    n = int(RATE * 3.0)
    spec = np.fft.rfft(rng.standard_normal(n))
    k = np.linspace(0.0, 1.0, spec.size)
    spec *= 1.0 / (1.0 + (k * 40.0) ** 1.2)          # розоватый шум: у БПФ-шума стык цикла бесшовный
    base = np.fft.irfft(spec, n)
    base /= np.abs(base).max()
    t = np.arange(n) / RATE
    base *= 0.55 + 0.25 * np.sin(2 * np.pi * t / 3.0 * 2) + 0.2 * np.sin(2 * np.pi * t / 3.0 * 5 + 1.0)
    for _ in range(22):
        start = int(rng.uniform(0.05, 2.8) * RATE)
        seg = noise(0.03, 0.004, rng, 0.15, 0.9) * rng.uniform(0.4, 1.0)
        base[start:start + seg.size] += seg[: n - start]
    loops = OUT.parent / "loops"
    loops.mkdir(parents=True, exist_ok=True)
    with wave.open(str(loops / "fire_loop.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((np.clip(base / np.abs(base).max() * 0.7, -1, 1) * 32767).astype("<i2").tobytes())
    # мотор: вспышки четырёх цилиндров на холостых, целое число периодов — цикл без шва
    rng = np.random.default_rng(800)
    n = RATE
    t = np.arange(n) / RATE
    eng = np.zeros(n)
    for harm, amp in ((1, 1.0), (2, 0.7), (3, 0.45), (4, 0.5), (6, 0.25), (8, 0.2), (12, 0.1)):
        eng += amp * np.sin(2 * np.pi * 26 * harm * t + rng.uniform(0, 6.28))
    eng *= 1.0 + 0.35 * np.sin(2 * np.pi * 13 * t)             # неровная работа
    spec = np.fft.rfft(rng.standard_normal(n))
    kk = np.linspace(0.0, 1.0, spec.size)
    spec *= (kk > 0.02) & (kk < 0.25)
    rattle = np.fft.irfft(spec, n)
    eng = eng / np.abs(eng).max() + 0.35 * rattle / np.abs(rattle).max() * (0.6 + 0.4 * np.sin(2 * np.pi * 26 * t))
    with wave.open(str(loops / "engine_loop.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((np.clip(eng / np.abs(eng).max() * 0.75, -1, 1) * 32767).astype("<i2").tobytes())
    print("Звуков:", len(list(OUT.glob("*.wav"))))


if __name__ == "__main__":
    build()
