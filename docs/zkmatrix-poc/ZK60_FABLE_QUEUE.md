# Fable — independent review priorities after round 6

These are documented assignments for Fable's own session, not claims that
Codex workers are Fable or that independent review has finished. The original
[F1 brief](ZK60_EXECUTION.md#f1--task-for-fable-prove-which-model-ran) remains
in force. No sensitive application inputs until the shared privacy gate closes.

1. **FA1: reproduce actual FFN opening-group behavior.** Start with the
   [source-derived inventory](ZK60_FFN_MASK_INVENTORY.md), especially X-at-p2
   and h16-at-p5 at the tiny one-row profile. Deliver independently verified
   proof/public-observation evidence, exact grouping/challenge replay, default
   fresh-randomness coverage and negative controls. The existing isolated
   singleton diagnostic is already executed; do not count it again as real-FFN
   evidence. The round-6 reproduction attempt produced no implementation.
2. **FA2: joint privacy assessment.** Cover actual A/H/W groups, terminal and
   proximity vectors, helper sums, CFS functionals, pads, table histograms and
   mask reuse across all observations. State base/extension-field rank and
   conditioning assumptions, code dimension/distance and cumulative queries.
   Determine the affected supported shapes; singleton cases do not establish
   or refute privacy of every larger group.
3. **FA3: review a concrete repair and private-block mask plan.** Specify new
   mask reservations, allowed claim transforms, one-shot opening order and
   transcript/profile domain. Review existing core masks and new seams together;
   adding seam pairs alone is not a repair. Codex implements only the reviewed
   plan, preserving legacy fixtures and marking any new compatibility boundary.
4. **FA4: approved private-model consistency.** Independently review the known
   P3 substitute-weight diagnostic. Specify a relation connecting fresh hiding
   W commitments to independently approved stable model identity, with exact
   registration/authentication and repeated-opening assumptions. A model-name
   string or copied candidate root is not authorization.
5. **FA5: arithmetic/security closure.** Review field-to-integer/no-wrap bounds,
   lookup/range constraints, challenge distributions and whole-proof soundness
   for the precise MVP profile. Host-oracle checks and frozen bytes are not a
   proof-level certificate. State remaining caveats instead of assigning an
   inherited security number to an unreviewed composition.

File coordination: Fable may add its independent review document and new
dedicated `hashline/tests/zk60_model_identity.rs` tests from the original brief.
For FA1–FA3 shared-source instrumentation, agree an exact lane with Codex first;
Codex owns `zk.rs`/attention/composition integration, Claude owns GPU/PCS and
memory-planner work. Use isolated checkouts, CPU-first tiny cases and the shared
heavy lock with two threads. No GPU/full-model launch or security-parameter
change is authorized merely by this queue.
