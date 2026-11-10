# Lane L44: the brief each host fork follows (scratch, kept as evidence of the work split)

Each host fork proves ONE host's named identity (lane L36's `FormAt`) at the W16R2 rung, by L41's `formAt_tzc` pattern,
on the shared tools of `formal/ZK60Formal/BlockHostBase.lean` (frozen once green).

Rules for a fork:
* Files: only `formal/ZK60Formal/BlockHost<Tag>*.lean` (Tag = `Dzc`, `Qkv`, `Szc`, `Fzc`); every new declaration in
  namespace `ZK60.Exec.Block.Join.W16.<Tag>` (no clashes between forks). Do not edit `BlockHostBase.lean`, any existing
  Lean file, the root `formal/ZK60Formal.lean`, or any other fork's file. Do not commit (the main agent commits).
* Iterate with `results/zk60_lean_l44_20261110/run_guarded.py lean-l44-<tag> <OUT>/<tag>_iterN.log
  <OUT>/<tag>_iterN.done /bin/bash <OUT>/iter.sh <OUT>/<tag>_planN.txt`, run in the background, waiting for its
  notification; plan lines `lean <abs path of your file>` (type-checks one file against built imports) or
  `build ZK60Formal.BlockHost<Tag>` (produces the olean, needed only if a second file of yours imports the first).
* Hygiene: no `sorry`, `axiom`, `native_decide`, `admit`, `maxRecDepth`, `maxHeartbeats`, `implemented_by`,
  `@[extern]`, `bv_decide`, `ofReduceBool`, even in comments. Numeric facts by `decide` / `rfl` on the rung's
  configuration are fine (L41 did so). Never weaken the interface; if a premise turns out unmeetable, stop and report.
* The interface theorem's statement is fixed (below); deliver it green, plus the `xc<Tag>` (and `pw<Tag>`) definitions
  with the signatures given.
