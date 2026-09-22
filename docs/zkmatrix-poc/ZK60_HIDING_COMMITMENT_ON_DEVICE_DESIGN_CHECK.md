# The hiding commitment on the device — the independent adversarial check

By an independent Claude Fable 5.1 adversarial checker for the security
owner, 2026-09-22 12:55. The subject is
`ZK60_HIDING_COMMITMENT_ON_DEVICE_DESIGN.md` (975 lines, commits
`5b2a2ef`..`d12ba3f`), a design offer for computing the prover's hiding
commitments on a GPU byte-identically to the CPU.

**The rule this check was run under: assume every claim is wrong until it
has been re-derived by a different method.** Nothing below is taken from the
memo's own scripts; where I use them at all, it is to compare with a number
I computed first, and that is labelled. No Rust was built, no GPU was
touched, no heavy job was run.

Labels as in the memo: **[COUNTED]** is mine, from the code or the shape,
by the two scripts in `results/zk60_device_commit_check/`; **[MEASURED]**
only from a committed log with its path; **[MODEL]** estimated. No number
here is a proving-time prediction.

Sources read: the lane `/home/victor/wt-zk60-block125m` at `a8e4939`
(`zkp-core/src/{pcs.rs,merkle.rs,hashtag.rs,ntt.rs,field.rs,rng.rs}`,
`hashline/src/zk.rs`, `hashline/src/private_block/*`), the main tree at
`d12ba3f` (`hashline/src/gpu/{cuda.rs,kernels.cu}`), the vendored crate
`blake3-1.8.7`, and the lane's layout models and timing logs.

---

## 0. Verdict per section

| memo section | verdict | the number that moves |
|---|---|---|
| §1 byte contract, steps 0-9 | **holds** — re-derived line by line, every citation checked | — |
| §1 step 10 (the opening) | **one step out of order** (DC-3) | the proximity rho is drawn BEFORE the clear vectors are absorbed, not after |
| §1 "exactly what differs" | **overstated** (DC-4) | four differences, not three; the fourth is the accelerator offer |
| §2 receipt reconciliation | **holds, digit for digit** — independently reproduced at all three shapes | — |
| §2.2 compressions | **wrong number** (DC-1) | 112,066,560 column digests / 112,590,844 total, not 112,197,120 / 112,721,404 — and the memo's own `counts.json` says 112,590,844 |
| §3 chunked peak (the 8 GB headline) | **holds exactly** | 1,909,852,144 B and 1,753,614,336 B both reproduced to the byte |
| §3 resident-arm peaks | **missing buffer** (DC-2) | +`rows·n·8` at every commitment: 125M `H` 8.71 GiB not 7.84; rung-W14's whole commit phase 1.20 GiB not 0.80 |
| §4 keyed kernel | **holds** — recipe confirmed complete against the crate, trap boundary confirmed at 129 rows | (DC-11, DC-12 are citation nits) |
| §5 private bytes | **missing buffer** (DC-5) | the pinned host staging pair, 128 MiB, which the note the memo quotes names explicitly |
| §6 test plan | **holds**, but see DC-6 | the verifier sees 0.391% of the kernel's output |
| §7 Amdahl arithmetic | **holds — every digit exact** | — |
| §7 framing | **overstated** (DC-7, DC-8, DC-9, DC-10) | "both free → 4.307 s" is ~9.6 s end to end |
| §8 "cannot pass silently" | **overstated** (DC-6) | caught with probability 1 − (1 − k/nn)^256, not caught |
| §9 what this is not | holds | — |

**The memo is substantially right.** Its central claims — five commitments,
the receipt reconciliation, the NTT ordering trap, the keyed recipe, the
128-row boundary, one key on the device, the chunked peak on the 8 GB card,
rung-W14 not chunking, and the whole Amdahl table — all survived an
independent re-derivation. Two numbers and two inventories do not.

---

## 1. Findings

### Severity: missing private buffer

**DC-5 — §5.1 has no row for the pinned host staging buffers.** The memo
quotes the toy statement's 03:23 note verbatim, including the words
"blinding rows and pads to device **and pinned host memory**", and then
gives a table titled "What private bytes reach device memory". The host half
of the obligation it quotes is never discharged.

The path [COUNTED]: `dev_commit_zk` (`cuda.rs:3751-3764`) uploads the
witness rows with `g.upload_sync(d_data.get_mut(), as_u64s(data))`
(`:3760`), which routes through the `Uploader` (`cuda.rs:808-880`) unless
`HL_GPU_PIN_MB=0`. The `Uploader` holds **two page-locked buffers**
(`pin: [PinBuf; 2]`, `:815`), each `(HL_GPU_PIN_MB << 20) / 8` u64 elements
— **default 64 MiB each, 128 MiB in total** (`pin_mb()`, `:797-800`; the cap
at `:1053`). They are allocated with `cuMemHostAlloc` and
`CU_MEMHOSTALLOC_WRITECOMBINED` (`PinBuf::new`, `:766-772`), **created on
first use and held for the life of the process** (`Gpu::up`, `:1047-1060`).
`pin_fill` (`:790-792`) copies the caller's bytes into them; there is no
memset anywhere on that path, and the last upload's bytes sit in that
window until a later upload happens to overwrite that slice.

What is in them: the rows of `A` and `H` — which is to say the block's
activations **and the mask and proximity rows**, since the memo's own §5.1
correctly notes those live inside `d_data`. So the same argument the memo
makes about `d_coef`/`d_enc` ("returned to the pool, unscrubbed") applies
verbatim to 128 MiB of host memory that the buffer review has not been told
about. This is not a claim that it is unsafe; it is a row the inventory
owes.

**DC-2 — §3.2/§3.3's resident-arm peak omits `d_coef`, because the pool
never frees.** The memo adopts the source's own peak formula
`[rows·(n + q + 2·nn) + nn]·8` (`cuda.rs:3618-3621`) and adds the leaf array
and the twiddles. That formula counts `d_coef2` and `d_enc` but not
`d_coef`, on the reasoning that `d_coef` is dropped before `d_enc` is taken.
The drop does not free device memory:

* `Pooled::drop` calls `pool_put` (`cuda.rs:503-509`), which pushes the
  buffer onto a process-global 64-entry `POOL` vector (`:451-456`). There is
  **no `cuMemFree`** on that path.
* `Pooled::take` for `d_enc` matches by **exact length**
  (`pool.iter().position(|b| b.len() == len)`, `:437-448`). A `rows·n`
  buffer can never serve a `rows·nn` request, so the pooled `d_coef` is
  dead weight that stays resident for the whole of the expand NTT and the
  hash.
* No drain runs between the two lines. The only caller of `dev_pool_drain`
  outside `cuda.rs` is `hashline/src/zk.rs:2666` — the v3 layer path — and
  the private block's `protocol.rs` does not call it at all. Even if it did,
  it could not help: the interval at issue is inside one function, between
  `:3699` and `:3711`.

Re-derived peaks [COUNTED, `recount_device_commit.py`]:

| resident arm | memo | mine | omitted |
|---|---:|---:|---:|
| 125M `A` (5,681 rows) | 6,716,884,976 (6.26 GiB) | **7,461,505,008 (6.95 GiB)** | 744,620,032 |
| 125M `H` (7,120) | 8,417,345,520 (7.84 GiB) | **9,350,578,160 (8.71 GiB)** | 933,232,640 |
| rung-W14 `A` (527) | 626,423,792 (0.58 GiB) | **695,498,736 (0.65 GiB)** | 69,074,944 |
| rung-W14 `H` (436) | 518,889,456 (0.48 GiB) | **576,036,848 (0.54 GiB)** | 57,147,392 |

This matters most where the memo says it matters least. **rung-W14 is the
shape the memo picks as the first validation target precisely because it
takes the resident arm at all four commitments** (headline 7, which I
confirm). Its whole commit phase is 864,264,176 B (0.80 GiB) on the memo's
model and **1,289,504,752 B (1.20 GiB)** with the pool undrained — 49%
higher than the figure a reviewer would be handed. Both fit 8,188 MiB
comfortably, so the conclusion does not move; the number does.

The 125M all-resident counterfactual, 12,140,445,680 B (11.31 GiB), I
reproduce **exactly** under the memo's model, and it rises to
16,879,265,776 B (15.72 GiB) with the pool undrained across the four
commitments. Since the whole point of that figure is "1.41× the card", the
correction strengthens the memo's own argument.

**The memo's mitigation sentence does not do what it says.** "`d_coef` must
drop before `d_enc` is taken (it does today, `cuda.rs:3695`)" — the drop is
at `:3699` (`:3695` is the inverse NTT), and dropping it does not reduce
device residency. The free-order condition the memo rightly insists on is
real, but the mechanism that would make it true is `dev_pool_drain`, not
`drop`.

**What DC-2 does NOT touch:** the chunked arm. I reproduce the memo's
chunked figures to the byte — `A` 961,513,456, `H` 1,153,073,136, the
constant 204,734,448 B of scratch + state + leaves + twiddles, the
commit-phase peak **1,909,852,144 B** and the held **1,753,614,336 B**. The
chunked path takes its scratch with `take_min`, which reuses, and the
headline "1.78 GiB, 22.2% of the card" stands exactly as written.

### Severity: wrong number

**DC-1 — §2.2 and headline 2 contradict the memo's own committed
evidence.** The memo says "112,197,120 of a 125M block's 112,721,404 BLAKE3
compressions are column digests". Counting one compression per 64-byte
block plus one per parent of the chunk tree [COUNTED]:

| commitment | column bytes | blocks | chunks | compressions/column | × nn |
|---|---:|---:|---:|---:|---:|
| `A` | 45,448 | 711 | 45 | 755 | 49,479,680 |
| `H` | 56,960 | 890 | 56 | 945 | 61,931,520 |
| endpoint ×2 | 296 | 5 | 1 | 5 | 327,680 each |

Total column digests **112,066,560**; with 262,144 leaves and 262,140 nodes,
**112,590,844**. The memo's figures are 130,560 too high. My formula is not
in doubt: it reproduces the memo's own `A`, `H` and rung-W14 numbers
exactly, and the rung-W14 total 9,175,036 to the digit.

Decisive: the memo's own script already says so.
`results/zk60_device_commit/counts.json` carries
`/125M/totals/compressions = 112590844` and
`column_hash_compressions = 327680` for each endpoint. **The memo's prose
disagrees with the script it cites as its evidence.** The derived
conclusion is unharmed — the tree is 0.2328% and the leaves 0.2328% of the
total, which still rounds to the memo's 0.23% and 0.46%.

**DC-7 — §7 attaches a quoted percentage to the wrong number.** "the
checker's own ceiling with every CPU lever taken is 13.44 s, 'of which the
two commitments are 60%'". In the source
(`ZK60_SLOT_EXPRESSION_IR_DESIGN_CHECK.md:614-615`) the 60% is of the
10.79 s round-loop-to-zero floor (6.500/10.79 = 60.2%). Against 13.44 s the
share is **48.4%**. The quotation marks make the misattachment look sourced.

### Severity: wrong contract step

**DC-3 — §1 step 10 states the transcript order wrongly.** The memo writes:
"group lambdas → the clear vectors absorbed under `b"pcs-vec"` → the
proximity rho → the prox vector absorbed under `b"pcs-prox"` →
`challenge_indices`". The proximity rho is not drawn there. `open_zk`
(`pcs.rs:1023-1052`) makes ONE call, `zk_rhos(&groups, rows, tr)` at
`:1027`, and `zk_rhos` (`:943-964`) draws the per-group lambdas **and then
`prox_rho = tr.challenge_fp2_vec(rows)` at `:961`** — all of it before any
absorb. The true order is:

1. per group, `challenge_fp2_vec(members.len())` in group order (`:947`);
2. `challenge_fp2_vec(rows)` — the proximity rho (`:961`);
3. absorb each group vector under `b"pcs-vec"` (`:1033`);
4. absorb the prox vector under `b"pcs-prox"` (`:1035`);
5. `challenge_indices(num_col_checks, nn)` (`:1036`).

`verify_zk_tagged` mirrors it exactly (`:1200`, `:1212`, `:1217`, `:1218`),
which is why the proof verifies. Why it matters for THIS memo: §1 is offered
as "the acceptance list for a kernel", and §6(d) makes an independent Python
gate that re-derives the transcript the load-bearing check. A
re-implementation built from step 10 as written would absorb before drawing
the prox rho, get a different Fiat-Shamir state, and sample different
columns. It is the one step in §1 a reader cannot take on trust.

### Severity: overstated

**DC-4 — "Only the hash functions differ, at three sites" is four.** Beside
the three hash sites, `commit_zk_owned_with` offers the work to the backend
unconditionally (`backend.try_commit_zk(...)`, `pcs.rs:728`) while
`commit_zk_owned_with_tag` gates the offer on `tag.column_key()`
(`:782-785`). That is a textual difference between the two bodies, it is not
a hash function, and it is the memo's own subject. The memo describes it
correctly in step 4 and headline 8, so this is a defect in the sentence a
reviewer would quote, not in the analysis.

**DC-6 — §8's "the failure mode is a proof that does not verify — loud, not
silent" is true only for the sampled columns.** I read
`verify_zk_tagged` (`pcs.rs:1168-1270`) and confirm the mechanism the memo
describes: the path-length check at `:1190-1195`; the leaf recomputed from
the opened column bytes with the CPU's own functions,
`salt_leaf_keyed(&hash_column_keyed(col, tag.column_key()), salt,
tag.leaf_key())` at `:1248`, checked against the root at `:1249`; and the
codeword check `Σ ρ_i·col_i == Enc(v)[j]` at `:1252-1262`, which also covers
the proximity rho. A wrong digest, a permuted leaf array and a wrong
encoding all fail, as claimed.

But the verifier only ever sees the opened columns [COUNTED]:

| shape | opened | of | fraction | distinct (with replacement) |
|---|---:|---:|---:|---:|
| 125M | 256 | 65,536 | **0.391%** | ≈255.5 |
| rung-W14 | 256 | 65,536 | **0.391%** | ≈255.5 |
| toy | 256 | 2,048 | 12.5% | ≈240.7 |

A device bug confined to `k` columns that are not sampled produces a root
nobody can check and **passes**: probability (1 − k/nn)^256, which for a
single corrupted column at 125M is **99.6%**. The classes that would do it
are real ones for a hand-written kernel: a bug in the last partial thread
block (`nn` is 65,536 = 64 blocks of 1,024, so there is no partial block at
the registered shapes, but there is at any shape where `nn % 1024 != 0`); a
bug in the stream kernel's global CV-stack indexing `state[(8s+i)·nn + j]`
that only bites at particular `j`; or a `size_t` overflow that only bites at
large `j`. None of this is a soundness break — a wrong digest cannot help a
cheating prover, and the honest prover simply gets a rare, unreproducible
verification failure. What it does is **raise §6's conformance harness from
a convenience to the only total check in the list**, and that is worth
saying out loud, because `dev_hash_check` as it stands hashes `nn = 64`
columns (`cuda.rs:2933`) — one thread block, never two — so it is exactly
the gate that cannot see the bugs the verifier also cannot see. The memo
should say "caught with probability 1 − (1 − k/nn)^256" and should add a
harness case with `nn` large enough to span thread blocks.

**DC-8 — §7's denominator is the prover call, not the proof.** The cited log
says the witness build is 5.24 s and is explicitly NOT in the table
(`q28-m125-final-dense.log:6` and `:206`), and `wire::encode` is another
0.044 s printed outside the 17.401 s wall (`:157`). So "both free →
4.307 s" is 4.307 s of prover call, on top of ~5.28 s that a receipt still
needs — **about 9.6 s end to end**, against a 5 s target. For a memo whose
purpose is sizing a lever against that target, this is the most consequential
omission in §7, and it costs the section nothing to say.

**DC-10 — two bucket labels in §7 are wrong.** (a) "1.997 s of the commit
half is not the commitment" — the `M: mask commit` phase (0.021 s,
`:108`) is a third commitment call sitting inside that bucket, which the
memo's own §2 insists on counting. (b) The fifth bucket is labelled "table
builds, extension rounds, setup, frame", but `frame` (0.044 s) is outside
the wall the bucket is a residual of, and the label omits 0.295 s of
per-slot time that no `PB-SLOTSTEP` line accounts for (0.127 s of it in
slot 17 alone) plus 0.020 s of claimed sums — 19% of that bucket is
unlabelled.

**DC-13 — §2.2's scope.** "a 125M block's 112,721,404 BLAKE3 compressions"
counts the four non-mask commitments. Adding `M` (50 rows over 4,096
columns: 28,672 column-digest compressions, 4,096 leaves, 4,095 nodes)
takes the correct 112,590,844 to **112,627,707**, and a block also
compresses for the transcript and for every `ZkRng` refill. The sentence
should say "the four hiding commitments'".

### Severity: wording and citations

**DC-9 — "the three logged 125M runs".** There are ten `PB-TIMING prove
[125M private block …]` headers in the lane's results directory; four are at
the cited code state. The fourth, `q28-m125-final-zero.log` (19 minutes
after the cited run, same binary), has `A: commit` 2.985 s and a pair of
6.392 s — **below the memo's stated 3.017 s and 6.500 s floors**. Across all
ten: `A` 2.692-3.552, `H` 3.329-3.923, pair 6.321-7.475, wall 17.401-27.871.
The memo's band is the tightest available reading, and it does not say so.

**DC-11 — "the lane's locks are identical" (§4.2).** The blake3 entry is
identical in lane and main, same line numbers, same checksum
`6d9e454fc11f76977dc803893aff6304ed33d6a26efae8696573bea74baa27ae`
(`zkp-core/Cargo.lock:12-15`, `hashline/Cargo.lock:22-25`, both trees). But
`hashline/Cargo.lock` is not byte-identical: the lane adds the
`private-block-kernel-shaped` workspace member (8,666 B vs 8,566 B). Say
"the blake3 entry is identical".

**DC-12 — five line citations are off by one or two.**

| memo | actual |
|---|---|
| `b3_iv` at chunk start `kernels.cu:538` | **`:536`** (`:538` is the block loop) |
| the same in the stream kernel `:1459` | **`:1458`** (`:1459` is `n_blocks`) |
| the stream kernel's strided read `:1470` | **`:1468`** (`:1470` is `block[w+1]`) |
| `drop(d_coef)` "it does today, `cuda.rs:3695`" | **`:3699`** (`:3695` is the inverse NTT) |
| main at `78531ea` (§3, §4.1) | the brief's main is `4751b93`; I verified `hashline/src/gpu` and `zkp-core/src` are byte-identical across `78531ea`, `4751b93` and `d12ba3f`, so every line number holds |

The three `b3_iv` sites the memo enumerates per kernel are the right three
(`:530`/`:536`/`:566` and `:1452`/`:1458`/`:1482`); the file has six in
total, which is what "three per kernel" correctly means.

**DC-14 — an observation, not a memo defect.** `k_hash_cols_stream` has no
zero-length guard: `n_chunks = (len + 1023u) / 1024u` (`kernels.cu:1434`) is
0 at `rows = 0`, the loop never runs and `leaves` is never written, where
`b3_hash_column` guards it twice (`:514`, `:537`). Unreachable today
(`commit_zk_owned_with_tag` asserts non-empty data), but a keyed conformance
harness that includes the empty-input vector will find it.

---

## 2. The byte contract, re-derived

I walked `commit_zk_owned_with_tag` (`pcs.rs:769-808`) against the memo's
eleven steps. Everything below is [COUNTED] from the source text.

| step | memo | my reading | verdict |
|---|---|---|---|
| 0 preconditions | `:773-775`, canonical `Fp < p` (`field.rs:8,10`) | same | ✅ |
| 1 pads, FIRST draw | `rng.fp_vec(rows·Q)` `:777`; one `fp()` = two `next_u64()`, lo then hi, `((hi<<64)|lo) mod p` (`rng.rs:73-77`) | same | ✅ |
| 2 salts, SECOND draw | `(0..nn).map(bytes32)` `:778`; four `next_u64()` LE (`rng.rs:93-99`) | same | ✅ |
| 3 coset powers | `coset_powers` `:642-651`, assert `h^nn ≠ 1` | same (the assert is on `x` after `nn` multiplications) | ✅ |
| 4 the offer and the T-8 decline | `:782-785` | same | ✅ |
| 5 the row encoding | `encode_row_zk` `:655-674`, sub-steps 5a-5f | same, in that order | ✅ |
| 6 column digest | `rows·8` LE bytes in increasing row order, one BLAKE3 call; legacy tiles 64 (`:157-175`), tagged builds a hasher per column (`:182-202`) | same | ✅ |
| 7 salted leaf | `H(digest ‖ salt)`, two updates (`:677-682`, `:691-696`) | same | ✅ |
| 8 the tree | `build_keyed` `merkle.rs:52-65`, leaves in column order, `H(left‖right)`, depth 16 | same | ✅ |
| 9 what is kept | `:799-807`, store host-or-device (`:81-84`), encoding resident to the opening | same | ✅ |
| 10 the opening | see DC-3 | **one step out of order** | ❌ |

**The headline trap, checked against `transform` itself.** `ntt.rs:69-108`
applies the bit-reversal permutation to the **input** array in place
(`:76-87`) and then runs decimation-in-time butterflies, leaving the output
in **natural order**. So the memo's headline 3 is exactly right: a
decimation-in-frequency device NTT (natural in, bit-reversed out) permutes
the columns while every value stays correct. And the follow-on question —
"is a column index in the encoded row really the natural-order index?" —
resolves the same way: after 5e the coefficient vector is `c_i·h^i`, so 5f
computes `Σ_i c_i h^i ω^{ij} = f(h·ω^j)`, and column `j` is the evaluation
at `h·ω_nn^j` with `j` the natural index. The other three traps check out
too: `two_adic_root(k) = (7^((p−1)/2^32))^(2^(32−k))` (`field.rs:81-86`,
`GENERATOR = 7`, `TWO_ADICITY = 32`); the twiddle stride is `max_n/len` over
the **shared** table (`ntt.rs:93,98`); and `inverse` scales by `Fp::new(n)
.inv()` for `n` the size of *that* transform, after the transform
(`ntt.rs:60-67`).

**Five hiding commitments, confirmed [COUNTED].** `protocol.rs:879` (`A`)
and `:998` (`H`) call `commit_zk_owned_tagged`; the two endpoints go through
`endpoint_g.rs:280` (general shapes) or `boundary.rs:350` (the frozen toy);
the mask is `zk.rs:481` `mask_commit_tagged`, which builds its own
column-hashed, salted, keyed tree and is the one commitment that never
reaches the accelerator by construction (`zk.rs:478-480`). Five.

---

## 3. The counts, re-derived

**The receipt reconciliation holds, and I reproduce it independently.** I
rebuilt each shape's receipt from the wire format (`OpeningZk::write_bytes`,
`pcs.rs:619-638`: group vectors and prox at 16 B per `Fp2`, then per opened
column 8 B index + `rows`·8 B + 32 B salt + `depth`·32 B path) plus the
mask's own constants (`wire.rs:17-19`: `MASK_VEC 1024`, `MASK_DOM 4096`,
`MASK_PATH 12`; 50 rows from the models), and compared with the lane's
layout models [COUNTED]:

| shape | part | mine | model |
|---|---|---:|---:|
| 125M | a_opening | 21,626,880 | 21,626,880 |
| | h_opening | 17,385,472 | 17,385,472 |
| | endpoint_openings | 1,499,136 | 1,499,136 |
| | mask_opening | 243,712 | 243,712 |
| | **total** | **40,783,352** | **40,783,352** |
| rung-W14 | **total** | **16,421,048** | **16,421,048** |
| toy | **total** | **2,816,472** | **2,816,472** |

Every part of every shape agrees. The memo's claim that this reconciliation
is the evidence that §1 describes the real commitment is fair, and it is now
evidence twice over, from two independently written scripts.

Also confirmed to the byte: the four commitments' encoded matrices
6,750,208,000 B (6.29 GiB); `A`+`H` alone 6,711,410,688 B; the random stream
61,124,608 B; every cell of the §2.1 and §2.3 tables I checked (data, pads,
encoded, leaf input, salts, tree bytes, sent columns, sent vectors); the
rung-W14 total of 9,175,036 compressions; and "`A` and `H` are 99.4% of the
committed bytes" — I get 99.40% when the mask is included in the
denominator, which is the reading that makes the sentence true.

**"Every encoded byte is hashed exactly once" — true, and it survives the
awkward cases.** Every row of the `rows × nn` matrix is a row of the
encoding, and every column is hashed once; the mask rows and the proximity
row are ordinary rows of `A`/`H` and are hashed with the rest; the pad
symbols are inside the encoded row by construction (5d/5e), not appended
afterwards; there are no unhashed endpoints. The only correction is DC-13's:
the sentence is about four of the five commitments.

**Where it fails: DC-1**, above.

---

## 4. Device residency, re-derived

Reproduced exactly: the chunked decomposition (persistent + 150,994,944 B of
scratch at 128 rows + 50,593,792 B of BLAKE3 state + 2,097,152 B of leaves +
1,048,560 B of twiddles = the constant 204,734,448 B), the per-commitment
chunked peaks, the commit-phase peak **1,909,852,144 B (1.78 GiB)**, the
held **1,753,614,336 B**, the all-resident counterfactual
**12,140,445,680 B (11.31 GiB)**, and the 6.4× ratio.

I checked the buffer list for omissions the memo might have made, and found
the ones it claims to have added and no others in the chunked arm:

* twiddles — present, and the memo's 1,048,560 B is right: `ensure_twiddles`
  (`cuda.rs:1655-1669`) uploads two stage-major tables of `2^max_log − 1`
  entries, so 2·65,535·8 = 1,048,560 at `max_log = 16`.
* the output digest array — present, `nn·8` `u32` = 2,097,152 B, a raw
  `dev.alloc::<u32>` in `hash_cols` (`:2912`) and in `commit_zk_chunked`
  (`:1830`).
* the BLAKE3 state — `B3_STATE_SLOTS·nn` `u32` = 50,593,792 B, and it really
  is `(state_words + 1)/2` u64 (`:1828`).
* `d_coef2`'s width is `nn` by default: `zk_compact_pad()` is off unless
  `HL_ZK_COMPACT_PAD=1` (`:205-209`), so the memo's `nn` is the right
  assumption.
* `rmax = 128`: `chunk_plan` (`:2115-2128`) steps `(chunk/128).max(1)·128`
  and `chunk_rows()` floors at 128 (`:2105-2113`). The memo is right that
  the source's own comment at `:2051` still says "default 1024" — the code
  says 128; the memo follows the code.
* **pinned host staging — missing (DC-5), and it is host memory, so it does
  not change the device table but does change §5's inventory.**
* **the pooled `d_coef` — missing (DC-2), and it does change the device
  table, on the resident arm only.**

**"rung-W14 does not take the chunked arm" — confirmed [COUNTED].** Its
largest `rows·nn·8` is 276,299,776 B against `chunk_bytes()` = 1 GiB
(`:2062-2065`), and `chunked_now` is false, so `dev_commit_zk_from` takes
the resident branch at all four commitments (`:3628`, `:3656`). The memo's
consequence — a gate run only there exercises `k_hash_cols` and never
`k_hash_cols_stream` unless `HL_ZK_CHUNK=force` — follows, and it is the
single most useful operational sentence in §3.

**The 32 GB conclusion is sound**, with one addition. "Should it chunk at
all" is the right question, the saving named (the opening reads its columns
out of `d_enc` instead of re-encoding) is real, and refusing to hard-code a
new threshold in favour of a fraction of free VRAM read at startup is the
right instinct. The addition: on a 32 GB card the all-resident arm is
exactly where DC-2 bites hardest, because nothing forces a drain and four
commitments' worth of `d_coef`/`d_coef2` can strand ~4.7 GiB. A
free-VRAM-fraction threshold should be read **after** a `dev_pool_drain`,
or it will measure a card that looks fuller than it is.

---

## 5. The keyed kernel, and the reference vectors

**§4.2's recipe is correct and complete.** Verified against
`blake3-1.8.7`: `KEYED_HASH = 1 << 4` (`lib.rs:200`); `new_keyed` decodes
eight little-endian `u32` via `words_from_le_bytes_32` (`platform.rs:477-488`)
and calls `new_internal(&key_words, KEYED_HASH)` (`lib.rs:1097-1099`);
`parent_node_output` sets `input_chaining_value: *key`, `counter: 0`,
`block_len: 64`, `flags: flags | PARENT` (`lib.rs:1021-1026`); and **every**
chunk starts from the key, not just the first — `ChunkState::new(key, …)`
sets `cv: *key` (`lib.rs:510-512`) and every construction site passes the key
(`:1082`, `:1118`, `:1234`, `:1290`, `:706`, `:884`, and the SIMD batch at
`:690-699`). The flags ride in `self.flags` through every compression
including ROOT and the XOF. `s[8..12]` are the first four IV words
unconditionally, with no mode branch (`portable.rs:46-61`), matching
`kernels.cu:485`. The crate states the whole mode dependence in one place —
`hazmat.rs:414-428`, where the only two mode-dependent quantities are the key
words and the flags byte — so there is no fifth step hiding anywhere.

One practical sharpening for the integrator: **edit the six `b3_iv(...)`
call sites, never the IV literals.** `b3_compress` hardcodes the same four
constants inline at `kernels.cu:485`, textually identical to four of the
eight in `b3_iv` at `:475-476`; a search-and-replace on the literals would
silently break the compression in both modes.

**The trap boundary, confirmed by construction.** I implemented BLAKE3 from
the specification (not from the crate) and, beside it, the exact bug the
memo predicts — key words at the chunk start, IV left at the parents,
`KEYED_HASH` still ORed everywhere. The buggy variant agrees with real keyed
BLAKE3 up to and including 128 rows and **first disagrees at 129 rows /
1,032 bytes** [COUNTED,
`results/zk60_device_commit_check/keyed_vectors.json`]. The memo's "exactly
right for every column of ≤128 rows and wrong above that" is exactly right.

A consequence the memo does not draw, and should: at 125M the endpoint
columns are 37 rows (296 B) and the mask columns 50 rows (400 B), both
single-chunk. **Three of the five hiding commitments would be byte-correct
under the chunk-start-only bug**, and only `A` and `H` would break. A
bisection that started from "which commitment fails" would point at `A`/`H`
and away from the actual cause.

### The reference vectors

`results/zk60_device_commit_check/keyed_blake3_vectors.py` and its
`keyed_vectors.json` / `keyed_vectors.log`. Three independent
implementations agree on every vector: (A) BLAKE3 written from the spec in
that file by this checker, (B) the Python `blake3` package 1.0.9 (bindings
over the Rust crate), (C) for the key derivations, the literals pinned in
`hashtag.rs:190-198`.

Anchoring first, so the harness is not circular: my spec implementation
reproduces the **official BLAKE3 test vectors** under the standard test key
`"whats the Elvish word for friend"` at lengths 0, 1 and 1,024
(`92b2b756…0d26`, `6d7878df…c95b`, `75c46f6f…7ba4`) and the unkeyed
companions. It then agrees with the Python package at lengths
0/1/63/64/65/1023/1024/1025/2048/4096, keyed and unkeyed.

**The eight derived keys re-derived independently.** I implemented
`derive_key` from the spec (context pass under `DERIVE_KEY_CONTEXT`, then the
material under the context key with `DERIVE_KEY_MATERIAL` and, note, *not*
`KEYED_HASH`) and reproduced all eight pinned literals of
`hashtag.rs:190-198` for both tagged profiles, as did the Python package.
The pins are correct. (My first run failed them because I had ORed
`KEYED_HASH` into the material pass; the failure is worth recording because
it is precisely the kind of one-flag error a kernel author will make.)

**The conformance seed** — keyed column digests under the m125 profile's
column key `d5fc391c…b135`, over a deterministic synthetic column (an LCG
reduced mod `p`, little-endian, as `hash_column` would hash it):

| shape | rows | bytes | chunks | keyed column digest |
|---|---:|---:|---:|---|
| empty | 0 | 0 | 1 | `7ad2a969cf6b76e6a88fc387abf86792b7225a551fd3145afe495df016e93501` |
| one row | 1 | 8 | 1 | `8d492850d41c4140c897a869c7df044a5908901f66bfc8d427e8b3e7bd753d7a` |
| 8 rows | 8 | 64 | 1 | `75bbf9ab6272f22ff369440b58b0e95b8f40e01d4a6617f849058db2ababd208` |
| 64 rows | 64 | 512 | 1 | `d06c984248a25da7a44edf80e3fe48c667afedcdb21b706daa19421227d2047b` |
| 127 rows | 127 | 1,016 | 1 | `f19e85af72737b98aa02feace2493ada47a612e84f8084e28d54ed707a01e7ae` |
| **128 rows (one chunk)** | 128 | 1,024 | 1 | `98bb8dfab899528be9b2e69484065d7c936b278865cc4e8bc32be81c5f017131` |
| **129 rows (first parent)** | 129 | 1,032 | 2 | `c274dd55a31249e2467ded26bc65625ffbf303ea80781306f150660dbc6b17a0` |
| 125M endpoint | 37 | 296 | 1 | `09ce9166787208d6093e51e24b8f656a38ac888962fe15f92c531a8b02b07e98` |
| mask `M` | 50 | 400 | 1 | `e74eadf64a7860ef2a61eb42ab157be7dfe35d7d00740d2be22fde5f5356a9b9` |
| toy `A` | 455 | 3,640 | 4 | `3063587e5c43aadd38e57f123dfd083edea0824ae5650e3e79481a24543f501b` |
| rung-W14 `A` | 527 | 4,216 | 5 | `a5c68ae255e3093b7cb7fb8c5b7772ea0487d61ea005435fdf27395076a03953` |
| rung-W14 `H` | 436 | 3,488 | 4 | `9e0dd7c4b6e30f0999f0fdf03850336612542f4539bc59e43cb02a0a715c8d7f` |
| 125M `A` | 5,681 | 45,448 | 45 | `ad82957cff4fc2a1b41e535e511c67bf1d73111eed8361e691ac2601ee76cfad` |
| 125M `H` | 7,120 | 56,960 | 56 | `e73a3f15df06f9368ecb9e6f0110b108cb1e9af9d3030358de7262c6db32cec6` |

The JSON carries the same table for the rung-G profile, the legacy unkeyed
digest of each input, the chunk-start-only bug's digest of each input, and
the three negative controls the memo asks for (keyed `K1` ≠ keyed `K2`,
keyed ≠ unkeyed, column key ≠ leaf key — all hold). The JSON's
`bug_is_invisible_here` flag is the one a keyed probe must not be fooled by.

**Which keys reach the device — confirmed.** The device returns unsalted
column digests (`cuda.rs:3598` says so; the salting is `pcs.rs:797` and the
tree `pcs.rs:798`, both host-side), so `column_key()` alone must be
uploaded. `leaf_key()`, `node_key()` and `transcript_key()` never leave the
host. The memo's headline 5 holds.

---

## 6. Private bytes

Re-derived from the allocation sites. The memo's table is right in every row
it has; DC-5 is the row it does not have. Two smaller notes:

* **The `ZkReenc` retention is real and correctly described.** On the
  chunked arm `dev_commit_zk_from` returns
  `DevCommit { data: d_data, enc: None, zk: Some(ZkReenc { pads, pows, q }) }`
  (`cuda.rs:3690-3691`), so `d_pads` and `d_pows` live to the opening; on the
  resident arm it returns `zk: None` (`:3747`) and the raw `d_pads`/`d_pows`
  drop and are really freed. That asymmetry is why my first residency model
  over-counted the memo's "held to the openings" by 1,200,128 B and why the
  memo's 1,753,614,336 B is the right number.
* **`HL_GPU_HOST_HASH=1` is narrower than §5.3 item 6 implies.** `host_hash()`
  is read at exactly one site, `cuda.rs:2878`, inside `dev_commit_src` — the
  **non-hiding** commit. `dev_commit_zk_from` never consults it. So enabling
  the flag cannot today copy a *hiding* commitment's encoding back to the
  host; it would take a code change to put that switch on the private path.
  The memo says "That is an A/B switch on the non-hiding path", which is
  right, and then lists "enabling `HL_GPU_HOST_HASH=1` on a private path" as
  a thing that would reopen the statement, which is right as a *future*
  condition but reads as a present hazard.
* **Zeroing on free, confirmed.** `pool_put` has no memset (`:451-456`),
  `pool_take`/`pool_take_min` allocate raw (`:446`, `:479`), `take_min`
  best-fits so a later smaller request gets a longer buffer whose tail holds
  the previous tenant's field elements, and the only three `memset_zeros`
  calls on the commit path are on *acquisition* of the BLAKE3 state
  (`:1829`, `:2264`, `:2316`). The memo's characterisation — a
  write-before-read argument, not an erasure argument — is exactly right,
  and its refusal to decide the privacy question is the right call.

**The six "what would reopen the toy statement" items** are each real
conditions and I found nothing wrong with them, subject to the
`HL_GPU_HOST_HASH` narrowing above. Item 2 ("any change that lets the device
see a salt") is the one that is structurally guaranteed today: the salts are
drawn at `pcs.rs:778` and consumed at `:797`, and `try_commit_zk`'s signature
(`params, data, pads, pows, ntt`) has no salt parameter at all, so a device
path cannot see one without an API change. That is stronger than the memo
claims, and worth saying: **C-H3's leaf-level blinding argument is
host-side by the type signature**, not merely by current behaviour.

---

## 7. Amdahl

Every arithmetic figure in §7 is **exactly right** [MEASURED,
`q28-m125-final-dense.log` in the lane at `a8e4939`, committed by `1952a1e`,
clean]: 6.500 (`:107` 3.069 + `:114` 3.431), 6.594 (the 23 `PB-SLOTSTEP`
masked-sumcheck lines), 0.647 (`:154`), 1.997 (`:147` 8.497 − 6.500), 1.663
(the residual), the five percentages, and all three Amdahl rows
(10.901 / 10.807 / 4.307, −37.4% / −37.9% / −75.2%). The buckets partition
the 17.401 s wall with no overlap and no gap; the 1.079 s LogUp figure is
verbatim from `:109`; the self-description quote is verbatim from `:4`. The
three-run A/H ranges are exact for the three runs the memo means.

The defects are DC-7 (the 60% misattachment), DC-8 (the witness build
outside the denominator), DC-9 (three runs of ten), DC-10 (two bucket
labels). One further note of precision: the memo mixes two rounding regimes
— 6.500 comes from the per-phase column (3 dp) and 0.647 / 1.997 from the
HALF lines (unrounded) — so every quoted digit is good to ±0.002, not to
1 ms. The two ±0.001 errors happen to cancel to exactly 17.401.

---

## 8. The sharpest counter-argument

**First, the disposal the brief asks for: the column key cannot be applied
host-side by hashing a prefix.** Keyed BLAKE3 is not prefix-equivalent to
any unkeyed hash, for four independent reasons, each sufficient: (i)
`KEYED_HASH = 16` is ORed into the flags word of **every** compression
(`lib.rs:200`, and the flag-threading at `:549`, `:584`, `:1026`, `:462`), so
even a zero-length prefix gives a different digest; (ii) the key words
replace the IV as the chaining value at the start of **every** chunk
(`lib.rs:510-512`), which a message prefix cannot imitate past the first
chunk because each chunk restarts from the key and a prefix only shifts
bytes; (iii) a message prefix shifts every block and chunk boundary and
therefore every chunk counter, which is an input to each compression
(`portable.rs:59-60`); (iv) parent nodes take the key as their chaining
value (`lib.rs:1022`) and their input is two CVs, not message bytes at all,
so **no function of the message can put a key there**. My reference script
confirms the consequence empirically: keyed and unkeyed digests differ on
every one of the 32 vectors. The keyed delta must live inside the kernel.
The memo is right, and its estimate of the delta's size — one `#define`, the
key words at three sites per kernel, the flag in four expressions per
kernel, one 32-byte upload — is right too.

**Second, the cheaper paths the memo does not price.**

1. **Encode on the device, hash on the host.** This needs *no keyed kernel
   at all* and is byte-identical by construction, because the hash would be
   the CPU's own `hash_columns_keyed`. The plumbing already exists on the
   non-hiding path as `HL_GPU_HOST_HASH=1` (`cuda.rs:2878-2886`). Its price
   is a `rows·nn·8` device-to-host copy (2.98 GB for `A` at 125M) plus the
   CPU hash. Whether that beats a keyed kernel depends entirely on the
   **encode/hash split of the measured 6.500 s, which the memo never
   establishes.** §2.2 proves the hashing dominates the *compression count*
   and then lets that stand in for where the *time* is. The two are not the
   same claim: the commitment also runs two NTTs per row over 5,681 and
   7,120 rows, and 112M compressions is ~6.7 GB of BLAKE3 input, which a
   rayon-parallel `hash_columns` on this box may well turn over in well
   under a second. **The measurement that would settle it already exists in
   the code**: `GpuStats` carries `secs_ntt` and `secs_hash` as separate
   fields (`cuda.rs:514-517`), and the CPU side could be split with one
   `HL_PB_TIMING` sub-phase. I would take that measurement before committing
   to stages 2-3 of the plan, because if the encode is the larger half, the
   memo's seven stages are sequenced behind the smaller one.
2. **Overlap across layers, not within a block.** §7 treats one block in
   isolation, and within a block the commitments and the round loop are
   genuinely sequential (the round loop's challenges are bound to the roots
   by Fiat-Shamir, so no reordering is available). But the 8B pass is 32
   layers, and layer *i*'s round loop on the device and layer *i+1*'s
   commitment on the host are independent. Pipelining them buys the same
   Amdahl term as making the commitment free — `min(6.5, 6.6)` of every
   17.4 s — with **no new kernel, no keyed mode, no new privacy surface and
   no byte-identity argument at all**, because every layer's bytes are
   unchanged by when they are computed. Its costs are host RAM for two
   layers' witnesses and a scheduler; its risk is the 8 GB card, not
   correctness. For a memo whose framing question is "what does a device
   commitment buy", the honest comparison is against this, and it is absent.

Neither of these makes the memo wrong. They make its stage ordering a choice
rather than the only path, and the memo presents the staged plan as the
path.

---

## 9. Would I build stage 1 first?

**Yes**, with one insertion. Stage 1 (the keyed conformance harness) is
CPU-only, needs no device, cannot freeze the box, and is the artefact every
later stage is measured against. Most of it now exists: the vectors in
`results/zk60_device_commit_check/keyed_vectors.json` are already
cross-checked against three implementations and anchored to the official
BLAKE3 test vectors, and they include the 128/129-row pair that is the whole
point. What stage 1 still owes is the Rust side — the same inputs through
`hash_columns_keyed`, asserted equal to these hex strings.

Two amendments to the plan:

* **Insert a stage 0.5**: split the measured `A: commit` into encode and
  hash on the CPU. It is one timing sub-phase, it is cheap, and it decides
  whether stages 2-3 are aimed at the larger half (§8 item 1).
* **Widen the harness beyond one thread block.** `dev_hash_check` hashes
  `nn = 64` columns (`cuda.rs:2933`), which is a single 1,024-thread launch
  with 64 active lanes. Given DC-6 — the verifier sees 0.391% of the
  kernel's output — the harness is the only total check, and it should run
  at an `nn` of at least 2,048 so that more than one block, and a partial
  block, are exercised.

---

## 10. What this check did NOT do

* **It ran nothing on a GPU and built no Rust.** Every device figure is
  counted from allocation sites and constants, exactly like the memo's; if
  the driver pads allocations, or WSL pages, the real residency differs from
  both of us. DC-2 in particular is a claim about what the code allocates,
  not a measurement of `cuMemGetInfo`.
* **It did not run the test suite, the freeze check, or any capture.**
* **It did not read the verifier's 31-phase half of the cited log**, nor
  confirm from that log that the verifier *accepted* — the run carries an
  `S19-F1 EXPECTED TO BE REJECTED` banner on its fixture, which does not move
  any timing but does bear on how much weight §7's single sample carries.
* **It did not audit the transcript module**, so "the Fiat-Shamir transcript
  has its own fourth key" is taken from `hashtag.rs:117-123` and the memo,
  not re-derived from `transcript.rs`.
* **It did not attempt the privacy question.** Whether a write-before-read
  invariant is an adequate substitute for scrubbing — on the device or in
  the 128 MiB of pinned host memory DC-5 names — is the buffer review's
  ruling, and this check only says that the pinned buffers belong in the
  inventory that review reads.
* **It did not check the memo's quotations of documents I did not open**
  (`ZK60_HASH_LAYER_AND_FS_LIFT.md`'s C-H1…C-H8, the 5090 runbook, the
  five-second plan's CL1 row) beyond the two cross-document numbers that
  §7 depends on.
