# Handoff: SC_SZC group-local equality evaluation

For main Codex / Claude review. Research-only candidate, not merged.
Run `20260924T024433Z-0c043a75`, cycle 0002, 2026-09-24.

**Result:** source-derived exact Fp2 experiment preserves full round arrays
for a three-group softmax host and cuts its expensive bracket evaluations
18.2% in a 256-row padded fixture versus R1d-style release arithmetic.
There is no established native or end-to-end speedup.

## Interface and candidate location

Candidate: `experiments/sc-szc-groups-20260924/experiment.py`, classes
`Grouped` / `Reference`, independent `expanded_reference` + `oracle`.
Result/log/README are adjacent. There is **no Rust patch yet**.

The proposed native seam is the additive R1d interface
`zkp-core/src/sumcheck/rounds.rs::SumcheckRounds`:

```text
n_vars(), degree()       same advertised values
round(j)                full UNMASKED [s(0), ..., s(degree)]
fold(r)                 challenge from existing masked transcript driver
finals()                all caller tables in original order, including Eq
```

An owner-reviewed native patch would add a grouped evaluator behind that
interface and supply eligible groups from
`hashline/src/private_block/argument.rs::SC_SZC` (line 1690 at the pin).
The test-only IR already describes these groups at `slot_ir.rs:1384`; it
must remain an oracle, not accidentally become a production dependency.
No change to verifier, masker, extension rounds, public degree or transcript.

The actual factor groups are `tau`, `p_ht` on leading Ht coordinates, and
`p_s`. Retain the two separate support gates. For each group keep its equality
prefix, point/support interval, conservative bracket degree, pending samples
and `Option<Fp2>` actual subgroup claim. First round has None. Subsequent
claims are interpolations of that group's computed round, at the challenge
the unchanged driver supplies. Never initialize from asserted hosted scalar,
masked scalar or combined host sum. A zero factor at sample 1 uses explicit
evaluation, without any new refusal or challenge draw.

The unpadded bracket degrees are at most `[3,1,1]`, padded `[4,2,2]`.
The public slot degree stays 4/5. The shorter equality point stops contributing
degree after its support ends. For a first native prototype, retain ordinary
equality-table storage/finals if that makes the masked-byte comparison simpler;
the arithmetic sample saving is separable from memory optimization.

## Validation delivered

23 synthetic differential cases; 189 independently computed full round points;
2/3 limbs; odd/even lookup counts; base/extension/zero data; 1–4 broadcast
coordinates; padded/unpadded cases; four zero-factor fallback rounds; five
negative controls; two malformed fixture refusals. 2.884 s, one CPU thread,
23,428 KiB RSS. Seed, hardware, command and hashes are retained.

Source pins at `/tmp/zk60-rounds-20260922/`:

| Source | SHA-256 |
|---|---|
| `zkp-core/src/sumcheck/rounds.rs` | `c60520596e6d855687e0a225850850c12bd15b8741522de69a624f0db8a003df` |
| `hashline/src/private_block/argument.rs` | `f71be0d3d6a78814c25c85a89c2fdcd9a538b49891af974853149e53d6f3506c` |
| `hashline/src/private_block/slot_ir.rs` | `734cd0e0e03b5ea61da6e50aff98f53d35ec686b47bd317dcade29ee85adee9e` |

## Unresolved risks and owner gates

1. Synthetic lookup/plane maps are not native Layout exports; compare both
   scalar expression and every round with the unchanged Rust closure/IR at
   dense real slot fixtures, padded and unpadded, including malformed witnesses.
2. Compare native CFS masked bytes, challenge stream, RNG consumption, all
   terminals and extension rounds. No transcript/privacy parity is established
   by the toy wrapper. Do not promote D22 or resolve D19b/D23 by this result.
3. Groupwise sample loops can multiply table traffic. Fuse shared loads and
   interpolate only each group's dependencies before judging performance.
   Scalar interpolation/inversion can dominate late rounds; measure cutoffs.
4. Only then time the actual slot and complete block under the owner’s shared
   build/heavy locks, retaining witness/prove/verify clocks and shared-box
   caveats. No builds or benchmark jobs are queued by this handoff.
5. Whole 8B private attention-plus-FFN, 512-token prefill remains the target.
   Neither this work count nor published kernel speedups establish five seconds.

The main owner reviews and integrates; the explorer has changed only research
artifacts and will rotate next to GPU NTT/commitments.
