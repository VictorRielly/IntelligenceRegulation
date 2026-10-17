# Deferred owned witness planes

Cycle0061, run20261017T112624Z-88d6b64e, seed2026101761.
The experiment and candidate are entirely inside research. No native build,
proof, GPU, dependency installation or fresh receipt verification ran.

The pinned R3 witness builder allocates every non-histogram i64 plane zeroed,
then replaces30 plane vectors plus16 norm-limb vectors with owned results.
Each producer already returns a full padded vector. The candidate leaves
only those46 initial slots empty. Every scatter-written plane keeps its
original zero-filled domain, including the exponential plane and its later
full padded pass. Three histograms remain empty. Producers, padding, arithmetic,
refusal order and every later statement/commitment call stay in place.
This differs from cycle20's Fp A-matrix assembly and cycles17/18's lookup readers.

`run.py` parses the pinned Ids segments and compares them with an independent
family catalog. A restricted first-use recognizer checks that each deferred
plane is first accessed by its full move; manual inspection covers the
builder's aliases. This is not a Rust parser or a native safety proof.
72 synthetic assembly fixtures compare eager allocation, deferred allocation
and a separate sparse last-write reference:5928 plane checks and293384
word comparisons. Variable two/three score and probability limbs exercise
moving IDs; probability-limb variants are robustness fixtures, not admitted
profiles. Full producer vectors deliberately contain arbitrary padded words
so that zeroing their pads cannot accidentally pass. Scatter gaps and the
second complete exp pass are preserved. Seven controls cover premature reads,
misclassified scatter planes, missing/short moves, corrupted untouched pads,
missing exp completion and the source first-use guard.

Only the final sources and results are authoritative. The first catalog
assertion failed by counting unnamed limb IDs as named constants; its log and
reconstructed source are retained. A later diagnostic census used an assumed
f_e=10 and a generic8B row width; its result is retained under
initial-fe-assumption. Final census uses the source/owner ladder's f_e=9,
TinyLlama row widths12/13/14 atT32/64/128 and8B T32 width13. Larger row widths
are an explicit count-only continuation, not admitted or benchmarked profiles.

Final local run and independent audit clocks are in result.json/audit-result.json.
Each runs one nice19 CPU0 thread on Intel Core Ultra9 185H,59s wall/CPU and
512MiB AS caps,96MiB estimated. Standard-library Python only. Commands and
source hashes are retained. The audit independently evaluates12 closed-form
payload counts, reconstructs the single-hunk patch and checks retained pins.

| Counted geometry | Final i64 planes MiB | Avoided initial allocation payload MiB | Final capacity reduction |
|---|---:|---:|---:|
| TinyLlama T32 |46.204|24.438|0|
| TinyLlama T128 |217.816|103.754|0|
| TinyLlama T256, count only |555.633|223.508|0|
| Llama3-8B T32, f_e9 count |90.392|49.126|0|
| Llama3-8B T512, count only |2234.266|906.016|0|

These are logical payload/aggregate allocation counts, not measured RSS,
physical zero stores, peak savings or speedups. The allocator/compiler can
avoid touching initial zeros. Overlap depends on producer batches and scratch;
the sum of avoided allocations is not simultaneous peak memory. The final
witness still exists when prove_core allocates A, looked columns and H.
This patch alone does not remove those proof-stage allocations or establish
that T256 fits. The three cloned D-plane payloads total6MiB atTinyLlamaT128;
sup_s holds4MiB of indices. Neither removal is in the patch.

Added cost: one small public moved-plane flag vector and46 fixed ID marks,
branching in the existing initialization map, and maintenance when the plane
catalog changes. There is no hidden-value-based dispatch, uninitialized read,
unsafe code, mask reuse, changed normalization rule or removed constraint.
Candidate Rust is unapplied and uncompiled. Actual native gates remain owed.

Six retained owner R3 TinyLlama22-block diagnostics match fresh-verifier
identity/size logs, successful guard records and completion markers; files
were inspected, not rerun. All are n=1 cold processes with16 Rayon threads,
CPU or RTX4070Laptop assistance. AtT128 GPU:142.783399s enclosing wall,
12.872s witness/extraction/parity,107.079s prove_run minus witness (still
includes endpoint work, serialization/sink),8.742s in-process verify and
8.451s separate verifier (11.307s additional model load),497665904bytes.
Load9.393s is6.5785% of enclosing wall, not isolated startup. Pure startup,
serialization and steady-state slope are unknown. Diagnostic128/wall=0.89646
positions/s; these are no accepted private8B target tokens. Deleting the
entire witness clock at zero cost yields only1.09908x (~0.9853positions/s).
R2/R3 calibration/export identities differ, so their gross timing change is
not a controlled optimization A/B.

8B end-to-end ceiling remains N/(T_complete - saved_native_time + added_cost),
with all terms unmeasured. Falsify on native witness/padded-word/first-refusal
divergence, transcript/RNG/receipt changes, or no enclosing gain. Capacity
requires lower actual maximum, not fewer aggregate allocated bytes.

See the research handoff for the native integration seam and validation gates.
No accepted8B proof/pass/token exists; context and all8B clocks/rates are null.
No resident sweep, decode or new long-context proof ran. Longer dense context
still has quadratic attention work. The50-token/s target is unchanged.
