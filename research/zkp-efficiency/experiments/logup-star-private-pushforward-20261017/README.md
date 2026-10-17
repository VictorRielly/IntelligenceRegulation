# LogUp* private pushforward boundary

Cycle 0067, `20261017T202105Z-363d38a1`, 2026-10-17 UTC.
**No proving improvement established.** This is an arithmetic prototype and
negative privacy/binding study, with public-source cost accounting. It is not
a GKR implementation, a native proof, a privacy proof or a performance test.

The motivation is real: H commits reciprocal helpers for private lookup
values. The native `looked` arrays themselves are already uncommitted. No
additional query-value commitment can be counted as a saving. The author's
[LogUp* note](https://eprint.iacr.org/2025/946) and the
[Powdr opening protocol](https://powdr.org/papers/twist_shout_logup_star.pdf)
motivate a table-length pushforward, whose original-index and pushforward
terminal claims still need binding. No upstream implementation was executed.

`pushforward.rs` supplies the research-only interface:

```
pushforward(index: &[usize], active: usize, r: &[Fp2], table_size: usize)
    -> Result<Vec<Fp2>, u32>
```

Its outputs are private scratch. For N=2^k, prefix support S, index I and
equality weights w_i=eq(i,r), it builds Y_j=sum_{i in S:I_i=j}w_i.
The local FFI wrapper also evaluates v(r)=sum_j Y_j T_j. These equations
include public support; this synthetic prefix support is not a reproduction
of the native kernel's entire pad/refusal relation. The adjacent-pair/LSB
cube convention matches native folds. Source-captured Goldilocks Fp2 is
compiled into a tiny std-only shared library, without Cargo or native crates.

The main differential test passes **405 fixtures, 23,166 pushforward Fp2
values, 405 virtual claims and 405 support checks**. Table sizes 2/4/8/16/256,
N=1/2/4/8/16/64, empty/single/odd/full active lengths, base/extension/Boolean
challenges and deliberately invalid inactive indices are exercised. Python
uses independent product-form weights, dense one-hot enumeration and an
adjacent-pair folding reference. The separate audit uses polynomial
convolution and independently reads every saved fixture. Its final
**24,014 checks** include source/count reconciliation, two terminal mutations
and an unbound-index control. Fourteen main controls pass.

The decisive negative is stronger than exposing an unmasked Y vector. With
one active query at position 0, a public virtual claim is
`v(r)=eq(0,r)*T[I[0]]`. Its nonzero known weight can be divided out, recovering
the private table value even if Y's commitment is perfectly hiding. Twenty
Goldilocks-extension controls recover the synthetic value exactly. The
same-histogram orderings [1,3] and [3,1] also have different virtual claims.
Exhausting F17 challenges distinguishes them at 16 of 17 points; the sole
exception is r=1/2. Thus replacing ordered binding with a histogram fails.

A zero-sum mask on Y generally changes the claimed value. A mask orthogonal
to the table preserves the original leaking scalar. An exhaustive scalar
one-time-pad illustration hides that scalar's marginal, while reuse reveals
differences; it is **not** a complete masked lookup construction and gives
no authorization for mask reuse. The diagnostic substitution control passes
self-consistent replacement arithmetic and fails the original ordered claim.
This models the need for terminal binding; it is not a forged native receipt.

The zero-denominator control retains the earlier whole-table negative: an
unused public row with zero denominator still causes the old attempt to
refuse. A membership-only/used-row check does not. We test that event only;
native ordering, error paths, draws and transcript operations are not replayed.
Prior fractional-tree root D/C disclosure and two-zero-leaf negatives remain.

`accounting.json` reconciles the current Llama-3-8B T32 shape with the owner's
public R5 counters. Per block: 83 U8 lookup columns, 11,714,560 queries,
**1,514 U8 helper base rows / 99,221,504 bytes**. All H is **1,758 rows /
115,212,288 bytes**, also containing exp/activation helpers, three table
helpers, the zero-sum pair and reserved/proximity rows. These are gross
payload counts, not removable masks, measured traffic, peak memory or net
commitment savings. A 256-entry Fp2 pushforward is logically 4,096 bytes;
putting its two limbs in the current 8,192-wide row layout costs 131,072
bytes before masks. Unbatched 83 pushforwards are an illustration, not a
required design or a lower bound; batching still needs its own construction.

The newly available R5 CPU 8B T32 phase diagnostic reports 171.578 s total,
including witness 21.376 s and reloads 15.993 s inside the inclusive
156.143 s prove-run clock. Fresh cli3 verification had not been observed at
the cost capture. Its summed H commit/open/U8/exp-act clocks are
11.75/2.23/4.78/0.74 s. Deleting **all four whole phases for free** removes
19.5 s, bounding their direct effect at **1.128224x**, or 0.210418
diagnostic positions/s, with all other work fixed. This deliberately
overcredits a U8-only candidate. It is not an upper bound on an architecture
that changes other phases, and not a 5090 forecast or an accepted proof rate.
Masking, GKR, terminal bindings, PCS, scratch, transfers, serialization and
verification are added costs with no native clocks here.

Reject a drop-in adaptation on any private raw evaluation, missing original
binding, changed denominator refusal or padding mismatch. Even a correct
redesign must show net workload savings after all added costs. The actual
integration seam is `private_block/protocol.rs` at lookup construction/H
commit, and `argument.rs`/`shape.rs`/`layout.rs` for affected slots, H claim
sites, M schedule and PCS bindings. No production patch or integration ran.

Commands from the research directory:

```
python3 experiments/logup-star-private-pushforward-20261017/prepare.py
python3 experiments/logup-star-private-pushforward-20261017/run.py
python3 experiments/logup-star-private-pushforward-20261017/account.py
python3 experiments/logup-star-private-pushforward-20261017/audit.py
```

`prepare.py` captures live public source; start a new capture before rerunning
it rather than replacing retained evidence. Main elapsed 0.356768 s, Python
peak 28,256 KiB, compiler peak 122,168 KiB; final audit 0.088526 s / 24,432
KiB. One Intel Core Ultra 9 185H CPU thread, CPU0, nice19, seed2026101767;
59-second CPU/wall and 512-MiB address-space caps. Estimated Python/compiler
memory below96/192MiB. These times establish bounded execution only. No GPU,
dependency install, native proof, real private data, Git or production write.

`native-pins.json`, `fixtures.json`, `commands.json`, `searched-sources.json`
and `artifact-manifest.json` retain provenance. The run/audit logs are explicitly
derived copies of returned JSON, while raw stdout is in the API transcript.
New older DUPLEX and Locq were assessed from primary metadata/abstracts;
their RSA/KZG backends introduce new arithmetic, commitment and composition
work. They do not remove native H by a plug-in substitution. Exact dates,
licenses, uninspected hashes and failed PDF/source fetches remain recorded.

Next bounded experiment: test domain/column batching for these 83 U8 columns,
counting each new pushforward and terminal mask site, with odd/padded-column
controls. Do not publish any raw virtual evaluation. Owner whole-prover GPU
and completed fixed-context workload clocks remain the higher-impact lanes.
