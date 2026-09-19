# Independent review of Fable's joint-view delivery — 2026-09-18

**Disposition: useful algebra and replay diagnostics; external-root and full
adaptive privacy acceptance remain open.** Reviewed immutable delivery:
`679ac264c14727e5ea98e499f42f9d1922ece40c` on `zk60-mvp-fable`, based on
`763e308`. No production protocol code is changed by this review.

## Concrete failure of the proposed root simulator

The delivery's `docs/zkmatrix-poc/ZK60_MVP_JOINT_VIEW.md:25` asserts that
knowing the honest endpoint tree's top pair requires secret salts or a
negligible guess. A previous **public authentication path** already reveals
that pair: recompute the child on the path and take the last sibling as the
other child. No private owner export or unopened-column secret is required.

The delivered `scripts/zk60_root_simulator.py:269` programs a different,
fresh top-pair input to the existing root. The observer can now exhibit two
distinct inputs hashing to that root. More genuine paths keep the original
pair. The simulator's fresh-input refusal does not fire: it guards the new
input, not whether a preimage of the same output is already public.

This is a distinguisher for the **proposed simulator** with allowed prior
public history. It is not an endpoint-recovery attack, a BLAKE3 collision
attack, or a demonstration that every possible simulator must fail. The
fresh-owner preparation experiment is different from the general fixed-root
experiment; its consuming API does not erase previously public information.

The delivered control at lines 404–411 already demonstrates a collision
distinction when supplied `secret_top_pair()`. The regression here obtains
the same information by ordinary path verification and forbids both secret
export helpers. It exposes only one genuine path before simulation. Every
path verifies, the observed root preimage count changes from one to two,
and the simulator does not refuse. The unchanged-genuine-tree control and
the no-prior-history control each retain one observed preimage.

Run the bounded regression:

```
python3 -m unittest discover -s tests -p test_zk60_root_history_boundary.py -v
```

It loads the exact delivery with read-only `git show`, checks source SHA-256
`248bc58ed0df390487d03581c78e33d539ff7a2acae3833b059dbf59bb334717`, and
explicitly skips if that immutable commit is unavailable. Missing delivery
evidence is not reported as successful reproduction. The ideal-oracle tool's
columns are bookkeeping values, not a production PCS-distribution sampler;
the inference here concerns its hash/history argument only.

Validation on 2026-09-18: all three focused regression/control tests executed
and passed in 0.068 seconds; none skipped.

## What the new algebra establishes

The sequential-kernel lemma in the delivery's memo, line 34, is valid for
the stated causal message rules when the **complete joint** message law is
witness-independent under **every forced challenge vector**. The earlier
marginal-law counterexample does not contradict that strengthened lemma.

The joint PCS column elimination and the CFS/M elimination are useful
progress. A proof need not build one enormous dense matrix: conditional
composition can suffice when CFS masks are independent and the conditional
law is shown uniformly over the full PCS interface. Nonlinear dependence of
honest sumcheck polynomials on PCS randomness is then not itself fatal.

The application of the lemma nevertheless remains incomplete:

- The memo at line 65 explicitly leaves the argument for other challenge
  vectors open. Four actual captured vectors do not establish its universal
  premise. Replay authenticates schedule and coefficients; it is not that
  distributional argument.
- `scripts/zk60_joint_view.py:35` excludes hash objects, adaptive dependence
  and CFS messages. `scripts/zk60_joint_cfs_view.py:1094` conditions on PCS
  terminals. A full argument must combine those conditionals with roots,
  paths and the observer's oracle history. Salted-leaf hiding alone does not
  justify deleting those correlated objects from the view.
- The CFS tool defines `want = final - c * eval` at lines 274–276 and
  substitutes it back at line 289. This does not independently check the
  actual FFN terminal polynomial. The memo acknowledges the limitation;
  the source-level link from the conditional model to that polynomial is
  still required.

Thus the memo's lines 30, 59 and 63 overstate closure. Its retained
`full_privacy_review_complete: false` remains the appropriate status.

## Necessary next construction work

Retain the fixed-root/history obligation and retract the two-point closure.
A repaired ROM simulator would need to retain previously exposed tree nodes
and paths, and simulate consistently below their public frontier, jointly
with prior field observations. That is a new stateful construction.

Alternatively, prove knowledge of the exact endpoint openings and the
complete computation inside an established general-purpose ZK argument.
The endpoint tree and paths then remain private witness computations. If
compatibility with existing PCS statements is claimed, compute those exact
BLAKE3 roots; a separately versioned salted-SHA profile is a new statement
format and does not certify the old protocol.

Private-attention schedule work can continue as experimental engineering.
This delivery does not establish the privacy prerequisite for accepting the
custom private block or the model-scale MVP.
