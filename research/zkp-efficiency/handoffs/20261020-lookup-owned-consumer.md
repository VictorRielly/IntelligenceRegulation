# Review handoff — owned lookup-layer buffers

2026-10-20, cycle0106, `20261020T141854Z-e43b78d7`. Research candidate; main/Claude reviews and
integrates. No native patch or merge. No proving speed improvement measured.

Result: top16 per-column8B T128 modeled arrays148.005->68.029MiB, still
3.870/3.885x treework and5.664x leaves. Full cache208.005->192.029MiB.
Original arrays/checkpoints cannot be mutated or treated as owned scratch.

Interface/patch location: research experiment
`experiments/lookup-owned-consumer-20261020/owned.py` exposes
`serve(read,n,b,p) -> (depth,OwnedPlanes,immutable_cache,counters)` and
`consume(OwnedPlanes,point,challenges,lambda,p) -> (claim,cubic_rows,terminal,folded,counts)`.
An eventual Rust adapter should return four new owned `Vec<Fp2>` planes;
regeneration writes directly, retained checkpoints copy explicitly. Consume
the owner once and drop it before requesting another layer. Two fixed-capacity
suffix equality tables plus scalar prefix replace dense equality; no inverse.
Python provenance labels are a test convention, not memory-safety evidence.

Actual native seam, read only: frozenR9
`hashline/src/private_block/protocol.rs:712` denominator cache and`:850`Hwriter;
`shape.rs:1994`lookup counts/`:2054`sites; `layout.rs:794`ordered queries;
`argument.rs:934`paired-helper relation andSC_TAB. A new private versioned GKR
protocol would replace rather than simply delete the corresponding helpers.
No Rust/CUDA adapter is ready, and no drop-in compatibility is claimed.

Validation: 3383probe checks/244consumers; independent260allocation
schedules/1300cost mutations/90direct original-MLE cases/9pins. All ordered
full-source scans, degree3 rows/terminal/plane finals match immutable and basis
oracles. Zero/one challenges and zero equality factors exercised. Original
cache/source unchanged; alias/borrow/reuse, altered arithmetic, zero denominator
at zero multiplicity and histogram controls retained. Wrong-site root
permutation still passes a root; ordered binding is not optional.

Run commands, seeds, source/code manifests, capacity census and limits in
experiment. F65537 unmasked arithmetic only; no native field/FS/transcript,
masking, receipts, CFS/PCS, privacy/refusal proof or GPU result. The model omits
all original A/model/otherH/M/commitments/masks/device/concurrent storage.
No symbolic large arrays allocated. Full-cache copies remain counted.

Unresolved: construct reviewed masked rounds, private root/terminal/ordered A
binding, one pre-challenge global histogram, soundness/site accounting and
all denominator refusals. Keep every root/intermediate private and fresh
randomness per proof. Current R9N-r9-a/b,DDgate,D32,D33/D34/D35 scopes apply.
No reused mask/opening, revealed roots or weakened privacy authorized.
Need actual exclusive/enclosing clocks/capacity and measured source traffic;
reject mismatch or full-workload regression. Even free deletion<=1/(1-f),f
unknown, so no numeric50/s ceiling. FZC compiler A/B remains higher priority.

Next local: test a bounded tiled first-round consumer that combines ordered
regeneration with a small fold prefix, and explicitly prices subsequent source
rescans/reconstruction. Compare all original-MLE sample rows and terminal
values under0/1/nonbinary challenges. Reject any plan that loses the full
ordered leaf relation or silently reuses private openings. Do not assume the
64MiB whole-layer arrays are a universal streaming-GKR lower bound.
Next owner: complete GPU phase/capacity clocks, verified fixed-context
resident1/2/4/8 passes and all-eleven FZC compiler A/B under shared locks.

