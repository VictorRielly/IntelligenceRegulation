# Fixing the joint-view gate's stage 4 (ruling G-1), re-pinning `mle.rs`,
# and printing the certifying minor — lane ledger

Lane: `zk60-native-jointview`, worktree `/home/victor/wt-zk60-jointview`.
Opened 2026-09-20 00:58 PDT by a delegated agent working for the security
owner. Python only; no cargo, no GPU. Sole writer in this worktree.

**Nothing in this lane establishes a privacy property.** The joint-view gate
is a consistency gate over an explicitly stated linear model at four real
captures' challenges. The project's open obligations (D8/D11 endpoint roots,
the nonlinear terminal link, the salted-leaf and Merkle channels) are
untouched.

## 0. The three jobs

| Job | What | Status |
|---|---|---|
| JOB 1 | Re-pin `zkp-core/src/mle.rs` at the integrator's proved-equivalent row-fold commit (4bf1fa0), after re-reading every ported function; rerun the gate and the tests | not started |
| JOB 2 | Ruling G-1: stage 4 hard-codes `joint == sum` and cannot fail. Replace with a genuine joint computation over the union of the receipt's commitments, with shared coordinates identified; three negative controls | not started |
| JOB 3 | Print the certifying minor per role per capture (indices, determinant, g, G, rank) and the distinct-opened-columns vs pad-count check | not started |

## 1. Status table

| Step | Command / artefact | Result |
|---|---|---|
| (to be filled) | | |

## 2. Findings

(to be filled)

## 3. NEXT

Start JOB 1: merge `perf/zk-batch-optimizations` into the lane branch, read
the new `mle.rs`, re-pin, rerun.
