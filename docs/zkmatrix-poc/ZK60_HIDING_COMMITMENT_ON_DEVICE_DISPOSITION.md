# ZK60 — security owner's disposition of the "hiding commitment on the device" design and its independent check

**Written 2026-09-22 13:03 PDT by the security owner (interactive Claude
Fable 5.1).** Inputs: the design memo `ZK60_HIDING_COMMITMENT_ON_DEVICE_DESIGN.md`
(drafter, `5b2a2ef`..`d12ba3f`, evidence `results/zk60_device_commit/`) and
the independent adversarial check `…_DESIGN_CHECK.md` (checker,
`db40805`..`7028fed`, evidence `results/zk60_device_commit_check/`), both on
this branch. The memo is the security owner's OFFER to the integrator, who
owns the keyed CUDA path and the device-buffer review; nothing here is a
patch. Labels: [MEASURED] from a committed log; [COUNTED] by a script from
code and shape; [MODEL] an estimate, never a prediction; [READ] I read it.

## 0. In plain words

The two big hiding commitments of a 125M block cost 3.07 s + 3.43 s of a
17.4–19.4 s CPU prove and are the natural device work; the memo writes down
exactly what a device version must compute byte for byte, what it costs in
bytes, how it fits an 8 GB and a 32 GB card, and how byte identity is
proved. The checker re-derived it by other methods: the byte contract, the
receipt reconciliation (40,783,352 / 16,421,048 / 2,816,472 B rebuilt part by
part), the NTT ordering trap, the keyed-mode recipe (against the vendored
`blake3` 1.8.7 and the official test vectors, re-deriving all eight pinned
keys), the 8 GB chunked peak (1,909,852,144 B to the byte) and the Amdahl
table all hold. **Four things were wrong or missing, two of them about
private bytes**, and they are ruled below. **The honest headline for the
target:** with the commitments free AND the round loop free the 125M block
would still be about 9.6 s end to end [MODEL — the witness build is 5.24 s
and outside both], and no number here is a time for the 8B pass.

## 1. Rulings

**DC-A — the contract stands with two corrections and becomes the
integrator's checklist.** Step 10's transcript order is wrong (DC-3): the
opening draws the group lambdas AND the proximity rho (`pcs.rs:943-964`,
`:961` [checker]) before any absorb, not after the clear vectors — the memo
corrects it, because §1 is offered as a re-implementation spec and the
Python gate is exactly such a re-implementation. "Only the hash functions
differ between legacy and tagged" is four differences, the accelerator offer
among them (DC-4) — corrected. The eleven steps otherwise re-derived. The
one device trap most likely to bite is confirmed: `transform` bit-reverses
its INPUT and returns natural order, so column `j` is the natural index and
a decimation-in-frequency device NTT would permute the columns — every
value right, every digest of the right bytes at the wrong index, a different
root.

**DC-B — two private-byte facts the memo missed go to the integrator's
buffer review as first-rank items, and are what the toy statement's 03:23
scope note was about.** (i) DC-5: **two 64 MiB page-locked host staging
buffers** (`cuda.rs:766-772, 808-880, 1047-1060` [checker]) through which
every witness upload is copied — unzeroed, process-lifetime. That is the
"pinned host memory" half of the scope note, and it exists on the UNKEYED
path today. (ii) DC-2: on the resident arm `d_coef` is dropped but not
freed — `pool_put` never frees and `pool_take` matches by exact length — so
it stays resident through the expand NTT (the memo's own mitigation cited
the wrong line); with it 125M `H` is 8.71 GiB not 7.84 on that arm, and
rung-W14's whole commit phase 1.20 GiB not 0.80. Together with the memo's
own inventory (witness rows in `d_data` held past the openings; pad rows in
`d_pads` retained to the opening on the chunked arm; the pool never zeroing
on free; `HL_GPU_HOST_HASH=1` copying the whole private encoding back to the
host), **this is the list the device-buffer review must read before any
statement extends to a device path.** Nothing on it is claimed unsafe; all
of it is claimed unread. The salts never reach the device [both agents].

**DC-C — counts.** The memo's prose compression counts contradict its own
evidence file (DC-1): the figures of record are the checker's
**112,066,560 column-digest compressions of 112,590,844** [COUNTED]; the
conclusion (hashing is 99.5% of the compressions; the tree and leaves are
under 0.5%) survives. Five hiding commitments per block, not two — my brief
was wrong and the memo corrected it. Encoded bytes 6.29 GiB = the measured
6,433 MiB of resident-set growth [MEASURED, `q28-m125-final-dense.log`].

**DC-D — the verifier sees 0.39% of a kernel's output (DC-6), so the
conformance harness is the only total check.** `verify_zk_tagged`
recomputes leaves only for the 256 sampled columns of 65,536; a device bug
confined to unopened columns passes 99.6% of honest proofs. Not a soundness
break — a wrong root binds the prover to the wrong thing, and the sampled
columns catch it with the usual probability — but it means: (1) **stage 1,
the keyed-mode conformance harness at the small shapes, is built first and
is the gate every kernel change must pass**, seeded by the checker's
vectors (`results/zk60_device_commit_check/keyed_blake3_vectors.py` →
`keyed_vectors.json`: BLAKE3 from the specification, anchored to the
official vectors, agreeing with the Python package, re-deriving the eight
pinned keys, with the 128/129-row pair where a chunk-start-only keying bug
first shows — 129 rows, 1,032 bytes); (2) the existing probe
`dev_hash_check` runs one thread block at 64 columns and cannot see a
multi-block bug — the harness must run whole commitments at the small shapes
and compare every column digest, not a sample; (3) the two endpoints (37
rows) and the mask (50 rows) are single-chunk, so the chunk-start bug would
leave three of five commitments byte-correct — a bisection points at `A`/`H`.

**DC-E — memory on the cards, with the VRAM rule.** 8 GB: the chunked
commit phase peaks at 1.78 GiB and holds 1.63 GiB to the openings
[COUNTED, confirmed to the byte]; with the round loop's tables (the IR
memo's 4.83 GiB) the block is 6.46 GiB, **81% of the card, counted with
nothing measured behind it** — the sentence the rule allows is "the
commitments fit chunked; the whole block is 81% on paper and has not been
run". 32 GB: chunked 6%, all-resident 38%, with the round loop 43% — there
the question is whether to chunk at all, and the 1 GiB chunk threshold is
the wrong constant for that card. The resident arm's true peak includes the
un-freed `d_coef` (DC-2).

**DC-F — the Amdahl table, framed honestly [MODEL, one run].** Of 17.40 s:
commitments 6.50, round loop 6.59, openings 0.65, the rest of the commit
half 2.00, everything else 1.66; commitments free → 10.9 s; round loop free
→ 10.8 s; both free → 4.3 s **of the prove** — but the witness build (5.24 s)
sits outside the prove, so end to end that is about 9.6 s (DC-8); and "the
commitments are 60%" is a share of the 10.79 s floor, not of the 13.44 s
ceiling (48.4% there; DC-7). No time for the 8B pass appears anywhere; the
private 8B pass has never been run on a GPU after lane CL1.

**DC-G — two things the check adds that change the plan.** (1) **Stage 0.5,
before any kernel: split the measured `A: commit` into encode and hash.**
Compression counts say hashing dominates the count; nobody has measured
whether it dominates the TIME. If the encode is the larger half, "encode on
the device, hash on the host" needs no keyed kernel at all and the whole
keyed-CUDA question moves down the list. The CPU path has an `HL_TIMING=1`
phase report in `pcs.rs`; one 125M run with it on answers this — mine to
run, today. (2) **Pipelining across layers**: in a 32-layer pass, layer
`i`'s round loop can overlap layer `i+1`'s commitment (CPU against device,
or two device streams) — the same Amdahl term as putting the commitment on
the device, with no kernel, no keyed mode and no new private surface. It is
a scheduling lever in the integrator's run driver, and it is the cheapest
item on this page; it needs the 8B pass to exist on the private line first.
(3) The "keyed prefix" shortcut is dead for four independent reasons (the
flag is in every compression; the key restarts every chunk; a prefix shifts
every chunk counter; parents take the key as chaining value and see no
message bytes) — nobody should try it.

**DC-H — ownership, restated.** The integrator: the kernels, the six launch
sites (opt-in per call, four are non-hiding paths), the keyed probe, the
buffer review (DC-B), the run-driver pipelining. The lane, as offers: stage
1's conformance harness (CPU-only, no device, the checker's vectors as its
seed, whole-commitment comparison at every small shape) and, after the D19
integration lands, a capture from a device-produced proof for the Python
gate's hash layer (the independent check). Stage 0 is not anyone's to skip:
without the D19 tag integrated there is no tagged commit to accelerate.

## 2. What this is not

Not an implementation; nothing compiled or run on a device by either agent.
Not a speed result: every second on this page is one CPU run's phase
[MEASURED] or an Amdahl ceiling [MODEL]. Not a change to any privacy
statement: the toy statement stays CPU-only until the buffer review of DC-B
has been read and ruled.
