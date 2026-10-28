# Classifier design (D38) — adversarial check, ledger

Lane: ADVERSARIAL CHECKER of `../DESIGN_CLASSIFIER.md` (+ `../f6_count.py` /
`../f6_count.json`). Paper plus small one-thread Python; no git writes; nothing
heavy. Exclusive write set: this directory (`classifier/check/`). Deliverable:
`CHECK.md` here.

## Log (UTC from `date -u`)

- 2026-10-21T02:43:07Z — check dir created; lane rules re-read.
- 2026-10-21T02:52:56Z — read DESIGN_CLASSIFIER.md, f6_count.py/.json, D20-D39 rows,
  survey REPORT/token_counts (71+41+1 = 113 vs 112 total: a boundary merge),
  prep lane's shieldstral_common.py. Wrote and ran `tok_probe.py` (python3 -I -B,
  reads ~/models/shieldstral-1.0-3b tokenizer files, imports ~/shieldstral-prep/pylib
  read-only) -> `tok_probe.json`: design-literal prefix (text through '<Document>: ')
  stable for only 9/24 contents (fails for content starting with a letter, the common
  case: last prefix token is a lone 'Ġ' that merges); split prefix-to-':' +
  tokenize(' '+content) + suffix equals mistral_common ids 20/24; the 4 misses are
  control strings in content ([/INST], [INST], <s>, </s>, [SYSTEM_PROMPT]) which the HF
  tokenizer turns into CONTROL ids (1,2,3,4,17,18) and mistral_common encodes as text.
  Suffix [/INST] stable 24/24. yes id 13059, no id 2649 (HF single tokens).
- 2026-10-21T02:55:32Z — wrote and ran `check_f6.py` (-B, layout replica read-only) ->
  `check_f6.json`: margin arithmetic holds (|w_D| 2^19.99 — design typo 2^20.99; B_D
  2^38.56; window 40, L 5; identity < 2^40.7, no wrap); tn 10 at width 3072 gives a
  32-bit window for Ceps < 2^40 (33 at exactly 2^40, refused by the derived-window door);
  F6 S-adjusted gains 2.0x / 4.1x / 2.1x / 1.9-2.0x vs the design's lower-bound
  2.1 / 4.9 / 2.3 / 2.4; f6_count.py's width formula gives 2^13 at T_pad 32, not the
  2^12 its comment states (counts move ~5%). Writing CHECK.md next.
- 2026-10-21T02:57:59Z — tok_probe extended: the split with tekken's plain-text encoding
  of ' ' + content equals mistral_common for 24/24 (HF encoding 20/24). `CHECK.md`
  written: verdict BUILDABLE WITH FIXES; core (margin identity, b binding, template
  clause) holds; binding fixes B-1 template boundary (prefix to ':', P0 84), B-2 tekken
  plain-text tokenizer + in-circuit control-id exclusion, B-3 verifier re-derives w_D /
  ids / c, B-4 app refusal rule, B-5 ruling on public n (D38(c)), B-6 fixed policy list,
  B-7 one-endpoint note + D34 recount, B-8 D23 amendment covers on-chain anchoring and
  transferability; F6 gains overstated 5-20% and F6 moves template binding into the cache.
  Nothing outside check/ written (all runs -B). Nothing running.

## State: DONE. Nothing running, nothing launched.
