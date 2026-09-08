# CL18 compact pad/scale A/B — Mistral one layer, P3, two threads [MEASURED, WSL-BOX, RTX 4070, single box, not a p95]

| arm | rep | commit W s | commit A s | commit H s | three commits s | re-enc W s | re-enc A s | re-enc H s | three re-encodes s | dev ntt s | PROVE s | proof_ready s | VRAM peak MB | proof |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| compact | 1 | 0.3278 | 0.1153 | 0.0962 | 0.5393 | 0.2361 | 0.0781 | 0.0661 | 0.3803 | 0.5390 | 4.1257 | 13.3014 | 5148 | `190e85a1..` / 40251860 B |
| compact | 2 | 0.3259 | 0.1138 | 0.0967 | 0.5364 | 0.2447 | 0.0783 | 0.0663 | 0.3893 | 0.5360 | 4.0517 | 12.7778 | 5148 | `190e85a1..` / 40251860 B |
| reference | 1 | 0.3871 | 0.1324 | 0.1097 | 0.6292 | 0.2891 | 0.0960 | 0.0809 | 0.4660 | 0.6290 | 4.3630 | 13.5495 | 5182 | `190e85a1..` / 40251860 B |
| reference | 2 | 0.3786 | 0.1303 | 0.1113 | 0.6202 | 0.2925 | 0.0916 | 0.0811 | 0.4652 | 0.6200 | 4.3295 | 12.9595 | 5182 | `190e85a1..` / 40251860 B |

byte-identical across arms: **True** (190e85a1d3be../40251860)

| quantity | reference | compact | change |
|---|---:|---:|---:|
| three chunked ZK commits (W/A/H) s | 0.6247 | 0.5378 | 1.162x |
| three chunked ZK re-encodes (W/A/H) s | 0.4656 | 0.3848 | 1.21x |
| changed phase total s | 1.0903 | 0.9226 | |
| PROVE s (HASHLINE_TIMING prove_s) | 4.3463 | 4.0887 | -0.2576 s |
| proof_ready_s | 13.2545 | 13.0396 | -0.2149 s |

Means over the reps per arm. The changed phase and the whole proof are reported separately; the traffic reduction remains a hypothesis until measured with a profiler; two-thread laptop diagnostic seconds, not a p95.
