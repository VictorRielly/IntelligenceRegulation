# MULTIMODAL DESIGN lane — progress (2026-10-21 UTC)

Brief: paper design and costing of Shieldstral's image path (Pixtral ViT +
projector), image binding, video sampling, audio, cost table and build plan
(D37-D39). No prover code, no git writes, no heavy runs. Deliverable:
`DESIGN.md` in this directory.

## Log

- 02:49 UTC started. Read CLAUDE.md, START_HERE, native ledger R8-R11,
  r10/WEIGHT_RANGE_COST.md, r11/ACTIVATION_COST.md, the classifier survey
  (REPORT.md §3, F10), D37-D39.
- 02:5x UTC VERIFIED from Hugging Face (repo sha 003ec7e2..., last modified
  2026-08-05): config.json, params.json, processor_config.json,
  chat_template.jinja, README.md (copies kept in this session's scratchpad
  only, not in the repo); transformers main `modeling_pixtral.py`,
  `modeling_mistral3.py`, `image_processing_pixtral.py`,
  `processing_pixtral.py`. Findings that correct or sharpen the brief:
  * the 2x2 merge is NOT only a reshape: `Mistral3PatchMerger` is an unfold
    followed by a learned `merging_layer` Linear(4096 -> 1024, no bias); the
    projector is RMSNorm -> unfold -> Linear 4096->1024 -> Linear 1024->3072
    -> GELU (exact erf, `projector_hidden_act: gelu`) -> Linear 3072->3072,
    all bias-free;
  * Pixtral also has `ln_pre` (RMSNorm after the patch conv, before layer 0)
    and no final norm (the projector's norm plays that role);
  * the processor resizes to multiples of 28 px (patch 14 x merge 2), bicubic,
    CLIP mean/std, longest edge 1540;
  * decoder image tokens = rows x (cols + 1): [IMG] per merged patch, one
    [IMG_BREAK] per row, the last replaced by [IMG_END]; 448^2 -> 272;
  * the model card's image prompt is a [text, image, text] sandwich: the
    whole public Instruct/Query/"<Document>: " prefix comes BEFORE the image,
    so public-prefix KV reuse (F6) still applies to images;
  * vision attention is MHA (16 KV heads), scale 1/8 (head_dim 64), 2D RoPE
    in HF rotate_half layout: 16 pairs rotated by row x theta_even, 16 by
    column x theta_odd.
- 02:55-03:10 UTC counting script `mm_cost.py` (pure Python, ~1 s, no guard
  needed). It imports the native R10 replica (re-runs its anchor against the
  R8/R9 prove.log sizes) and the speed plan's layout / cost law / platform
  factors, restates both in one class `Lay` (any geometry, DD with receipt,
  F6 rectangular scores [MODEL], batch axis [MODEL]) and asserts: Lay == speed
  plan replica on the counted ladder; Lay == R10 replica DD off/on (8B T512 DD
  525,172,736); DD receipt delta +235,008 B; R9 receipts 23,049,192 /
  29,300,856 B; cost law == speed plan's block_phases. All checks pass.
  Outputs `mm_cost.out`, `mm_cost.json`. (`sys.dont_write_bytecode` set after a
  first run left `__pycache__` in the speed-plan directory; removed.)
- Key findings [COUNTED unless noted]:
  * Pixtral block (d 1024, MHA 16x64, FFN 4096): 224 px (T256) 75.4 M
    committed with DD / 91.0 M without, 4.2 / 5.0 GiB; 448 px (T1024) 452.8 /
    741.9 M, 22.9 / 37.1 GiB; 896 px 4.4 / 9.2 G (219 / 455 GiB). Score domain
    16 T^2 dominates; DD saves 17% / 39%.
  * Shieldstral decoder block == Llama-3-8B block at equal T (3072 -> 4096,
    9216 -> 16384 padding): 117.9 / 272.7 / 663.3 M at T128 / 256 / 512. A
    64-token text post (156 -> 256) needs 14 GiB without F6, 7.2 GiB with F6.
    Split-width bound -18..-26% [MODEL]. Flag for the token lane.
  * Cost [MODEL, speed-plan law]: image 224 px + DD + F6 ~10 min laptop
    (7.2 GiB), ~4.4 min 5090 today, ~28 s after the GPU port; 448 px no laptop
    (33 GiB), ~17 min 5090 today; 896 px infeasible. Video 30 s at 0.2 fps
    (224 px): ~53 min laptop, 8.8 GB receipts; at 1 fps 4.4 h, 44 GB.
  * Binding: recommend the run's hiding input endpoint (salted by its masks and
    leaf salts) with its opening shipped with the post (owner check extended to
    viewers); needs a D23 reading; salted fingerprint (L2) as fallback.
  * Whisper-tiny encoder ~1.27 G committed per layer (1500 -> 2048 frames,
    heads 6 -> 8) [MODEL]; POC: captions as text, audio not assessed.
- 03:10 UTC `DESIGN.md` written (sections 0-9: model facts, relations, binding,
  video, audio, cost table, build plan with review items, rulings, method).
  Not a soundness or privacy acceptance.
