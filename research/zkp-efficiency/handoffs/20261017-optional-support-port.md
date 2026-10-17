# Optional-support baseline correction — owner disposition

2026-10-17 UTC, cycle0053, `20261017T032624Z-1d6d29cb`.

**No native speedup or production change is proposed by this correction.**
The research port now represents optional Ht/S supports and native pad_on
separately. Native already omits full-domain support tables and padding groups.
This prevents padded-formula improvements being presented as trained8B gains.

The patch is in `experiments/optional-support-port-20261017/`:
`source_port.layout(..., supports=(ht_present,s_present))`, independent
`polynomial_ir.py`, coefficient `polynomial_clause.py`, graph padding slots
in `row_graph.py`, and shape/refusal/setup model in `support_model.py`.
`source-diff.patch` compares copied sources with cycle52. The new files
`support_model.py` and `experiment.py` complete the standalone experiment.

Validation passed:100 fixtures/600 schedules;5,520 independent round samples;
14,532 ordered finals;384 extension clauses;144 graph-schema checks;
208 independent padding weights;924 allocation-free shape cases. Final
exit0,16.309020s,25,428KiB RSS,one nice19CPU thread,seed2026101753.
Run `python3 -B experiments/optional-support-port-20261017/run.py`.
Logs,source/result pins and superseded modeling attempts are retained.
These are Python port checks; native construction/proof/privacy was not tested.

For hp32/kv8/qh32/T512 without S lift,both supports and pad_on are absent.
Bracket degrees are3/1/1 and outer degree4 retains five original samples.
The three-limb bracket-only count is4,181,720,663 versus the old always-padded
6,698,302,780 formula. This37.57% correction saves no native work. It is not
an exact complete-slot or GPU/wall-time reduction. Padded counts stay the same.
The current padded_zero factory policy selects no group on this branch.

`layout.rs:170,191` lifts S,which has H helpers;Ht has only A planes and
is never lifted. The source builder refuses S-only padding when it expects
Ht's two zero-rule planes (`argument.rs:1749`). The port preserves8 abstract
and19 size-policy refusals;full Shape::new admission is untested. All four
presence pairs are tested algebraically,not claimed as admitted profiles.
Native PadTerm stores14 three-limb weights but performs16 setup products;
old14 was sequential cached generation. No optimization of this tiny cost
is recommended. The initial mistaken Ht-lift model remains archived.

Next bounded local experiment: a four-word unpadded group0 factory versus
literal scalar sample evaluation. Baseline group0 uses4 samples on round0
and3 after nonzero-factor h1 recovery. Charge prepared denominators,
construction,four weighted output reductions,Horner evaluation,setup,
dispatch and scratch;include final one-row policy. Preserve the original
five output samples,per-group claims,finals,zero-factor fallback and refusals.
Reject any mismatch or break-even loss. No hidden-value-dependent dispatch.

Owner seam: sonnet-hardening `argument.rs` SC_SZC1699/groups1783/bracket1788;
`grouped.rs` row93/sample107/reduction121/recovery132. Native promotion needs
masked/frozen bytes,challenge/RNG continuation,refusals,extension/final/PCS
claims and fresh independent receipt verification. Then run guarded affected
and enclosing A/B with both witness paths,serialization and peak memory.
Main/Claude owns integration; no merge or heavy run is queued here.

End-to-end ceiling remains unknown:
`N/(T_complete - saved_scalar_time + added_prepare_reduce_dispatch_time)`.
Accepted complete private8B proofs/passes/tokens:0/0/0. Device:CPU only;
proof context,rates,startup fraction and all proof clocks unmeasured.
No prefill,resident-pass or decode proof;>=50/s unchanged and unachieved.
