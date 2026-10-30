# Native slot batching compatibility boundary

Research only. No production patch, scheduler port or proof redesign is supplied.

The pinned R13 `private_block/argument.rs::argument` calls `define` then
`run_slot` on one mutable transcript. `run_slot` absorbs the slot index,
draws a nonzero CFS multiplier, publishes the mask-bearing scalar, executes
masked main/extension rounds, refuses extension challenges 0/1, and absorbs
the ordered private terminals. Only then does the next definition run.
The transcript hashes both the previous state and a counter and folds each
challenge back into that state. The current whole-slot schedule is serial.

The reviewed ledger has sixteen named point dependencies and twelve host
dependencies. `QMM` writes the row point read by `KMM`/`VMM`; `WO` overwrites
that field. `GMM` writes the point read by `UMM`; `DMM` draws its own row
point. Six hosts each bind two distinct earlier private slots. R13's seven
replacement definitions and the optional appended dictionary slot are
included in the source inspection. The two bilinear slots keep two separate
extension rounds, unlike ordinary slots with one.

At 8B/T128 there are 24 equal-shape pairs, all ordered by the native transcript.
A counterfactual with transcript edges omitted has 21 pairs without the
reviewed point/host dependencies. That is only a necessary-condition screen:
it establishes neither a valid aggregate polynomial nor soundness/privacy,
compatibility, lower memory or better performance. Equal total round count
does not make different main/extension schedules equivalent.

The mask and claim obligations survive any future proposal:

- Every slot uses its own CFS mask; a host's Gamma combines its own mask
  total with the earlier hosted multipliers/mask totals in the declared order.
- Every private table claim retains its commitment, slice, ordered point,
  reserved mask pair and extension-round identity. A shared sampled point
  never licenses shared private blinding.
- Every terminal stays bound through the same A/H/endpoint claims and M
  functionals; endpoint boundary pairs remain disjoint between stages.
- All original refusals, source-claim binding, full attention/FFN coverage,
  fresh per-proof randomness, independent verification and privacy gates apply.

The experiment executes eight unchanged shape metadata methods under small
stub fields, plus a reviewed event ledger and graph analysis. It executes
neither native `define` nor any cryptographic function. It is not a general
Rust parser. Point-field and exact-anchor checks constrain source drift but
are weaker than executing all definitions and their relations.

Next bounded experiment if native clocks remain unavailable: model two to
four separate proof transcripts at a round evaluator interface with synthetic
Fp2 tables and distinct challenges, compare against scalar references, and
reject swapped per-proof challenges, mask/site IDs and early buffer reuse.
Use no shared challenges, masks or private caches. Such a batch may reduce
launch overhead across independent contexts while preserving each proof;
its actual work/peak capacity/critical-path incidence must be measured first.

The concrete GPU interface to inspect is
`hashline/src/gpu/cuda.rs::dev_zerocheck_blocks`, which currently accepts one
`&mut Transcript`. Its `nb` is not evidence of independent proof transcripts.
An eventual multi-proof API needs separate state and result ownership for
each proof; no such API or safe port is established here.

Owner priority remains complete, independently verified high-end GPU
resident-model workloads at fixed context with 1/2/4/8 passes, actual capacity,
startup/drain, exclusive phases and all failures. Do not treat modeled
parallelism as saved critical-path time. Native owner/Claude reviews and
integrates future work; nothing is merged here.
