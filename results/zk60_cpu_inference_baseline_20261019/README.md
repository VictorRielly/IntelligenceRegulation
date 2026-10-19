# Plain CPU inference vs private proof, 8B, laptop CPU (2026-10-19)

Measured 11:05 UTC through the resource guard (light class, 5.77 GiB peak; one
1.5 GiB single-threaded gate job live beside it), Intel Core Ultra 9 185H.
Inference: Ollama's llama.cpp backend, `deepseek-r1:8b` (Llama-3.1-8B
architecture, 8.0 B parameters, Q4_K_M 4-bit weights), CPU only
(`CUDA_VISIBLE_DEVICES=-1`, `num_gpu=0`), raw prompts, one untimed warm-up,
four DISTINCT prompts per length (attempt 2 showed Ollama reuses its KV cache
on repeated or shared-prefix prompts; attempts 1-2 kept in subfolders).
`measure.py`, `result.json`, `run.guard.json`.

| | 32 tokens | 128 tokens |
|---|---:|---:|
| plain inference, tuned CPU engine, 4-bit (prefill, median of 4) [MEASURED] | ~1.3 s (23.9 tok/s; 27-30-token prompts at 1.13-1.23 s) | ~5.4 s (23.6 tok/s; 103-104-token prompts at 4.34-4.42 s) |
| our exact int8 integer forward pass (the prover's witness, 16 threads) [MEASURED, R5 cli3] | 21.4 s | — |
| private proof, 32 blocks, quiet box [MEASURED, R5b] | 156.2 s | 432.5 s |
| private next-token proof (embedding + 32 blocks + head), shared box [MEASURED, R3] | 191.7 s | — |
| proof ÷ tuned inference [COUNTED] | ~117x (blocks), ~143x (next token) | ~80x |
| proof ÷ our own integer forward pass [COUNTED] | ~7x | — |

Caveats: the engine runs 4-bit weights in floating point; the proof covers an
exact int8 integer model (an int8 engine would be somewhat slower than 4-bit
on CPU [MODEL]); our witness builder is not an optimised GEMM library (a
research microbench measured 4.8-7.7x for tiled int8 GEMMs). One run per
cell; shared box unless labelled quiet.

## 8-bit baseline (Victor's request, measured 11:37 UTC)

`llama3:8b-text-q8_0` (Meta Llama-3-8B base, Q8_0 8-bit weights — the closer
match to the proved int8 model), same script and settings (`measure.py
llama3:8b-text-q8_0 result_q8.json`, `run_q8.guard.json`; peak 9.13 GiB; one
6 GiB single-threaded gate pass queued beside it, not yet running):

| | 32 tokens | 128 tokens |
|---|---:|---:|
| plain inference, 8-bit, CPU (median of 4 distinct prompts) [MEASURED] | ~1.55 s (20.6 tok/s; 27-30-token prompts 1.28-1.46 s) | ~5.6 s (22.8 tok/s; 103-104-token prompts 4.47-4.60 s) |
| private proof, 32 blocks, quiet [MEASURED] | 156.2 s | 432.5 s |
| proof ÷ 8-bit inference [COUNTED] | ~100x (~124x for the next-token proof) | ~77x |

Prefill on this CPU is compute-bound, so 8-bit runs within ~15% of 4-bit.
The proof still covers a stricter model than either engine (int8 activations
and integer softmax/norms, where both engines compute those in floating point).
