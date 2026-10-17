# Owner handoff: heterogeneous public/dense driver

Cycle0039, run `20261012T202555Z-550cccf0`, 2026-10-12.
**Synthetic conformance passed; native speed/privacy/receipt gates outstanding.**
No production edits, merge, build, GPU job or heavy queue action.

Candidate and evidence:
[experiment](../experiments/heterogeneous-public-driver-20261012/README.md),
tested `driver.py`/`experiment.py`, uncompiled/unapplied `driver.rs`,
`support.rs`, `causal_mask.rs`, command/result/execution/log and pinned native
snapshots. Final20.963668 s,22,656 KiB RSS, seed2026101239, one pinned nice19
CoreUltra9 CPU thread,59-second/512-MiB caps. The initial passing run and one
edit syntax failure are retained separately.

32 fixtures/128 schedules:384 generic SZC totals;720 independent original-cube
round samples vs2,880 candidate samples;896 independent SZC finals; companion
RS32 totals/600 samples/160 finals;43,008 independent extension-table samples;
1,536 extension polynomial samples;1,536 public selector/terminal values;
24 controls. Contexts1/2/3, padded1/2/4, queryheads1/3/6, KVheads1/2,
cube logs0/2/6/7, arbitrary/base/Boolean/zero Fp2, two/three limbs and odd/even
helpers. These are algebra fixtures, not admitted native profiles or witnesses.

The interface takes explicit original cube log and original-order table
entries. Each is dense, public support or public causal. Private/equality
tables remain dense. Row reads are immutable during round reduction; all
tables bind once after reduction. Generic private total uses the same row
reader. Finals preserve every original index. HOST recovery starts `None` on
inconsistent data, and subsequent claims come from actual unmasked samples.
Public extension targets are zero and retain every `(1-e)` selector.

Read-only candidate seam:

- `hashline/src/private_block/argument.rs`: Tab66, build338, total406,
  run447, census512, verifier613, B::public716/B::supp810, causal1013,
  RS1265/SZC1699. Add descriptors through the builders without changing
  pad/profile/shape admission or table count/order.
- `zkp-core/src/sumcheck/rounds.rs`: ClosureRounds52; replace implicit
  first-table length with explicit validated cube and common endpoint/fold/final
  access. `driver.rs` sketches the serial adapter, not native module wiring.
- `zkp-core/src/sumcheck/grouped.rs`: round99/fold149/finals175. The grouped
  closure still consumes the same scalar row; exact endpoint reading belongs
  in the round adapter. **Optimized grouped integration has not been tested.**

Pins in the experiment's `native-manifest.json` define the source; lines are
navigation hints. Original verifier polynomial, extension routine and all
masking/transcript/claim/audit operations remain authoritative.

At m125 head map/T512, three simultaneous SZC public tables are192 MiB logical
payload; dense public folds12,582,909 become1,026 descriptor binds. RS has
128 MiB public payload in a separate sequential slot. Logical field-state
upper bound for SZC is24,768 B; native Vec capacities, metadata, allocator and
parent peaks are unknown. Added typed dispatch, endpoint predicates, O(T)
causal preparation/drop and compiler/parallel-driver costs must be priced.
This is not a native traffic/runtime claim. The historical entire RS+SZC
slot ceiling is8.394 s within27.523873 s whole-test wall, one synthetic block;
this candidate only affects a subset. No numeric accepted8B ceiling exists.

Owner validation sequence: admitted-shape verifier descriptor and terminal/
refusal/frozen-byte parity; then native total/Closure/Grouped/census/extensions
and the owned actual SC_SZC masked-transcript oracle. Preserve future-score
host checks, padded helper clauses, Ht constant over j, grouped head support,
shape-derived degrees, draw/absorb order, and fresh per-proof masks. Check
release skip/debug recovery, zero factors, inconsistent witnesses and source
pins. Isolate construction, reader/dispatch, fold/final shares and native
memory peaks before a guarded independently verified complete A/B under the
owner shared build/heavy locks. No permission to reuse masks/private openings,
alter PCS/soundness/profile or promote this sketch follows from the result.

Next local experiment is complementary GroupedEqRounds representation parity
with independent original-cube samples, per-group claims, zero equality factors
and false asserted hosts. Accepted independently verified complete private8B
proofs/passes/tokens remain0; rates and all proof-phase/startup clocks are
unmeasured. No prefill/resident/decode proof. Target>=50 proved tokens/s stands.
