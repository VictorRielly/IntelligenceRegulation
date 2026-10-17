# Bounded suffix witness replay — cycle 0016

Run `20261003T220146Z-cf20886e`; seed 2026100316. CPU-only exact packing/scheduling
experiment, not a native block proof, trained model, GPU result or privacy gate.

## Tested question and baseline

The inspected `StackSource::prepass` calls `advance` for all L layers and drops
each witness. `restart` resets the stream, and the proving pass rebuilds them.
The existing source caches ONE witness only between `boundary_plane(k)` and
`witness(k)`. H-1 requires the final output sealed before the run header.
A contiguous suffix cache retains only deterministic INTEGER planes from this
same sealing attempt, before endpoint/proof randomness is drawn. It contains
no RNG, salts, masks, commitments or transcripts. Native integration is unbuilt.

Candidate `[PackedPlane]`: signed/unsigned 1/2/4/8-byte exact integers, preserving
plane count, length/order, nonzero padding and EMPTY histogram vectors. No
rounding, clipping or arithmetic change. Metadata/checksum stay private in RAM.
One attempt/context/layer bound, consumed once. Optional cache exhaustion evicts
or skips entries and recomputes: **it adds no input-dependent refusal**. No disk
witness cache or cross-run cache is proposed.

## Executed evidence

[Command](command.txt), [script](experiment.py), [stdout](stdout.log),
[result](result.json); exit 0, **0.097 s, 18,556 KiB RSS**,
one Intel(R) Core(TM) Ultra 9 185H CPU thread; no accelerator. RLIMIT AS 512 MiB / CPU 55 s,
59 s alarm, one-CPU affinity; estimated memory 32 MiB.

- 110 signed/unsigned boundary/random/empty vectors match independent
  `struct.pack` byte encodings and decode to the exact i64 inputs.
- 13 schedules over T=2/3/7/16, widths 4/8/16 and 1/3/6/8 synthetic layers
  give **670 independent forward-plane comparisons**. Suffix sizes 0, 1,
  half, all preserve witnesses, boundaries and final sealing output.
- 20 control categories include malformed bytes/metadata, i64 overflow,
  stage order, changed input/run/model, cached corruption, missing empty
  histogram, late sealing refusal and nonzero exp-padding preservation.
  Four budget-exhaustion schedules preserve all outputs by recomputation.
- Full suffix at eight synthetic layers removes eight second-pass builds;
  half suffix removes four. No proof state is cached; separate MOCK seeds
  change mock digests while witnesses remain identical. This is not native
  RNG/transcript verification.
- Native plane-list parser agrees with a separately named type manifest;
  i64 payload counts at toy and m125 agree with the independent retained
  native-layout probe (419,840 and 711,344,128 bytes).

The reduced forward oracle checks all score pairs, causal averaging and a
small linear FFN/residual. **It omits native norm, RoPE, exp/SiLU tables,
calibration and proof arithmetic**; it validates replay scheduling, not
full-block equivalence. Canonical i64 checksums use test SHA-256, not the
native proof's BLAKE3 transcript. No real private input, activation or weight
is retained. The synthetic digests in the result are synthetic only.

## Counted payload and decisive limit

Bytes below exclude Vec/allocator overhead, weights, looked/helper planes,
commitments, scratch, endpoints, masks, output copies and packing overlap.
Typed widths derive from successful builder ranges; E and SUM retain full
i64. This static conservative representation has **not** been validated on
native witnesses. Dynamic prototype sizes are separate. These are counts,
not RAM/VRAM measurements or throughput.

| Geometry | i64 MiB/layer | Typed MiB/layer | Typed whole stack GiB | Layers in 1 GiB payload |
|---|---:|---:|---:|---:|
| m125 | 678.39 | 122.36 | 1.43 | 8 |
| llama3_8b_T512 | 2296.52 | 385.18 | 12.04 | 2 |
| llama3_8b_T1024 | 6256.78 | 1106.34 | 34.57 | 0 |
| llama3_8b_T2048 | 19169.56 | 3556.67 | 111.15 | 0 |

The 8B rows use public Llama-3 geometry only; they are **unregistered**. Full
signed-int16 norm bound includes -32768 and epsilon and needs five limbs;
the inspected builder refuses any count other than four. The existing owner
trained-profile lane owns that repair. Do not label these rows admitted.
All ordinary score-plane pairs and P-3 domain lifts are included.

**Memory negative:** typed full-stack replay still costs 12.04/34.57/111.15 GiB
at T512/1024/2048. Increasing context makes cached attention quadratic. A
1 GiB payload budget retains 2/0/0 of 32 layers, even before metadata/peak.
Full caching is not a small-memory optimization. At T512, 2/32=6.25% of
second-pass BUILDS is removable under equal-layer-cost assumptions, not
6.25% of workload time. Full witness packing/expansion additionally moves at
least 5.24/14.38/44.39 GiB per cached layer at these shapes; those logical
lower counts omit extrema scans, checksums and plane copies. The Python
prototype adds all those costs; no measured bandwidth is assumed.

## End-to-end ceiling and falsification

Let Wc be measured second-pass witness time for cached layers, P packing,
U unpack/check/copy cost, and T the complete workload time. Maximum saving
is Wc-P-U; it is useful only when positive. Rate ceiling for N new positions
is N/(T-Wc+P+U), holding coverage/device/context fixed. Wc is unmeasured in
the retained owner run, so no numerical native/8B ceiling follows. For equal
first/second witness costs, even FREE full replay removes at most half of
the two-pass witness subtotal. Larger independent passes still pay these
recurring costs each time; they are not process initialization.

Falsify on any native plane/byte/boundary/refusal/RNG-continuation mismatch,
new cache-budget refusal, actual peak overflow, or replay overhead >= avoided
witness work. Require enclosing proof clocks and independent verification.

## Preserved failed/rejected designs

[Initial attempt](initial/stderr.log) refused the synthetic score range at a
late layer. Its script and exit 1 are retained. The reduced synthetic FFN
divisor changed from 4 to 32 to produce an admissible toy fixture; production
calibration is untouched. [Intermediate](intermediate-budget-refusal/result.json)
passed its arithmetic oracle but REFUSED on optional cache budget. That
changed-refusal design is rejected; final cache exhaustion recomputes.

## Integration and next test

[Handoff](../../handoffs/20261003-witness-suffix-replay.md): actual seam
`StackSource::{prepass,restart,advance}` plus existing `RunWitnessSource`.
No production files changed or merged. Need native tiny/ragged complete
plane/refusal differential, fixed-test-seed proof-byte and RNG-continuation
parity, then source-pinned existing phase clocks under owner's common guard.

Next bounded research: exact typed plane reader at `protocol.rs` witness ->
`a_data` conversion and later lookup/helper consumers. Expanding packed data
back to i64 before conversion forfeits much of the live-memory benefit.
Count all LAST reads before considering removal; the witness remains live
through exp/activation helper denominators. Exact typed storage could reduce
current per-layer peak even when suffix caching is too expensive, but that
benefit and whole-proof time remain unmeasured.

[Primary LIVE search](search-log.md) and source pins are retained. Checkmate
commit/history retrieval failed; no pin inferred. No external code executed.
