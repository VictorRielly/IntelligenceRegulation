# The hash layer and the Fiat–Shamir lift for a STANDALONE tagged shaped block (obligation 3, last clause)

> **DRAFT — UNCHECKED.** Written 2026-09-23, 08:32–08:51 PDT (`date` read at
> 08:32, 08:41, 08:47 and 08:51), by a delegated Opus 5.5 agent for the security
> owner. **No independent check has read it.** It is the "one paragraph owed"
> of `ZK60_SHAPED_PRIVACY_PATH_STATUS.md` obligation 3, grown to a short memo,
> plus the residual column of obligation 10. **Not a privacy acceptance and
> not a privacy claim**: D22 (the toy) is the only statement in force.

> **Status update, 2026-09-23 09:18: CHECKED and RULED** — check
> `ZK60_HASH_LAYER_STANDALONE_TAGGED_BLOCK_CHECK.md` (`cb83a97`), disposition
> `ZK60_HASH_LAYER_STANDALONE_TAGGED_BLOCK_DISPOSITION.md` (HB-1…HB-4). No
> counterexample; every figure re-derived independently. **Errata that
> override the text below:** (F-1 / HB-1) S-5(b)'s reason for D21 is
> incomplete — the prover has no output-equality precheck
> (`protocol.rs:770-771`), so D21 is kept by the production caller verifying
> before transmitting; (F-2) the absorb counts 495 / 376 are COUNTED, only the
> squeezes are MEASURED; (F-3) rung-K4's 765,388 is a sum of measured parts
> (750,540 block stream in situ + 2 × 7,424 endpoint draws on a replica);
> (F-4) H^blk's real-versus-all-zero distance is 2^-71.86 (the one-sided
> sampler figure and a two-world LogUp figure were mixed); (F-5) at a block
> the constructor inputs (48 / 58 B) are shorter than every actual absorb
> (60 B) — separated by length too; (F-6) the tag-key `m` is a convention, and
> the "twelve keys" comment at `s24_tests.rs:151` is stale (28 at `544fbaf`);
> (F-9) the 47-byte constructor test pins 3 of the 7 run profiles; (F-10) S-3
> should say that before stage 26 the endpoint domains were identical, so a
> total failure of E-1 would then have shown as identical all-zero roots.

| | |
|---|---|
| Lane read | `/home/victor/wt-zk60-block125m` at **`544fbaf`** (stage 45 closed), read-only, working tree clean for source. Every `file:line` below is at that commit; paths without a crate are `hashline/src/private_block/…`, `zkp-core/src/…` is named |
| Gate read | round 9j records `results/zk60_native_run_gate_block/block-{rung-g,m125}-{dense,zero}*.json` on `/home/victor/wt-zk60-jointview` (read-only), and ledger §R9j |
| Base argument | `ZK60_HASH_LAYER_AND_FS_LIFT_RUN.md` ("the run memo", Lemma H^run, Route A^run) as revised, and its disposition (rulings H-1 … H-8) |
| Runs | one exact-arithmetic script (§7); nothing built, proved, verified or benchmarked. Labels: **[MEASURED]** a run happened and is cited; **[COUNTED]** arithmetic from code and shape; **[ARGUED]** reasoning here, unchecked; **[MINE]** my arithmetic, checked by nobody |

## 0. In plain words

- A standalone shaped block is **the run argument at `L = 1` with a
  different header**: one transcript under the *block* profile, five
  commitments (`A`, `H`, `M`, two external endpoints), five openings in the
  order `M, A, H, Input, Output`. Everything the run memo proved *per tree*
  and *per challenge* carries over; everything it said about *segments,
  boundaries and position tags* drops out.
- **The numbers.** Per proof the sampler term (D9) is **2^-72.86 at 125M**
  (9,212,588 draws) and **2^-76.58 at rung-G** (701,876 draws) — COUNTED, and
  reproduced per commitment by the gate's independent port on the real
  standalone bundles. **Every hash-layer term is at least 37.1 bits below
  that at `q = 2^128`**, as for the run (37.3–37.5 there).
- **New here, all small:** the 40-byte envelope's `block_binding`, both
  external endpoints opened back to back in one proof, the policy file beside
  the receipt, and **no production caller of the shaped block prover** (the
  block analogue of ruling H-2). None changes a figure.
- **Still hanging on Victor: D19b.** Without it no tagged profile — block or
  run — has an accepted model for its four keyed hash functions (§5).

## 1. The claim (conditional statement H^blk, in the run disposition's form)

> **Given** the fixed-challenge theorem for one shaped block (Theorem B's
> per-stage part — "the toy theorem per stage", `ZK60_JOINT_LAW_COMPOSITION_RUN_DISPOSITION.md`
> §1 — itself a reduction conditional on G-R1, G-R2 and G-R4 as the status
> page words them), **in the model of D19 with D19a's keyed family read as
> D19b proposes** (pending Victor, §5), and **under the named generator
> assumption** (M-3 / ruling C-3, the proof's three generators jointly, their
> separate OS entropy reads independent — E-1 / J-2): an **accepted**
> standalone receipt of `hashline-zk-mr1/private-block-m125/1` (resp.
> `…/private-block-rung-g-t24-dev/1`) — its 40-byte envelope and frame with
> five roots, all field values, 1,280 salt slots and 1,280 authentication
> paths, together with the 112-byte endpoint policy it is verified against —
> seen by a verifier making at most `q ≤ 2^128` hash queries, is within the
> blinding sampler's bias of a view that does not depend on the hidden input,
> output or activations: **about 2^-72.86 per proof at 125M and 2^-76.58 at
> rung-G**, linear in the number of proofs (**2^-52.93 / 2^-56.65 at a
> million**). **Every hash-layer term is at least 37.1 bits below that.**
> Whether the prover refuses an admissible witness is, up to 2^-117.4 (the
> two-world LogUp term, S-4), a function of the verifier-visible challenges;
> the challenge-only refusal is liveness, 4/p = 2^-62.0. Excluded, in the same
> sentence: the refusal string; timing, memory, power (D20); anything a
> capture adds (D21); a receipt the prover's own check rejected (D21).

The form is the run disposition §1's accepted conditional statement with
`L = 1`. The 125M figures confirm the status page's own [MINE] entries
(§1 table: 9,212,588 draws, 2^-72.86, 2^-62.0, about 2^-52.9 at a million)
and fill the rows it marked "not tabulated" / "OPEN (small)" (§2.2: salt
guessing, leaf collision, pre-query, absorb collision, and the standalone
sampler count) — as COUNTED figures, not measured ones (§6 item 3).

## 2. The run's argument, specialised

### 2.1 What a standalone block absorbs and publishes (code at `544fbaf`)

| step | what | code |
|---|---|---|
| before any transcript | `check_endpoints` refuses unless the owners' roots are the policy's | `protocol.rs:802` → `:757-768` (`:761-763`) |
| generator | ONE block stream, domain `single-prover/v1/ ‖ 0x02 ‖ block profile` (keyed-mode input under 32 B of `/dev/urandom`) | `protocol.rs:813`; `hash_domain.rs:240-249`; `zkp-core/src/rng.rs:44-51` |
| header | constructor over the **block** profile under its own `K_T`; then **5** absorbs: `expected-IO` (112 B, both endpoint roots), `public-statement` (the block's F_U digest), `parameters` (the block line), `calibration`, `schedule` | `protocol.rs:113-123`, `:96-101`; `private_block.rs:998-1007` |
| body | `A` root (+rows, log-cols), `M` root bare, β γ α, `H` root, 23 slots, `M`/`A`/`H` openings | `protocol.rs:1013`, `:1023`, `:1029-1031`, `:1132`, `:1140`, `:1148-1158` |
| endpoints | refusal replay on a clone, then `Input` then `Output` opened | `protocol.rs:820-827`; clone at `:388` |
| envelope | `HLPBLOK1 ‖ block_binding`, the F_T state after the header, **compared on decode, never absorbed** | `wire.rs:15-16`, `:145-146`, `:218-221`; `private_block.rs:1170`, `:1175` |

Only five roots ever feed the challenge chain — the two endpoint roots inside
`expected-IO` (`private_block.rs:1004-1005`), `A`, `M`, `H` — because salts
and paths are gathered after the indices are drawn (`zkp-core/src/pcs.rs:1036-1050`;
`zk.rs:594-599`). That is the run memo's Claim N3 at `4L + 1 = 5` [COUNTED
from the code; the capture's `transcript_program` says the same].

### 2.2 Carries over unchanged

| run memo item | at a standalone block |
|---|---|
| the model: D19 + D19a's form, D19b's justification; conventions V-1, V-2 (§2.1) | the same four keyed functions, keyed by the block profile (`shape.rs:1222-1234`, `zkp-core/src/hashtag.rs:92-101`) |
| N1 / H-3: the generator's stream is **unkeyed** BLAKE3 over 40 B | `zkp-core/src/rng.rs:53-61`; keyed only at `:47` |
| **Lemma H^run**, all four steps, with `4L + 1 → 5` trees | step 1 `zkp-core/src/pcs.rs:1248-1249`, `zk.rs:671-672`, endpoints at `protocol.rs:1386`; step 2 salts leave only for sampled columns (`zkp-core/src/pcs.rs:1043`, `:1048`; `zk.rs:598`); step 3 node inputs carry no salt (`zkp-core/src/merkle.rs:27`); step 4 roots, plus the envelope (§4 S-2) |
| N4 (three toy length arguments unnecessary; the two toy terms re-priced into the tag-key row) | unchanged in kind; `m` grew (§3.3) |
| N5: no other F_U input is 40 B | the block's F_U inputs are a **subset** of the run's: calibration 30 B (`private_block.rs:365-367`), endpoint spec digest 142 B ×2 (`endpoint_g.rs:197-206`), block public digest ≥ 31 B + weights (`private_block.rs:755-761`), block schedule digest ≫ 40, refill 40 [COUNTED, script]; rider C-R1 unchanged |
| N6 / B4 / C-R2: no constructor input is 47 B | block profiles 48 B (125M) and 58 B (rung-G); **checked by test** over every registered block profile (`s24_tests.rs:354-398`) |
| N7: tag key = generator key, `3·4·2^-256` | three generators per proof, as per run |
| N11 / H-1: both endpoint planes committed before any challenge | a fortiori — and **syntactic** as at the toy: the witness is a by-value argument (`protocol.rs:787`) fixed before the generator (`:813`) and the transcript (`:817`) |
| N12: no oracle programming; ideal world = honest prover on the all-zero input | **MEASURED at both shapes for a standalone block**: `m125-zero` proved in 20.10 s, verified from bytes in 1.20 s (lane stage 45), `rung-g-zero` likewise; both gated in round 9j |
| Route A^run hops `G_0 … G_8′`; B1 (`zkp-core/src/transcript.rs:107`), B2, B3 (47 < 48), B5, B6, B8 (roots at `protocol.rs:1013`, `:1023` precede the first squeeze at `:1029`), B10 | the same hops at `L = 1`, minus every tag clause |
| refusal classes; C-R4 (context: zero refused at `endpoint_g.rs:146`); C-R5 (tagged commitments decline the device, `zkp-core/src/pcs.rs:782-785`; `M` hashed in `zk.rs:514-516`) | unchanged; CS-3's lookup-miss refusal precedes the first `A` draw (`protocol.rs:978`) |

### 2.3 Drops

Position tags and everything about them (§3.5, F-1, H-5, B9, the tag clause of
hop `G_6 → G_7`, and §7.3 item 2's owed `L = 2` hybrid); boundaries (`B_k`
roots, `pb-run-stage` / `pb-run-block`, the boundary spec digest, **GS-7** —
a claim published one stage before its opening; at a block the endpoint
claims of slots 21 / 22 are opened in the same proof, in the toy's order);
the run header's `run-shape`, run public statement and run schedule digest;
the run statement file (N2) and segment framing (N10's segments); **M-9**,
replaced by D21 as at the toy; R-1's per-stage refusal channel (a block's
witness is built before anything public exists — run composition disposition
R-1); C-R3's `RunWitnessSource` interface item; the stage-by-stage hop-order
discussion (§4.2); and J-5's run-scope draw assertion (a block has stage 36's
eleven single-block segments).

### 2.4 Changes

| item | run (125M, `L = 12`) | standalone block |
|---|---|---|
| header | 6 absorbs under the run domain | **5** absorbs under the block domain (`protocol.rs:115-121`) |
| binding | in every segment header | in the 40-byte envelope (§4 S-2) |
| commitments = openings = roots | 49 | **5** |
| `N_leaf` (salts drawn) | 2,473,984 | **266,240** (125M), **20,480** (rung-G) |
| F_T queries `A` | ≤ 182,828, a BOUND | **14,748 / 2,733**, live squeezes MEASURED (§3.1) |
| sampler draws | 109,728,784 over three streams | **9,212,588 / 701,876** over three streams (§3.2) |
| generator sites | `run.rs` run stream + `endpoint_g.rs` ×2 | `protocol.rs:813` + `endpoint_g.rs:269` ×2 (via `private_block.rs:1075-1076`), role-separated domains (`hash_domain.rs:176-199`) |
| S-4 refusal; liveness | `12·768/\|Fp2\|`; `37/p` | `768/\|Fp2\|` = 2^-118.42 (two-world 2^-117.42); `4/p` = 2^-62.00 |
| tag keys in existence `m` | 12 at `8c5922b` | **28** at `544fbaf` (seven tagged registered block profiles, `shape.rs:158`, two legacy `:1213-1215`); 32 with the test-only rung-K8 |

## 3. The figures, per block

### 3.1 Trees and transcript [labels per row]

| | 125M | rung-G | label |
|---|---:|---:|---|
| encoded columns `M` / `A` / `H` / `In` / `Out` | 4,096 / 65,536 ×4 | 4,096 ×5 | COUNTED; the gate's records agree |
| `N_leaf` = salts drawn = F_C = F_L queries | 266,240 | 20,480 | COUNTED |
| F_N queries (`N_leaf − 5`) | 266,235 | 20,475 | COUNTED |
| salt slots published; columns re-hashed and authenticated under the block's own keys | 1,280; **1,280 of 1,280**, 26,470,400 B | 1,280; **1,280 of 1,280**, 2,594,816 B | **MEASURED** (R9j B6; CH-7: 0 of 1,280 under another profile's keys) |
| distinct opened columns, expected / dense / zero | 1,270.2 / **1,270 / 1,267** | 1,241.0 / **1,244 / 1,240** | COUNTED / **MEASURED** |
| unopened leaves (hidden by salt alone), dense / zero | **264,970 / 264,973** | **19,236 / 19,240** | MEASURED (from the above) |
| of them with the leaf digest published (expected) | 1,251.3 | 1,166.0 | COUNTED |
| path digest slots | 19,456 | 15,360 | COUNTED |
| F_T absorbs | **495** | **376** | COUNTED from the code (§2.1 sites; per slot `pb-slot` / `pb-scalar` / `pb-term` at `argument.rs:475`, `:530`, `:592`; one `sc-round` per round — main rounds `zkp-core/src/sumcheck.rs:109` through the masker, `zk.rs:1082-1083`, extension rounds `zk.rs:1099`; `pcs-vec` per group + `pcs-prox`, `zkp-core/src/pcs.rs:1033`, `:1035`; `mask-q`, `mask-prox`, `zk.rs:584`, `:593`) and **reproduced from the capture's public structure** (361 / 242 rounds; groups 36, 9, 1, 1) |
| F_T live squeezes (`final_counter`), dense = zero | **14,252** | **2,356** | **MEASURED** (gate replay; `= challenges 13,932 / 2,036 + 64·5`) |
| of them slot-definition draws (measured − modelled channels) | 446 | 325 | MEASURED − COUNTED; the run memo extrapolated ~485 and allowed 1,024 |
| `A` = absorbs + squeezes + constructor (+ 0 tag squeezes) | **14,748** | **2,733** | as above |

The dense and all-zero bundles give the **same** transcript counts at both
shapes: the number of transcript operations does not move with the hidden
input — the run memo's row 23, now MEASURED at 125M.

### 3.2 The sampler's draw accounting, per generator

| | block stream `fp()` / salts | each endpoint `fp()` / salts | per proof `fp()` | D9 term | label |
|---|---:|---:|---:|---:|---|
| **125M** | 9,029,804 / 135,168 (148.8 MB) — `A` 5,484,800, `H` 3,526,654, `M` 18,350 | 91,392 / 65,536 | **9,212,588** | **2^-72.8648** | COUNTED (run memo §6.2, H-6); **per commitment reproduced by the gate's port on the real bundle** (A, H, endpoints exactly; `M`'s 2·ΣL_s = 2,478); generator **not measured** at 125M (obligation 6a) |
| **rung-G** | 687,028 / 12,288 — `A` 411,392, `H` 258,046, `M` 17,590 | 7,424 / 4,096 | **701,876** | **2^-76.5791** | COUNTED; reproduced by the gate likewise (`M`: 1,718); the endpoint geometry is rung-K4's, whose 7,424 is MEASURED on the replica |
| rung-K4 (anchor) | 750,540 / 12,288 | 7,424 / 4,096 | 765,388 | 2^-76.4542 | **MEASURED** (lane stage 36; endpoints on the replica, S36-F2) |
| toy (anchor) | 320,908 / 8,192 | 3,072 / 2,048 | 327,052 | 2^-77.68 | **MEASURED** (stage 36) = D9 / D22 |

Draw sites: `A` masks `protocol.rs:1002-1004` + pads `zkp-core/src/pcs.rs:777`;
`H` masks `protocol.rs:1115-1117`, zero-sum rows `:1118-1126`
(`layout.rs:1281-1284`), pads; `M` `zk.rs:485`, `:496`, `:503-508`; endpoints
`endpoint_g.rs:276-278` + pads; salts `zkp-core/src/pcs.rs:778`, `zk.rs:513`.
One `fp()` draw is exactly `r(p−r)/(p·2^128) < 2^-96` from uniform with
`r = 2^128 mod p = p − 2^32` (`zkp-core/src/field.rs:10`, `:36-38`;
`zkp-core/src/rng.rs:73-77`), so D9's `draws × 2^-96` is an upper bound
[COUNTED, control C7]. The gate's `M` "free unknowns" are 15,870 = 46·256 +
4·1,024 − 2 because two drawn `b` entries are overwritten (`zk.rs:505-506`,
stage 36 assertion 6); the draw count keeps them.

### 3.3 The residual table [COUNTED, MINE], `log2`, at `q = 2^128`

| residual | formula | 125M | rung-G |
|---|---|---:|---:|
| **sampler bias (D9, accepted)** | draws × 2^-96 | **−72.8648** | **−76.5791** |
| LogUp refusal (S-4), one-sided (two-world: −117.42) | `768/\|Fp2\|` | −118.42 | −118.42 |
| salt guessing (Lemma H) | `q·N_leaf·2^-256` | **−109.98** | **−113.68** |
| leaf-input collision (Lemma H) | `C(N_leaf,2)·2^-256` | −220.96 | −228.36 |
| challenge pre-query (B5) | `q·A·2^-256` | −114.15 | −116.58 |
| absorb-input collision (B6) | `C(A,2)·2^-256` | −229.30 | −234.17 |
| constructor-vs-absorb (B10) | `(A+q)·2^-256` | −128.00 | −128.00 |
| tag-key collision (H-4), `m = 28` (`m = 32`: −247.05) | `C(m,2)·2^-256` | −247.44 | −247.44 |
| tag key = generator key | `3·4·2^-256` | −252.42 | −252.42 |
| generator, in-model alternative (primary: M-3, no bit count) | `6q·2^-256` | −125.42 | −125.42 |
| **TOTAL** (`q = 2^128`, and the same at `q = 2^80`) | | **−72.8648** | **−76.5791** |
| **gap, sampler → largest hash-layer term** | | **37.11 bits** | **37.10 bits** |
| liveness, NOT distance | `4/p` | −62.00 | −62.00 |
| a million proofs (10^6): sampler / salt guessing / leaf collision / total | | −52.93 / −90.05 / −181.09 / **−52.93** | −56.65 / −93.75 / −188.49 / **−56.65** |

The total equals the D9 term to four decimals. **The hash layer is not where
a standalone block's error goes**, exactly as for the run (gaps 37.30 /
37.47 there); at `q = 2^80` the gap is 85.1 bits. The tag-key row moved from
the run memo's 2^-249.96 (`m = 12`) because the lane now registers seven
tagged block profiles; all 28 keys are pairwise distinct **by test**
(`s24_tests.rs:156-249`), and rung-K8's four against those and each other
(`k8_tests.rs:268-285`), so the row is zero today and changes no total.

## 4. What a standalone block has that the run argument did not cover

- **S-1 — the header under the block-profile domain [ARGUED].** A standalone
  block and a stage of a run over the same shape share all four keys (D19a)
  and are separated by the constructor input — block profile
  (`protocol.rs:115`) against run profile — so their initial F_T states are
  independent in the model (run memo N8(1), seen from the other side). For
  hiding nothing beyond B5 / B6 is needed (salts and generators are fresh per
  proof, and another proof's challenge points are just more queries the
  distinguisher may know); cross-protocol replay is also stopped by the magics
  (`wire.rs:15`, `:250`). The 125M block's constructor input (48 B) sits at
  the bottom of the absorb length class, so B10's content argument (a state
  would have to spell `hashline-v1/…`) is what separates it, priced at 2^-128.
- **S-2 — the envelope binding [ARGUED; reproduction MEASURED].** A 32-byte
  F_T state, a public function of the five public header words, published at
  `wire.rs:145-146`, compared at `:221`, never absorbed; the gate recomputed
  it from public words on all four bundles (R9j B2). It is inside Lemma H's
  public map `T`. The H-5 clause applies verbatim: it is **not
  input-independent** (the header absorbs both hiding endpoint roots, and
  fresh salts make it differ even between two proofs of one input); it is
  carried by the roots' hiding, not by "being public".
- **S-3 — both external endpoints in one proof [ARGUED; checker, attack
  here].** Opened back to back after `H` (`protocol.rs:820-827`), each tree
  its own `T` with no cross-tree input, each from its own generator
  (`private_block.rs:1075-1076` → `endpoint_g.rs:269`) under a role byte
  (`endpoint_g.rs:83-85`; `hash_domain.rs:207-213`). In the ideal world both
  planes are zero, so the two trees commit **identical data**; Lemma H never
  uses the columns' entropy — the unopened leaves are fresh because of the
  salts — and the only coupling event, two equal salts, is inside
  `C(N_leaf,2)·2^-256`. The independence of the three OS reads is assumption
  E-1 (J-2), not a hash fact. The field-view side is not this page's: both
  endpoints disclose 0 and the whole block's joint rank equals the sum (2, H's
  public identity) [MEASURED, R9j B7 / B9]. A one-stage run opens the same two
  roles in the same order (run memo §1.2 rows 12–13), and the gate reads the
  block's per-commitment figures equal to the run's (31 of 31, R9j.9).
- **S-4 — the endpoint policy beside the receipt [ARGUED].** 112 B
  (`private_block.rs:357`, `:998-1007`): magic, context (C-R4), the two scales
  pinned to `ENDPOINT_SCALES` (`:371`), the two endpoint roots. No object not
  already in Lemma H.
- **S-5 — no production caller [READ; OPEN for the integrator, not a proof
  obligation].** In non-test code `prove_inner_at` / `verify_inner_at` are
  called only at `Shape::toy()` (`protocol.rs:780`, `:1331`); the shaped
  entries `to_bytes_at` / `verify_bytes_at` (`private_block.rs:1164`,
  `:1182`) are `pub(crate)` and reached only from `#[cfg(test)]` modules
  (`private_block.rs:112-341`). As ruling H-2 said of `prove_run`: the object
  the game is defined over exists only in test builds. A production entry
  must (a) seal both endpoints with the witness builder's own pass
  (`witness::build_shaped`, ruling H-1's rule in block form) and (b) keep
  D21 — which it can, because a refusal returns before the `Receipt` is
  assembled (`protocol.rs:831-840`).

## 5. The dependence on D19b, exactly

D19b (register: **PROPOSED — pending Victor; recommendation accept**) is used
wherever the argument treats one of the four **keyed** functions `F_T, F_C,
F_L, F_N` — keyed by **public** keys derived from the block profile string
(`zkp-core/src/hashtag.rs:92-101`) — as a random function independent of the
other three and of unkeyed BLAKE3: (i) Lemma H step 2, the unopened salted
leaf `F_L(d ‖ s)` as fresh and uniform; (ii) N4 — dropping the toy's length
arguments and re-pricing its 2^-241 / 2^-485 terms into the tag-key row;
(iii) B2 in hop `G_6 → G_7` (a challenge input cannot meet a column, leaf,
node or refill input because they are different functions); (iv) even B1,
B3, B5, B6, B10 inside `F_T`, because `F_T` is itself keyed with a public
key. **Not** used: every count, the D9 term, the LogUp and liveness terms,
N5's 40-byte argument (unkeyed, inside D19 plus V-1), and the generator
assumption M-3 (standard model). **D19 as accepted does not cover keyed
BLAKE3 under a public key, so without D19b no tagged-profile statement —
standalone block or run — has a model at all**; the block adds no new use of
it (its header, S-1, is another input to the same `F_T`). If Victor says
"D19b yes", nothing measurable changes (the one D19b-priced row is 2^-247.4,
zero by test). If he says "no, use prefixes", the tag stage is redone and
this page must be re-derived under one unkeyed oracle; which of the toy's
length arguments would then return depends on how the prefixed inputs sit
against the remaining unprefixed ones (the 40-byte refill, the statement
digests) — **not analysed here**.

## 6. Open, and what a checker should attack first

**Open.** (1) D19b (Victor). (2) Theorem B's per-stage part at the shaped
layout: G-R1's leftovers GS-4/5/11/12, G-R2, and G-R4 "said exactly" (NL-8)
— conditions of H^blk, outside the hash layer. (3) The generator's
consumption is **MEASURED at neither shape** of this page: 125M is obligation
6a; rung-G is not among stage 36's six shapes — both COUNTED, per commitment
reproduced by the gate. (4) Route B (G-H1) — unruled, not needed for Route A.
(5) S-5, the production entry (integrator). (6) Inherited, unchanged: G-H2
(standard model), G-H3 (soundness composition), G-H4 / C-R5 (device path;
the statement is CPU-only).

**Proposed corrections, not applied** (dated notes beside the originals, for
their owners): register D19b's "about 2^-251" and the run memo §6.2's
tag-key row (`m = 12`, 2^-249.96) now read **2^-247.44** at `m = 28`
(2^-247.05 with rung-K8), zero by test; the run memo (§2.4, §4.2, §6.1,
§6.3 — right at its `8c5922b`) and the status page §2.3 row 6 cite
`endpoint_g.rs:224` for the endpoint generator — at `544fbaf` it is
`endpoint_g.rs:269`, with a role-byte domain since stage 26. None moves a
total.

**Attack first.** (a) **S-3**: is there any relation between the two endpoint
trees, or between an endpoint tree and `A` (which shares the slot-21/22 data
through the claims), that Lemma H's per-tree kernel misses — in particular in
the all-zero world where both endpoints commit the same plane? (b) The
**F_T count**: re-derive 495 / 376 absorbs from the Rust (not from the run
formula), and confirm the refusal replays (`protocol.rs:326`, `:388`) add
only duplicate points. (c) The **125M draw count**: re-derive `H`'s
zero-sum rows and `M`'s ΣL_s = 1,239 from the Rust rather than from the
pinned model identity `published − draws + 46`. (d) §5: whether any step
uses more of the model than stated (e.g. the envelope state being published
while it is also the chaining value of every later `F_T` query). (e) S-5's
reading that no production path reaches a shaped profile.

## 7. Evidence

`results/zk60_hash_layer_standalone_block/standalone_block_hash_counts.py`
(exact integer / `Fraction` arithmetic; floating point only for the tree
occupancy expectations) → `standalone_block_hash_counts.json`. **Controls
first, all pass:** C1 the toy's 327,052 draws, 320,908 / 8,192 block stream,
12,288 salts, 2^-77.68; C2 rung-K4's MEASURED 750,540 and 2 × 7,424; C3 the
run memo's 109,728,784 / 2^-69.2906, 2,093,340 / 2^-75.0026, 2,473,984
salts, absorbs 1,129 / 5,932 and all six hash-layer rows at both run
configurations; C4 the gate's blinding-unknown counts on the real bundles
(identical on dense and zero at each shape) against the per-commitment model
(exact); C5 `final_counter =
challenges + 64·5` on all four, dense = zero; C6 S-4's 2^-118.42; C7 the
exact per-draw bias; C8 the re-hashed bytes (exact) and expected against
measured distinct columns. It reads the four gate records' published figures
(as constants, sourced) and, for the absorb cross-check, only the round
counts and role group / claim counts of the two dense bundles'
`observations.json` — no column, salt, path or field value.

**Read, not re-derived:** the run memo and its disposition; the status page;
register D9, D19, D19a, D19b, D21, D22; lane ledger stages 24, 26, 36, 45;
gate §R9j. **Not done:** no Rust was run; no lemma was re-proved; the run
memo's Lemma H^run and Route A^run are taken as ruled ("holds with changes")
and only their specialisation is argued here. **Nothing here establishes a
privacy property.**
