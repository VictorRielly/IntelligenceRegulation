# R12b delivered for the independent fix review

R12b is frozen at
`51de5b83bc0dcaeeeb430165081c47653ac012c462c09f3df4ce7f125faf904f`
(229 files). `R12B_COMPLETE.done` is zero; `R12B_AUDIT.json` audits all
21 final stages. The R8, R9 and R12 freezes retain their exact file sets and
file hashes. No new soundness or privacy acceptance is claimed.

R12-F1 now checks derivation, not only declarations. The loader checks the
three integer tables' exact dtype, shape and size, then recomputes their
digests by streaming the authenticated Shieldstral BF16 checkpoint. Final-norm
weights are captured from the same reads authenticated by the full checkpoint
hash; the consumed embedding tensor has its own pinned digest. A doctored head
or multiplier file is refused even after its manifest digest is updated.

R12-F2 uses bounded descriptor-checked regular-file hashing: no final symlink,
FIFO or device is opened, the opened identity/length is rechecked, and the
read length is exact. R12-F3 refuses `--rope-from-export` at every profile
with a pinned RoPE transform. N-7's retained test fixture is under results.

The new files are included in both source pins and the hash/absorb censuses.
The census classifies their six streamed SHA-256 constructors as public model
and table hashing, outside the proof's BLAKE3 oracle classes. The norm accessor
uses the prover's declared bounds, including legal `tn=7`; the classifier's
`tn=10`, `ceps<2^40` window remains strict.

| Final acceptance | Result |
|---|---|
| Complete native suite | 739 passed, zero failed, 29 targets; 43 deliberately ignored |
| Required ignored gates | Five seeded/identity tests, two dense proofs, two fresh-byte checks, one full tied-table attack check separately passed |
| Focused R12/R12b | 18 passed; all nine token-calibration fields affect the trained statement identity |
| New components and source/hash censuses | Four component tests plus both census gates passed |
| Full pinned-tensor independent calculation | Native embedding/head/multiplier and both margin digests equal independent NumPy |
| Actual Astra export | All four actual table files equal native recomputation; BOS/classifier norm equal the profile |
| Forgery controls | Rehashed head and multiplier modifications rejected; dtype/shape and short/special-file controls pass |
| Existing profiles | Four R9 seeded digests and five statement identities unchanged |
| Saved complete-stack receipts | R8/R9 TinyLlama 22-block and 8B 32-block runs verify under the new CPU CLI, DD and non-DD, at their original identities |
| CLIs | CPU and GPU-enabled trained CLI builds pass; derivation CLI builds and runs |

The two generic dense T128 proofs are public synthetic witnesses at Shieldstral
geometry, with independent kernel agreement and differing heads. Their receipts
are 29,301,896 bytes (non-DD) and 29,536,904 bytes (DD); both verify in a new
process and modified receipts are rejected. Peak sampled RSS was 6.52 GiB.
The pair's log records 197.97 s under **shared box, browser load**; that timing
is excluded from performance measurements by the coordinator's timing note.
It is not a trained classifier or sustained throughput result. Every heavy final stage used the common
guard; this sandbox reported watchdog-only enforcement, not kernel cgroup caps.

## Public interface for token and export lanes

`hashline::private_block::tied_tables::recompute_tied_tables(export, margin)`
returns the three table digests, an optional directly quantized margin row,
and typed calibration data. `margin` is `Some((yes_id, no_id, public_scale))`.
`tied_token_calibration(export)` exposes the profile-authoritative BOS and
classifier/head `(g0,cn,tn,ceps)`, together with the profile digest.

The token verifier must take IDs/scale from its statement-bound registered
policy/profile and require its files to equal recomputation. It must consume
the returned BOS/norm values or compare its copies; there is no file-preference
fallback. The F1 native loader uses the same derivation mechanism.

Exact quantizer:

- Widen BF16 exactly; use binary64 signed block-Hadamard transforms, three
  blocks of 1024 divided by 32.
- Embedding: rotated row is cast to binary32 then widened; divide by the
  first residual scale from the profile; `floor(x/scale+0.5)` in int16.
- Head: multiply by the checkpoint's final norm before rotation; per-row
  scale `max(abs(row))/127`; the same half-up rule in symmetric int8.
  All-zero rows stay zero. Multipliers are
  `max(1,floor(4096*row_scale/max_scale+0.5))`, stored as int64.
- Margin: rotate `(E[yes]-E[no])*checkpoint_final_norm` before quantization;
  divide by one public scale and apply the half-up rule. Refuse outside
  `[-32767,32767]`; no saturation or difference of separately rounded rows.

Calibration authority is `profile.json.token_io_parameters` with `bos`,
`classifier_final_norm` and `head_final_norm`, inside the profile digest the
trained statement binds. The authenticated checkpoint can be located by
`tied_embeddings.checkpoint_file`; absent that, the existing pinned local
snapshot is used. Its content pin, BF16 dtype and exact shapes remain mandatory.

For Shieldstral's actual registered IDs 13059/2649, the chosen scale is
`4.08288030735373e-6`. The 3,072 quantized coordinates span -32767 to 31800:
**COUNTED: zero coordinate refusals**. This is a public table quantizer check,
not an inference refusal/fidelity evaluation. `policy_margin_reference.json`
and `ASTRA_TABLES_CROSSCHECK_r2.json` record the independent and actual-export
checks. The reference fixture's public test norm calibration is not a trained
classifier acceptance.

## Reproduction and retained evidence

`frozen-tree/`, `manifest_frozen.json`, `r12b-vs-r12.patch`, final `*-r2`
commands/logs/guard records, source candidate, receipts and hash manifests are
beside this report. The exact heavy commands are JSON arrays; builds use
offline/locked Cargo and two build jobs. `accept_r12b_r2.py` resumes completed
gates and refuses an unexamined incomplete run; `finalize_r12b.py` independently
audits the gates before atomically exposing the frozen tree.

The first full-suite attempt is preserved: 593 passed and one stale hash-call
census failed. The module enumeration/classifications were corrected, legal
norm endpoints were tested, and every final gate was rerun on the frozen source.
The full final suite used the prior measured four-test-thread configuration.

Retained executable SHA-256:

- CPU trained CLI: `d9106df642156410812095e657b2e13edec023e922c61ce660d34e194114d4a1`
- GPU-enabled trained CLI: `5065475c9a1fdc2fe7007472c6d4e2c35e703f08b093f4a5bbda0758d4b81b78`
- Derivation CLI: `1d6396bacf60a7ce906771ce1f727d53893a5203314050a827548627f00c020b`

Next: coordinator routes the independent R12b fix review and token R-C2 rebase.
Sol rebases the isolated R13 work onto this freeze, then completes the accuracy
profiles and the approved Shieldstral-only `(0,-8)` member, with native counts,
proofs and a separate D24 review. R13 is not yet a proof entry point.
