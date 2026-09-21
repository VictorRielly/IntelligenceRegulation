# The D22 re-read and re-pin at the integrator's `4751b93`

Lane `zk60-native-jointview`, worktree `/home/victor/wt-zk60-jointview`,
opened 2026-09-20 21:35 (PDT). Sole writer: one delegated Opus auditor
working for the security owner. PYTHON ONLY — no cargo, no build, no GPU.

**What this is.** Register entry D22 accepts the privacy of ONE artifact,
the toy private-block profile `hashline-zk-mr1/private-block-t32-poc/1`.
Its statement (`ZK60_PRIVACY_STATEMENT_TOY_PROFILE.md`) rests at step 3 on
Python gates that replay real receipts and CONSTRUCT blinding preimages;
those gates are PORTS of Rust functions, each guarded by a SOURCE PIN.
Condition 7 of §5: *a change to any pinned Rust file suspends step 3 until
the file is re-read and re-pinned.* At 20:52 on 2026-09-20 the integrator
committed `4751b93` on `perf/zk-batch-optimizations`. This page is the
independent reading that condition 7 demands: the pin inventory, the
hunk-by-hunk classification, the per-function verdicts, the pooling
analysis, the decision per file, and the gate re-run.

**Nothing here is a privacy acceptance.** The security owner rules on
whether D22's step 3 resumes; this page is the reading it needs.

## 0. Status

| # | item | state |
|---|---|---|
| W0 | skeleton ledger | PENDING |
| W1 | pin inventory: every pin of every toy gate tool, at the pin commit, at `4751b93^`, at `4751b93` | PENDING |
| W2 | the re-read: every hunk of every moved or on-path file classified | PENDING |
| W3 | pooling / reuse and draw-order analysis ("private host reuse") | PENDING |
| W4 | decision per file | PENDING |
| W5 | the gates re-run on the four toy captures against the committed records | PENDING |
| W6 | the RUN gate's pins; what is owed at the lane merge | PENDING |
| W7 | whole native suite | PENDING |

## 1. Pin inventory

PENDING.

## 2. The re-read

PENDING.

## 3. Pooling, reuse and draw order

PENDING.

## 4. Decision per file

PENDING.

## 5. The gates re-run

PENDING.

## 6. The RUN gate's pins

PENDING.

## 7. What is and is not established for the new tree

PENDING.
