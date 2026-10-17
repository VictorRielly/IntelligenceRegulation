| run | round | mode | blocks | total wall (s) | digest pass (s) | witness (s) [per block] | block loads in proving pass (s) | proofs only (s) [per block] | in-proc verify (s) | fresh verify (s) [crypto only] | receipt (B) | peak RSS (GiB) | peak VRAM (MiB) | positions/s total | positions/s proofs |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Llama-3-8B T32 | r4 | CPU | 32 | 384.5 | 83.012 | 18.629 [0.582] | 79.222 | 110.2 [3.44] | 93.356 | 96.103 [13.3] | 465,815,776 | 1.9 | - | 0.083 | 0.29 |
| Llama-3-8B T32 | r5 | CPU | 32 | 267.8 | 25.455 | 30.453 [0.952] | 24.15 | 187.3 [5.85] | off | 45.777 [22.0] | 465,815,776 | 2.04 | - | 0.119 | 0.171 |
| Llama-3-8B T32 | r5-cli3 | CPU | 32 | 171.6 | 15.294 | 21.376 [0.668] | 15.993 | 118.8 [3.71] | off | 26.491 [13.4] | 465,815,776 | 2.04 | - | 0.186 | 0.269 |
| Llama-3-8B T32 | r4 | GPU | 32 | 391.3 | 79.49 | 18.109 [0.566] | 77.997 | 117.7 [3.68] | 92.741 | 90.935 [13.2] | 465,815,776 | 1.57 | 2369 | 0.082 | 0.272 |
| TinyLlama T32 | r3 | CPU | 22 | 56.2 | 9.703 | 2.683 [0.122] | 0.0 | 40.2 [1.83] | 3.015 | 3.152 [3.2] | 250,855,088 | 2.15 | - | 0.569 | 0.797 |
| TinyLlama T32 | r5 | CPU | 22 | 87.6 | 3.192 | 5.293 [0.241] | 3.38 | 75.5 [3.43] | off | 10.134 [7.1] | 250,855,088 | 1.41 | - | 0.365 | 0.424 |
| TinyLlama T128 | r3 | CPU | 22 | 168.6 | 9.714 | 12.831 [0.583] | 0.0 | 136.2 [6.19] | 9.042 | 11.1 [11.1] | 497,665,904 | 4.82 | - | 0.759 | 0.94 |
| TinyLlama T128 | r5 | CPU | 22 | 189.6 | 2.036 | 16.712 [0.76] | 1.963 | 168.6 [7.66] | off | 13.328 [11.0] | 497,665,904 | 3.63 | - | 0.675 | 0.759 |
| TinyLlama T128 | r3 | GPU | 22 | 142.8 | 9.393 | 12.872 [0.585] | 0.0 | 107.1 [4.87] | 8.742 | 8.451 [8.5] | 497,665,904 | 3.03 | 3105 | 0.896 | 1.195 |

Llama-3-8B T32 r4 CPU controls 11 declines 0 id 259dad7cb2c9739e
Llama-3-8B T32 r5 CPU controls 11 declines 0 id 259dad7cb2c9739e
Llama-3-8B T32 r5-cli3 CPU controls 11 declines 0 id 259dad7cb2c9739e
Llama-3-8B T32 r4 GPU controls None declines 0 id 259dad7cb2c9739e
TinyLlama T32 r3 CPU controls 11 declines 0 id 9b71dfb0a2b4608d
TinyLlama T32 r5 CPU controls 11 declines 0 id 9b71dfb0a2b4608d
TinyLlama T128 r3 CPU controls 11 declines 0 id 53a5667decccbe4d
TinyLlama T128 r5 CPU controls 11 declines 0 id 53a5667decccbe4d
TinyLlama T128 r3 GPU controls None declines 0 id 53a5667decccbe4d
('Llama-3-8B T32', 'CPU') r4 vs r5 identity equal: True | segment lengths equal: True | receipt bytes equal: True
('Llama-3-8B T32', 'CPU') r4 vs r5-cli3 identity equal: True | segment lengths equal: True | receipt bytes equal: True
('TinyLlama T32', 'CPU') r3 vs r5 identity equal: True | segment lengths equal: True | receipt bytes equal: True
('TinyLlama T128', 'CPU') r3 vs r5 identity equal: True | segment lengths equal: True | receipt bytes equal: True
