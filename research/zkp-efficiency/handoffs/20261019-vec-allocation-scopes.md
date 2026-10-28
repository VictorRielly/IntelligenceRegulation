# Owner handoff — original Vec allocation-scope evidence

20261019T231854Z-28e6b36b;2026-10-19 UTC. **Capacity evidence only;no speed gain measured.**

Interface unchanged:`Array::i8s()->Vec<i8>` and pad_matrix outputs. Frozen R8
TrainedExport::load_layer_mode aw/fw initializer seam. Patch location:
experiments/vec-allocation-scopes-20261019/prior-review-only-statement-scopes.patch
(copied cycle0090 diff). Production diff remains UNBUILT/UNAPPLIED.

New validation:Rust1.90 opt0/3 original Vec/System allocation events,8 synthetic
shapes x5 modes x2 builds=80 regions. Independent destination oracle and event
formulas:1389 checks,720 corrupted vector controls,240 event mutations,32
reference/extra-clone masquerades. Largest reduced proxy peak419200->304384B;
same36 allocations/482848B total. All output bytes equal. Source and binary
pins,commands,seed2026101991,logs,synthetic output bins and hardware retained in
experiments/vec-allocation-scopes-20261019/. No custom decoded Drop/black_box.

Limits:scalar row analogue,not native Rayon;System requested sizes,not usable
capacity/RSS/VRAM;optimizer may elide allocations in other builds. Unchanged
standalone loader modeled saving0B;112.003906MiB target pad overlap and prior
move/release composition are models only. Same total work/free count remains.
All-load-deletion bound1.103104x is much broader than this candidate,CPU only.

Owner action:review/rebase with checked moves/raw release,run native full/
reload byte/first-refusal/record/receipt/source-freshness/CS/H-1 gates,and
measure actual allocator live/peak plus enclosing clocks under shared locks.
Reject changed bytes/refusals/lifetime,whole-loader peak erasure or elapsed
regression. No private masks/commitments/openings reused;no privacy scope
promotion. New verified proofs/passes/positions0/0/0;50/s target unachieved.

Next local work redirects to the existing GPU buffer pool's simultaneous
live+idle capacity,not another loader variant. Whole-prover device and
verified resident1/2/4/8 workloads remain the main end-to-end priority.
