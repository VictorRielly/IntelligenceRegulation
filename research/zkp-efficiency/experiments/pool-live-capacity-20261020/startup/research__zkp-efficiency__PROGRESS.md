# ZKP efficiency progress

Cycle0091 complete — `20261019T231854Z-28e6b36b` —2026-10-19 UTC.

**No speed improvement measured.** Original Vec/System allocation probe
confirms shorter overlap in a scalar pad analogue:largest reduced fixture
419200->304384B peak requested,identical outputs at Rust opt0/3. Same36
allocations and482848B total.80 regions;independent audit1389 checks,720
corruptions,240 event mutations,32 reference/clone negatives. Native loader,
Rayon,RSS/VRAM and enclosing-time gains remain unknown;patch unbuilt/unapplied.

New verified complete proofs/passes/positions **0/0/0**;device/context none.
New witness/proof/serialization/verification clocks,steady/total proved rates
and startup fraction unmeasured. Carried owner CPU diagnostic only:8B T128,
32 blocks,one16-thread pass,GPU off,total478.737s(0.267370 positions/s),
prove_run393.785s includes witness98.348s;fresh verify42.709s+13.681s load.
Researcher did not reverify it. No long-context,resident proof series or
decode ran;larger workloads allowed,attention may grow quadratically.
Complete private8B >=50 proved positions/s on RTX5090 remains unachieved.

LIVE search covered GPU NTT/commitments,sumcheck/GKR and Rust allocation
semantics;new older register-file scheduling lead screened. Sources and
access/cache blockers saved. Seam:load_layer_mode aw/fw;owner owes native
gates/clocks. Next local:existing GPU pool live+idle capacity audit;whole-
prover GPU and verified resident1/2/4/8 remain first. No mask/opening reuse.

[Experiment](experiments/vec-allocation-scopes-20261019/README.md),
[handoff](handoffs/20261019-vec-allocation-scopes.md),
[dated report](progress/20261019T231854Z-28e6b36b.md). Only research changed;no delivery implied.

Final provenance gate230 checks PASS;10 primary source records saved.
Checkpoint 2026-10-19T23:30:19.251633+00:00;owner status update reviewed.
