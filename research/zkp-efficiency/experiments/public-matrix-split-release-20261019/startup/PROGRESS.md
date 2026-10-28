# ZKP efficiency progress

Cycle0088 complete — `20261019T201854Z-ec298e23` —2026-10-19 UTC.

**No speed improvement measured.** Public raw-array release matches78 accepted
synthetic sealing/reload paths and6720 mutation-path controls. Independent
audit reconstructs all public bytes/hashes/metadata and checks first errors.
Main/audit: 7.810/0.274s,40304/34256KiB,
one low-priority CPU thread. The21-line Rust patch is unbuilt/unapplied.

At8B T128,the modeled sealing public-payload envelope falls63.875MiB with1
hash worker or208.010MiB with16. The16-worker/current+next/four-pin envelope
falls2.016689->1.813554GiB. **Reload peak saving is0B.** Actual RSS/VRAM,
elapsed savings and complete model memory remain unknown.

Carried owner R8 diagnostic: trained8B T128,32 blocks,one16-thread CPU
pass,GPU off,n=1. Total478.737s =>0.267370 positions/s diagnostic;
prove_run393.785s includes witness hand-over98.348s,including17.595s
block-load tasks. Sealing wall84.824s contains overlapping load/witness
tasks27.151/80.897s. Do not add nested/overlapped clocks. Receipt922711264B.
Fresh verify42.709s plus initial public load13.681s; recheck34.395s plus
10.739s load. Fresh guard wall165.982s includes controls. Startup fraction,
isolated serialization and steady slope remain unmeasured. Researcher did
not reverify the receipt; no new target credit.

New independently verified full-stack proofs/passes/positions: **0/0/0**;
device none; no proof context or workload ran. Steady-state and total-workload
proved rates, startup fraction, and new witness/proof/serialization/verification
clocks are unmeasured. Synthetic cases are validation paths, not proof passes.
No long-context prefill, resident proof series or decode ran. Longer workloads
remain allowed; dense attention can grow quadratically with context.
The complete private8B / >=50 proved positions/s target on one RTX5090 or a
named high-end GPU remains unchanged and unachieved. No masks, private
commitments or openings were reused.

Seam:load_layer_mode after BlockPublic::new,before LayerRecord hashing.
Next local: release9 raw matrices after padding,before constructors,with
exp/act retained through their reads. Owner native gates/clocks are owed;
whole-prover GPU and verified resident workloads remain first.

Eight LIVE sources recorded:Jolt/Atlas streaming and actual license,
October16 Zippel index,composition/sublinear-space,zkLLMPoT,and Rust drops.
No external performance reproduced. Only research changed.

[Experiment](experiments/public-raw-last-use-20261019/README.md),
[handoff](handoffs/20261019-public-raw-last-use.md),
[dated report](progress/20261019T201854Z-ec298e23.md). Saved reports do not establish delivery.

Final consistency/provenance gate PASS: 261 checks,18 unchanged source/evidence pins,14 frozen R8 manifest matches;two patch hunks applied in memory only. No native compile/proof. Final checkpoint 2026-10-19T20:28:11.449367+00:00.
