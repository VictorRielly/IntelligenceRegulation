# D63 lane L29: the executable stage IN-C and OUT-C verifiers, the stages' completeness, and the honest prover's oracle form (2026-11-07)

Lean lane L29 (Claude), on its own worktree branched from perf at `b7459211` and fast-forwarded to perf `6d1b21ad`
(lanes L9–L25 merged; no merge commit). Lean 4.34.1, Mathlib v4.34.1, no new dependency. Six new library files under
`formal/ZK60Formal/`, imported by the library root: `StageVerifyExecLay.lean`, `StageVerifyExecInC.lean`,
`StageVerifyExecOutC.lean`, `StageVerifyExec.lean`, `StageVerifyExecComplete.lean`, `HonestOracleProg.lean`; one checker,
`StageVerifyExecCheck.lean`, not imported (it defines `main`). One TEST-ONLY Rust file,
`ops/zkp-mvp/gpu-metal/hashline/src/lean_l29_export_tests.rs`, declared by two lines (a comment and one
`#[cfg(test)] #[path] mod`) at the end of the test-only `private_block/token_io/classify_capture_tests.rs`; it lives in
`src/`, not `src/private_block/`, as lanes L10's and L18's do, so `s25_tests.rs`'s `TEST_ONLY_FILES` needs no new entry.
`Statements.lean`, every existing Lean file and every production source are unchanged. Evidence:
`results/zk60_lean_l29_20261107/`.

Labels: **PROVED** (a Lean theorem, axioms at most `propext`, `Classical.choice`, `Quot.sound`), **TESTED** (value for
value against the Rust code), **CODE** (read off the sources, file:line, 2026-11-07), **ESTIMATE** (arithmetic or
reasoning not proved in Lean), **CONTRACT** (a named premise a component lane must discharge).

## 1. In plain words, for Victor

**What this lane is.** Your gate `ProductionReady` for the media app's classify run was assembled by lane L18 with the
run's two token stages, IN-C (the hidden token ids into the first block's input) and OUT-C (the last block's output
into the published verdict), as PARAMETERS: no Lean verifier existed for them, so the protocol object was only as
concrete as those parameters. Lane L25 then wrote the honest provers of the blocks and reduced completeness (O8) and
the refusal list (O9) to named contracts, one of which was "the stage verifiers". This lane removes that parameter and
takes the next step on the honest prover's oracle form.

**What now exists.**
- **Both stage verifiers, as executable Lean, in the code's order.** `stage_in_c::verify` and `stage_out_c::verify`
  line for line: the segment decoder (the stage frame `HLPCLIN1` / `HLPCLOT1`), the path-depth checks, the frame
  absorbs, the roots, the challenges, every slot's definition with its tables and closure (lane L15's closures for
  OUT-C, new ones for IN-C), the slot loop (lane L9's), the functional count, the openings' audits (lane L10's), and
  the openings themselves (lane L10's executable functions at the stages' parameters). PROVED: each accepts EXACTLY
  when every one of its checks passes in that order, and their slot phases are lane L15's Fiat–Shamir model of a
  stage.
- **The classify run's protocol object is now concrete in its stages.** L18's stage parameters are instantiated with
  these verifiers (`classifyProtocolExec`); the run's acceptance is PROVED to unfold into: the pre-header checks,
  `L + 2` segments, stage IN-C's decode and verify, the blocks in order, stage OUT-C's decode and verify.
- **It agrees with the code on a real receipt.** A test-only export proves an honest classifier run on the development
  rung, verifies it with the production verifier, and replays both stage verifiers step by step beside it. Lean then
  runs ITS OWN stage verifiers on the same data: PLACEHOLDER_TESTED
- **The stages' completeness in L25's form** (`StageInOK`, `StageOutOK`). The honest IN-C and OUT-C provers are written
  in Lean in the code's order, and PROVED: the executable stage verifier accepts the honest segment (and the segment
  decodes back) given the same kind of component contracts L25 named for a block: each slot's arithmetic, and the
  completeness of `M`'s test and of the openings (L10's functions, whose completeness is not yet proved). So O8's stage
  part is now in exactly the shape of its block part.
- **The honest prover's refusals as transcript programs, `δ = 0`.** L25 proved that a refusal whose computation is
  written as a "transcript program" has freshness `δ = 0`, and left writing the run in that form (L25-3). This lane
  builds the combinators (sequencing, draws, the honest sumcheck, a commitment's Merkle root, the transcript's creation)
  and PROVES, for any slot of any part, that its `c = 0` refusal, each of its degenerate-extension refusals and each
  zero batching coefficient is such a site, firing EXACTLY when the honest prover's own guard does; the same for stage
  OUT-C's LogUp refusal (256 bad values). What remains for O9/O10 is writing the run's prefix up to each part (the
  blocks' cores, the commitments' Merkle trees) in this form.

**What it does not do.** The openings' completeness (L10) and each slot's arithmetic stay contracts, for the stages as
for the blocks. O12's honest-prover hypotheses (L19) are not discharged: they need the prover's `FSModel` (points
causal in values, the receipt read off the view), for which the transcript programs here are the first half. The run's
zero-knowledge cap `R ≤ 2^112` (L19-2) stays; it is your ruling.

**One thing worth knowing (finding L29-3).** Stage IN-C's LogUp refusal ("zero LogUp denominator; discard attempt")
is checked after the embedding challenge `r_emb` is drawn, and the table it compares `α` with depends on `r_emb`. So it
is not a refusal at `α` with a fixed bad set, as L18's site list has it; it is about thirteen sites (one per `r_emb`
coordinate, plus one at `α`) of at most `V = 2^17` bad values each, about `2^20.7` in total at Shieldstral. Still deep
inside the `2^85` budget; no statement changes.

PLACEHOLDER_REST
