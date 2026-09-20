# ZK60 — the RUN gate (Python privacy-consistency gate for a multi-block run)

**Lane** `zk60-native-jointview`, worktree `/home/victor/wt-zk60-jointview`.
**Opened** 2026-09-20 12:30 PDT. **Sole writer**: this lane's agent.
Python only — no cargo, no builds, no GPU. Nothing here is a privacy
acceptance, and no statement here establishes a privacy property.

## 0. What this lane is building

A NEW tool, `scripts/zk60_native_run_gate.py`, that reads a RUN CAPTURE
bundle (schema `hashline-native-capture/4-run`, written by the Rust lane
`zk60-private-block-125m`) and computes, for a whole multi-block run:

1. load + integrity (manifest hashes, schema, sizes against `run.json["shape"]`);
2. the Fiat-Shamir transcript replay of every stage, in run order;
3. per stage, per commitment: the disclosed dimension by exact rank, the
   certifying minor, distinct opened columns against the pad count;
4. **the boundary** (ruling M-8): per boundary, its figure RESTRICTED to its
   reserved rows; the three-role joint figure (A_k, B_k, A_{k+1}); the
   whole-run figure or the largest sub-system computed;
5. negative controls, each shown to pass honest and fail perturbed;
6. channel labels (CONSTRUCTED / DERIVED / ARGUED / OPEN) for a run;
7. evidence under `results/zk60_native_run_gate/` and the report
   `docs/zkmatrix-poc/ZK60_NATIVE_RUN_GATE.md`.

Inputs, READ-ONLY, from the lane worktree (never copied into this repo):
`/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920/run-a-tame/`
and `.../run-b-zero/` — two independent honest three-block runs at the
development rung (24 tokens, width 96, hidden 192, 6 q-heads over 2 kv-heads;
1024 columns, inverse rate 4, 256 opened columns).

Rule taken from the brief and kept: the four TOY bundles' gates
(`zk60_native_joint_view.py`, `zk60_native_privacy_gate.py`) and every module
they hash into their evidence are NOT edited. Shape-driven variants live in
new `zk60_native_rg_*.py` modules; shape-agnostic code
(`zk60_native_jv_field`, `JointSystem`) is imported.

## 1. Status

| # | item | state |
|---|---|---|
| S0 | ledger, skeleton, baseline test count | done |
| S1 | bundle loader + integrity (`zk60_native_rg_bundle.py`) | done |
| S2 | run transcript replay (`zk60_native_rg_replay.py`) | done |
| S3 | shape-driven per-commitment view (`zk60_native_rg_pcs.py`) | done |
| S4 | the boundary: reserved-row figure, three-role joint, run-wide | done |
| S5 | negative controls | done |
| S6 | channel labels for a run | done |
| S7 | both bundles run, evidence, report | done |
| S8 | tests green, toy gates unchanged | done |

## 2. Commands and logs

| what | command | log |
|---|---|---|
| baseline tests | `python3 -m unittest discover -s /home/victor/wt-zk60-jointview/tests -p 'test_zk60_native*.py' -v` | `results/zk60_native_run_gate/tests_baseline.log` |
| tests after | same | `results/zk60_native_run_gate/tests_after.log` |
| the gate, run A | `python3 scripts/zk60_native_run_gate.py --bundle <run-a-tame> --evidence results/zk60_native_run_gate --name run-a-tame` | `results/zk60_native_run_gate/run-a-tame.log` |
| the gate, run B | same with `run-b-zero` | `results/zk60_native_run_gate/run-b-zero.log` |
| toy joint-view gate, re-run | `python3 scripts/zk60_native_joint_view.py --captures results/zk60_native_captures_20260919 --evidence /tmp/.../toy_recheck` | `results/zk60_native_run_gate/toy_unchanged.json` |

## 3. Findings

(kept current; see §5 NEXT)

## 4. What this lane does NOT show

Linear channels of two captured three-block runs at ONE development shape.
Nothing about the 125M shape. The hash layer is argued, not computed. The
joint-law composition for a run is unwritten. NOT a privacy acceptance.

## 5. NEXT

S0: ledger committed; baseline test run in flight.
