# Shieldstral calibration-prep lane — PROGRESS ledger

Lane: CLASSIFIER CALIBRATION PREP (brief from the coordinating session, 2026-10-21 UTC).
Write set: this directory, `~/models/shieldstral-1.0-3b/`, `~/datasets/`, `~/shieldstral-prep/`.
No git writes, no prover changes, no GPU. Heavy jobs via `scripts/zk60_resource_guard.py`.

## Pins
- Model: `mistralai/Shieldstral-1.0-3B` revision `003ec7e2b0bab5f0e6307edbaf186fa5822b76f5`
  (HF lastModified 2026-08-05T10:06:52Z), Apache 2.0, ungated.
- Canonical local snapshot: `~/models/shieldstral-1.0-3b/snapshot-003ec7e2/` (weights fetched there by
  `tools/pdownload.py`, sha256-verified against the HF LFS hashes). Small files live one level up in
  `~/models/shieldstral-1.0-3b/` (and are copied into the snapshot dir).
- NOTE: a first sequential `curl` (launched 02:33 UTC) is also writing `~/models/shieldstral-1.0-3b/model.safetensors`
  and then `consolidated.safetensors` at ~1 MB/s. It was detached by setsid; its `.done` marker was bogus (quoting
  error) and was deleted. Its files are redundant copies; do not use them unless their sha256 matches WEIGHTS.sha256.
- ToxicChat: `lmsys/toxic-chat` dataset revision `29df8e4dba60e1f4af4b4075c0705c5b313548a8`, file
  `data/0124/toxic-chat_annotation_test.csv` -> `~/datasets/toxicchat-29df8e4d/` (CC-BY-NC-4.0).
- OpenAI Moderation: `openai/moderation-api-release` commit `f4ab51b5edd3bfbcb349a56324274235b674e0e4`,
  `data/samples-1680.jsonl.gz` -> `~/datasets/openai-moderation-f4ab51b5/` (MIT).
- Python extras: `~/shieldstral-prep/pylib` (pip --target --no-deps): transformers 5.13.1, tokenizers 0.22.2,
  huggingface_hub 1.33.0, safetensors 0.8.0, mistral_common 1.11.7 (+ small deps). System torch 2.4.1, numpy 1.26.4.
  Scripts run with `python3 -I` and add `~/.local/lib/python3.10/site-packages` explicitly.

## Steps (UTC from `date -u`)
- 02:30 read CLAUDE.md, lane rules (+2026-10-19 addendum), survey REPORT.md, D38.
- 02:32 HF API: revision + file list + LFS sha256 recorded (scratchpad copy; final in WEIGHTS.sha256).
- 02:33 small repo files downloaded (config, params, chat template, tokenizer, tekken, README).
- 02:38 parallel downloader launched (detached): `logs/pdownload.log`, marker `logs/pdownload.done`.
- 02:41 cookbook page saved (`~/datasets/web_refs/cookbook_shieldstral.html`): 11 worked examples with published
  scores (usable as an external check); multi-policy example = the general single-query policy.
- 02:44 paper (arXiv 2607.25857 HTML) read: ToxicChat 2,853 samples, OpenAI Mod 1,680; no eval prompts given.
- 02:47 datasets downloaded + sha256. ToxicChat test 5,083 rows; human_annotation==True subset = 2,853 rows,
  362 toxic (= the paper's count). OpenAI Mod: 1,680 rows, unsafe = any category label ==1 -> 522.

- 02:51 model.safetensors downloaded + sha256 OK (87753e30...). consolidated.safetensors downloading (~3 MiB/s).
- 02:52 pylib installed (transformers 5.13.1 has Ministral3; imports fine against torch 2.4.1).
- 02:55 tools/: shieldstral_common.py (templates, tokenization split, pread safetensors reader),
  shieldstral_ref.py (numpy fp32 reference, layer-streamed, lazy per-matrix loading), hf_check.py,
  make_prompts.py, ref_check.py, compare.py, check_template.py, bench_run.py, pdownload.py.
- 02:58 unit checks: my YaRN inv_freq (f64) vs HF Ministral3RotaryEmbedding (f32): max rel 1.4e-7; HF
  attention_scaling 1.0; 21 dims original / 16 ramp / 27 interpolated (/16); native interleaved RoPE ==
  HF-permuted rotate-half (scores agree to fp32 rounding).
- 03:00 template 'card': prefix 87 tokens, suffix 1 ([/INST]); 0 mistral_common mismatches and 0 split
  mismatches over all 4,533 benchmark items. ('cookbook' template check still running.)
- 03:00 numpy ref on 13 cross-check prompts (74 s, peak RSS 0.46 GiB): crosscheck/ref_hf_yarn.{npz,json}.
  Cookbook published scores: 5/11 match closely (threats 0.7978 vs 0.798 ...), 6/11 deviate (ref more extreme).
- 03:02 HF transformers 5.13.1 layer-streamed (eager, fp32) on 5 prompts (71 s, peak RSS 1.58 GiB > declared
  1.35; within cap 2.2): crosscheck/hf_transformers.npz. compare: max |dlogit| 7.6e-6 over full vocab,
  max |dmargin| 5.7e-6, argmax/top-20 identical -> crosscheck/compare_ref_vs_hf.json.
- 03:02 MistralCommonBackend (the cookbook's tokenizer path) gives identical ids for all 13 prompts;
  weights unchanged since the 2026-08-04 public squash (HF tree API). Cookbook gap is not tokens/weights.
- 03:03 queued RoPE sensitivity runs (plain / yarn_notrunc / yarn_mscale) -> logs/rope_*.log, marker
  logs/rope_variants.done.

- 03:04 subset queue launched (detached): tools/bench_queue.sh queue_subsets 1.0 6
  toxicchat:card:200 openai_mod:card:200 toxicchat:cookbook:200 openai_mod:cookbook:200
  -> bench/<set>_<template>.jsonl, logs/bench_*.log, markers logs/bench_*_200.done, logs/queue_subsets.done.
- 03:08 RoPE sensitivity (13 prompts, vs correct run): no-YaRN max|dlogit| 0.060; YaRN without floor/ceil
  0.0012; mscale 1.277 wrongly applied 1.51 (borderline verdict flips). Prefix-KV reuse vs full: 7.6e-6.
  -> crosscheck/compare_ref_vs_*.json.
- 03:09 template_check.json complete: 'cookbook' prefix 95 / suffix 1, 0 mismatches. Content tokens
  ToxicChat-human: median 14, mean 45.9, p95 236, max 1219; OpenAI Mod: median 90, mean 160, p95 504, max 1811.
- 03:10 HF Mistral3ForConditionalGeneration (meta): lm_head.weight IS language_model.embed_tokens.weight.
- 03:12 bench throughput 19.8 tail tok/s [shared box, 6 threads]. Queued HF bf16 run on all 13 prompts
  (logs/hfcheck_bf16.*) to measure bf16-vs-fp32 margin noise (Mistral's numbers are bf16).

- 03:14 ToxicChat-200 (card) done: P 0.634 R 0.929 F1 0.754 (CI 0.62-0.86); D38 rule == cookbook rule on all 200.
- 03:15 consolidated.safetensors sha256 OK. record_pins.py: all 12 files match HF (LFS sha256 / git blob id)
  -> WEIGHTS.sha256, pins.json, model_files/ (config, params, chat template, tokenizer_config, ...).
- 03:15 stray sequential curl had died at 02:56 (HTTP/2 CANCEL); its 2.2 GB partial top-level
  model.safetensors deleted. No stray processes.
- 03:16 consolidated (native layout, interleaved RoPE) vs HF layout, 13 prompts: max|dlogit| 5.7e-6.
- 03:17 HF bf16 CPU run far too slow (267 s/prompt; would exceed max-secs before saving): stopped via
  SIGTERM to its guard (exit 75 recorded, peak RSS 1.7 GiB). Replaced by numpy bf16 emulation
  (RefBF16; bf() rounding == torch bf16 bit-exact) -> queued logs/refcheck_bf16emul.*.

- 03:2x bf16-emul 13 prompts: max|dmargin| vs fp32 0.13 (crosscheck/compare_fp32_vs_bf16emul.json); reproduces
  cookbook borderline 0.531 exactly; the 6 deviating cookbook examples stay deviating (not bf16, not our forward).
- 03:32 COORDINATOR MEMORY HOLD: HOLD file created; no new guarded jobs. Acked via SendMessage(main).
- 03:3x coordinator scope update: three category queries (sexual / graphic violence / hate-harassment), per-category
  F1 + margins + token counts. Export-interface notes: model.safetensors sha256 matches; embed_tokens raw-byte sha256
  67a138c1...2093dd19 (matches coordinator; identical in consolidated tok_embeddings).
- 03:3x transformers 4.48.1 YaRN is WRONG for this config: ignores original_max_position_embeddings (uses
  max_position_embeddings 262144 -> 34/14/16 dims) and mscale/mscale_all_dim (attention factor 1.277). Matches 5.13.1
  bitwise only with max_position_embeddings=16384 AND rope_scaling.attention_factor=1.0. -> crosscheck/rope_tables_check.json,
  crosscheck/rope_tables_reference.npz, inv_freq_*.npy. YaRN-vs-unscaled entries changed: exact 66.7%; int8(x127) 24% (T128)
  / 29% (T256) / 40% (T1024).
- 03:3x length_stats.json: share <=40/104/168/424 content tokens: ToxicChat-human 76.8/87.6/92.6/99.5%; OpenAI 19.9/56.5/73.5/91.5%.
- 03:3x category templates added (shieldstral_common.TEMPLATES cat_sexual/cat_violence/cat_hate): prefix 73/73/79 + suffix 1.
- 03:36 RELEASE received. OpenAI-200 card done: P 0.630 R 0.974 F1 0.765. bf16-emul TC200: 0 flips, |dm| p95 0.13 max 0.19.
- 03:41 old queue_subsets stopped (SIGTERM while idle in HOLD loop; cookbook general subsets never launched).
- 03:42 launched (detached): rope hf448 variant (logs/rope_hf448.*), then tools/bench_queue2.sh queue_categories 1.1 6
  toxicchat:cat_{hate,sexual,violence}:200, openai_mod:cat_{sexual,violence,hate}:0:168:300 (stratified: all 312 unsafe
  <=168 tok + 300 safe, safe weight 3.073), toxicchat:cookbook:200 last. Marker logs/queue_categories.done.

- 03:44 rope hf448 (transformers 4.48.1 tables as built from the shipped config): max|dmargin| 1.33, borderline flips.
  Warned coordinator via SendMessage(main).
- 04:07 ToxicChat-200 category runs done (8 min each). vs toxicity label (proxy): sexual flag 13.0% P .769 R .714 F1 .741;
  violence flag 2.5% F1 .121; hate flag 2.0% F1 .188; union P .688 R .786 F1 .733. |m|<1: 2/2/4 of 200; median |m| 9.0/11.5/9.7.
- 04:07 OpenAI stratified category runs started (sexual -> violence -> hate), then toxicchat cookbook 200.

- 04:37 OpenAI sexual (stratified <=168, n=612, 76 pos) done: missing0 P .597 R .974 F1 .740 (CI .64-.84);
  known-only F1 .811; |m|<0.5: 7 (1.2% weighted), <1: 14 (2.3%).
- 04:38 SECOND COORDINATOR MEMORY HOLD (2-3 h; prover build is critical path). HOLD file created 04:38:24. The violence
  chunk c1 was admitted 04:38:02 and runs to its 26-min time box (~05:04); queue then waits on HOLD. Acked.

- 05:04 violence chunk c1 hit time box: 538/612 done (exit 3). Interim OpenAI violence: P .556 R .807 F1 .659.
  Queue now blocked on HOLD; no guarded job of this lane live. Interim category write-up sent to coordinator.

- 05:1x coordinator: after release run hate (strict), then a MODERATE variant of all three (same Queries, Instruct
  "You are a safety moderator. Apply a moderate tolerance threshold."; templates mod_*: prefix 72/72/78 + 1, T128 room
  55/55/49) on OpenAI-strat and TC200; then final report. queue_categories stopped while idle (SIGTERM; its watcher
  task stopped); the general cookbook TC200 job is dropped. analyze_categories.py now reports strict vs moderate.

## Next
- after "release": rm HOLD; launch bench_queue2.sh queue_final 1.1 6 openai_mod:cat_violence:0:168:300
  openai_mod:cat_hate:0:168:300 toxicchat:mod_hate:200:0:0 toxicchat:mod_sexual:200:0:0 toxicchat:mod_violence:200:0:0
  openai_mod:mod_sexual:0:168:300 openai_mod:mod_violence:0:168:300 openai_mod:mod_hate:0:168:300  (~2.6 h)
- analyze_categories.py; final report text (subagent cannot write REPORT.md: report goes in the handback).
- prefix-cache exactness check; benchmarks 200+200 (card), then cookbook template subset; full sets queued
  in <=28-min guarded chunks (bench_run exits 3 on the time box; queue relaunches; HOLD file honoured).
- margins, length distribution, REPORT.md.
