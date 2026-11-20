"""Arithmetic for the tick 18 handoff (queue item 6). Standard library, reads no file."""

# DeepProve abstract (ePrint 2026/1112) [authors' numbers], tokens per minute
for name, tpm in (("GPT-2", 174), ("Gemma 3", 86), ("GPT-2 distributed", 1855)):
    tps = tpm / 60
    print(f"DeepProve {name}: {tpm} tok/min = {tps:.2f} tok/s; target 50 is x{50 / tps:.1f} away")

# SLP (arXiv 2609.27367) [authors' numbers]
t8, t16 = 94.8, 99.0
print(f"SLP TinyLlama context 8 -> 16: {t8} -> {t16} s, +{(t16 / t8 - 1) * 100:.1f}% for 2x positions")
print(f"SLP 12 packed requests 181.9 s = {181.9 / 12:.1f} s per request; 12 separate at {t8} s = {12 * t8:.0f} s")

# Prefix re-execution for a driver that re-proves every prefix of lengths 1..N (tick of 2026-09-26)
for n in (32, 128, 512):
    print(f"N={n}: prefix-recompute positions {n * (n + 1) // 2}, ratio to one pass {(n + 1) / 2:.1f}x")
