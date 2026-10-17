# Resident U8-helper producer: integer/field boundary

Cycle 0066, `20261017T192105Z-c342a26b`, 2026-10-17 UTC.
No proving speedup established. CPU-only source experiment; no native crate,
GPU, receipt, RNG, transcript, privacy acceptance or production edits.

The active F device evaluator already builds working tables from resident A/H.
It does not upload each resident helper from the host again. Before that stage,
the private-block prover still builds looked i64 columns and U8 helpers on the
host, writes planar H, and calls the tagged owned H committer. The older
`gpu::dev_helpers` and `pcs::commit_zk_device` are useful interfaces to study;
the latter is an untagged API with incomplete host helper rows, so it is not
a drop-in replacement for this block's tagged H and CPU readers.

This experiment asks whether the U8 producer could use resident A alone and
drop `looked` after the byte histogram. Source and checks are pinned in
[native-pins.json](native-pins.json), with exact captured files under `native/`.
Baseline is `lookup_values_at`'s literal wrapping-i64 closure, followed by
`Fp::from_i64`, the cached byte inverse/single-value helper and `write_h`.
The actual field and these local bodies are compiled into a std-only Rust
shared library. This is a small isolated source build, not a native prover build.
Serial wrapper orchestration substitutes for Rayon and the real caller.

**Negative:** computing affine lookups directly in the field changes malformed
integer-witness behavior. Moreover, A has discarded a bit of information:

```
p = 18446744069414584321
x = -9223372036854775808
y =  9223372032559808513
x mod p = y mod p
wrapping_i64(2*x) = 0
wrapping_i64(2*y) = -8589934590
```

Coefficient 2 occurs in the real Q/K rotation remainder catalog. Thus no
deterministic A-only producer can reproduce all old helper words across the
old internal full-i64 witness domain. Both directions of helper-stage zero
denominator status change are exhibited. This is not a demonstrated change
to accepted complete proofs, a native soundness defect, or an admissible-input
attack. Honest bounded arithmetic does not overflow; the stronger all-witness
byte/refusal compatibility gate still needs a solution.

`resident_codec.rs` is a compiled, research-only interface for one solution.
A residue has two signed-i64 preimages precisely in `[p-2^63, 2^63)`, an
interval of `2^32-1` residues. Preserve one private bit for each relevant source
word, set only for a negative ambiguous preimage, reconstruct with unsigned
word arithmetic, do the affine calculation modulo `2^64`, and then convert to
the field exactly as before. Identity columns need neither reconstruction nor
this bit: their field denominator is already exact. Bitmaps belong to the
current proof's private memory, never public metadata, captures or receipts.
No model/mask/opening reuse is involved. This codec is not a CUDA implementation
or an integrated H producer.

The independent Python reference uses arbitrary integers, per-term signed
conversion and direct modular inversion. A separate audit uses full-extension
exponentiation, interval/preimage reasoning and actual FFI bit-index mutations.
Tests include all int16 values; random/full-i64 ambiguity and wrap boundaries;
48 source-derived public catalogs, all six domains, odd/single/paired helpers;
zero, 1, 2, 3, 7, 63, 64 and 65 lengths; arbitrary synthetic padded words;
generic affine/multiterm columns; used/unused/out-of-range zero denominators;
and both planar limbs with disjoint offsets and sentinel gaps. Helpers' failed
buffer contents and real orchestration are not reproduced: the harness keeps
its synthetic output private until all its checks succeed. Only helper-stage
status and accepted output values are compared.

Run from the research directory:

```
python3 experiments/lookup-helper-staging-20261017/prepare.py
python3 experiments/lookup-helper-staging-20261017/run.py
python3 experiments/lookup-helper-staging-20261017/audit.py
```

`prepare.py` captures current source. Do not run it over retained evidence
unless starting a new explicitly named capture. Its reviewed parser is copied
from the previous local catalog experiment; no downloaded code is executed.
The final compile command is in `result.json`; `run.log`, `compile.log`,
`audit.log` and `environment.json` retain results and hardware. Each runner
sets CPU0 affinity, nice 19, a 59-second CPU/wall limit and 512 MiB address-space
cap. Estimated Python/compiler memory is under 96/192 MiB; no dependency install.
Earlier passing evidence is retained in the two `initial`/`before` directories;
a weak midpoint control was strengthened to execute the actual wrong lift.

`accounting.json` separates payload illustrations from measurements. At the
earlier TinyLlama T128 geometry, all looked storage is 221.25 MiB per block;
the prior borrowed-column candidate leaves 53.75 MiB. A bitmap for only
nonidentity expressions' source planes is 0.609375 MiB, while U8 H outputs
still occupy 235.25 MiB. These are not measured peak/traffic savings. Current
CPU consumers, host/device H coherence, fallback, masks, keyed commitment
ownership, error handling and transfers must be resolved before that storage
can be eliminated. 8B/bigger-context rows keep hypothetical-shift qualifiers.

The old 1.1B T128 owner GPU-assisted process spends 8.844 of 161.857226 seconds
in all U8 H helper construction. Even deleting that whole parent caps direct
gain at 1.057799x with other work fixed; the CPU analog is 1.041052x. The
prototype retains the helper work and adds packing/reconstruction. Actual
8B helper phase, native gain and GPU cost are unknown. The whole prover and
public model residency remain higher priorities. Reject a port on any
word/refusal/RNG/transcript/PCS/byte mismatch or no enclosing workload benefit.

Source search/date/license/commit qualifications are in `searched-sources.json`.
The [handoff](../../handoffs/20261017-resident-helper-integer-boundary.md) and
[dated report](../../progress/20261017T192105Z-c342a26b.md) contain owner gates
and the complete target clock report. The >=50 proved-token/s target stands.
