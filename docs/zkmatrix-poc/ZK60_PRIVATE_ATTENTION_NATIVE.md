# ZK60 native private attention — engineering delivery for independent review

| | |
|---|---|
| Author | Claude Fable 5.1 (delegated attention lane), 2026-09-18 |
| Worktree / branch | `/tmp/wt-zk60-attention-fable-20260918`, `zk60-private-attention-fable-20260918` at `db021ba` (no commits made; files left for review) |
| Profile | `hashline-zk-mr1/private-attention-t32-poc/1` — **experimental** |
| Status | **Written, NOT compiled, NOT run.** This session had no permission to run `cargo` (every invocation was denied, including `cargo check`). Every command in §7 is unrun; every number in §5 is computed from the layout by hand. Expect compile fixes. |
| Claims | None beyond "this is the implementation". No MVP, whole-proof privacy, D8/D11 or five-second claim. |

## 1. Ownership (lane record)

Sole writer of the attention Rust in this worktree. Files created:

- `hashline/src/private_attention.rs` — public API, statement types, endpoint owners, receipt.
- `hashline/src/private_attention/layout.rs` — fixed geometry, planes, lookups, **the declared mask/CFS schedule**.
- `hashline/src/private_attention/witness.rs` — exact-integer attention-half witness (kernel semantics).
- `hashline/src/private_attention/argument.rs` — the eighteen masked sumchecks, written once, driven from both sides.
- `hashline/src/private_attention/protocol.rs` — transcript, ownership, the schedule audit, opening refusals, prove / verify.
- `hashline/src/private_attention/wire.rs` — bounded fixed-shape codec.
- `hashline/src/private_attention/tests.rs` — unit tests (honest proof, 17 witness tampers, 19 receipt tampers, refusals, audit, wire).
- `hashline/tests/zk60_private_attention.rs` — public-API tests.
- `hashline/examples/zk60_private_attention.rs` — prove in one process, verify in a fresh one.
- this note.

Edited: `hashline/src/lib.rs` (+2 lines: the module export and its one-line caveat). Nothing else was touched: not `attention.rs`, not `zk.rs` or any `zk_ffn_*`, no existing profile, no frozen proof bytes, no security parameter, no `codex-audit-*`, no `scripts/logup_*_spike.py`, no `src/manifest.rs`, no GPU file, no `Cargo.toml`.

## 2. What is proven

The attention half of the fixed block, with the integer semantics of `private-block-kernel` / `causal_oracle::FixedCausalOracle` (calibration `tn 11, cn 1024, ceps 1, wrho 29; shifts q/k/v/qr/kr 7, score 6, o 9, ao 7, residual 0; fE 9, fP 9, fRo 7, wrhoS 14; mask −127`):

| Stage | Relation proven | Where |
|---|---|---|
| input | `x_in` equals the caller-fixed input endpoint plane; `x_in ∈ int16` | IO-in slot; D zero-check + U8 limbs |
| RMSNorm | `D = isqrt(Σx² + ceps)` via `Dsq = D²`, `a1 = ss − Dsq ≥ 0`, `a2 = 2D − a1 ≥ 0`, all three byte-limbed below 2²⁴; `2·cn·g·x + D·2^tn = y·D·2^(tn+1) + ρ`, `ρ, σ = D·2^(tn+1) − 1 − ρ ∈ [0, 2²⁹)`, `y ∈ [−127, 127]` | SS slot, norm-squares zero-check (hosts SS), limb zero-check, D zero-check |
| Q, K, V | three matmul sumchecks against the public weights; `acc = 2⁷·y + r`, `r ∈ [−64, 64)`, outputs in `[−127, 127]` | 09Q / 09K / 09V, hosted by the Q and KV zero-checks |
| RoPE | `C·x + S'·x_partner = 2⁷·xr + r` with the partner opened at the flipped point (its own site, its own pair) | Q and KV zero-checks |
| scores | `Σ_i qr·kr = 2⁶·s8 + r` over **all** `(h, t, j)`, bilinear, two extension rounds | score slot, hosted by the softmax zero-check |
| causal softmax | one-hot selector (boolean, row sum 1, `zsel·δ = 0`), `δ = max − masked score`, `(δ, E[δ])` in the exp table, `Sum = Σ_{j≤t} E`, `2⁹·mask·E = p·Sum + ρ`, `ρ, σ ∈ [0, 2¹⁴)`, `p < 2¹⁰`; off the causal support the same relation forces `p = ρ = 0` | row-sum slot + softmax zero-check |
| PV | `Σ_j p·v = 2⁹·o8 + r`, bilinear, two extension rounds | PV slot, hosted by the Q zero-check |
| output projection | `Σ_i o8·wo = 2⁷·ao + r`, `ao ∈ int16` | Wo slot, hosted by the D zero-check |
| residual 1 | `xres1 = x_in + ao`, `xres1 ∈ int16` | D zero-check |
| output | `xres1` equals the caller-fixed output endpoint plane | IO-out slot |
| lookups | 47,104 U8 lookups + 2,048 exp lookups, committed histograms, table-helper zero-check, ONE value-0 sum claim on H masked by a proven zero-sum pair | TAB, ZS, the H sum claim |

Not covered (composition work, A3/A4 of the construction): `norm_m`, the FFN seams, residual 2. The FFN's private input is `norm_m(xres1)`, so this component's output endpoint does not chain to the repaired FFN IO profile without that norm; nothing here pretends otherwise.

Every range is exact (the kernel's refusal windows), obtained from one 256-entry table: a `b`-bit value is byte limbs plus `2^(8 − b mod 8)·top ∈ U8`; `[−127, 127]` is `v + 127 ∈ U8 ∧ 127 − v ∈ U8`. The no-wraparound argument (every constrained integer expression stays below 2⁵² ≪ p; in particular `D, a1, a2 < 2²⁴` gives `D² + a1 < 2⁴⁹`) is written out in the comment above `layout::lookups`; **it is a premise for the reviewer to re-derive, not a checked fact.**

## 3. The declared schedule, and where it deviates from the JSON

The construction's slot list, host assignment, M shape and functional order are implemented exactly:

- **18 slots** in the order `01 SS → 02 norm squares [hosts 01] → 08 limb → 07 row sums → 09Q, 09K, 09V → 10 score → 11 PV → 12 Wo → 03 D [hosts 12] → 04 Q [hosts 09Q, 11] → 05 KV [hosts 09K, 09V] → 06 softmax [hosts 07, 10] → TAB → ZS → IO-in → IO-out`;
- **M: 40 rows** (36 coefficient rows + `b_re, b_im, u_re, u_im`), opened once, **28 functionals** in the order `[Γ_s if standalone] eval_s …` then the five batched `Γ_host = c_h·G_h − Σ ν_s κ_s c_s·G_s` (κ = 32 for the row-sum slot, whose host term is constant in `j`; 1 elsewhere). No standalone total of a hosted slot or of a host exists;
- each private slot publishes ONE masked scalar `s + c·G`; nothing reconstructs a claimed sum in the clear; the score and PV slots carry two extension rounds with the `((1−e₂)(1−e), (1−e₂)e)` / `((1−e₂)(1−e), e₂)` coefficient forms;
- every claim site has its own reserved pair; each commitment has a proximity pair; histograms are committed A rows; no helper sum, no histogram, no collapse.

`(main rounds, extension rounds, degree)` per slot: `(9,1,3) (5,1,3) (9,1,3) (11,1,3) (4,1,2)×3 (3,2,2) (5,2,2) (4,1,2) (9,1,4) (9,1,4) (8,1,4) (11,1,4) (8,1,3) (8,1,2) (9,1,2) (9,1,2)`; largest mask row `L = 12·4 + 2 = 50`.

**Recorded deviations** (each is stated in `layout.rs` and bound into the transcript through the schedule digest):

1. **Row numbering is this module's, not the JSON's.** `zk60_private_attention_schedule.json` numbers rows of the legacy `AttnLayout` (both norm sites, residual 2, FFN seams, padded heads). This component is the attention half at one geometry with its own planes: 75 A sites and 35 H sites instead of the JSON's 135-claim inventory. **The rank tool has NOT been re-run on this layout**; that is the first thing the security reviewer should do (§6, R-1).
2. **One U8 table instead of Int16 / U16 / Prob / Srem / Win.** This is the lever the construction records in §6 ("recorded, not proposed"). Consequence: every table is one row, so there are **no block masks and no multi-row histogram slots**; A is 306 rows and H 290 instead of 1,487 and 2,490. The price is more planes (limbs) and more lookups. If the reviewer wants the declared table set instead, only `layout::lookups`, the limb planes and the TAB slot change.
3. **Softmax zero-check degree 4, not 5**: the exp lookup has its own single-lookup helper, so no helper relation multiplies two lookups with the public causal mask.
4. **W is not committed.** P1 weights are public and tiny here; the verifier evaluates the folded weight MLE itself and the transcript binds a digest of the exact words. No W opening, so no W rank question under P1. P3 is not implemented.
5. **Additional refusals** beyond the construction's list: a zero host batching challenge ν, and an extension challenge equal to 1 (a `(1−e)` data coefficient of zero). Both are functions of challenges only and are never resampled.

## 4. Privacy mechanics, premises, and what stays open

Mechanics implemented: one OS randomness stream per attempt (`ZkRng::from_os`, no seed API); all mask rows drawn before their commitment; header, public digest, endpoint policy and schedule digest absorbed before any challenge; A root → M root → (β, γ, α) → H root → slots; every published scalar absorbed before its slot's first round challenge, terminals after the extension round(s); `prove` takes the endpoint owners **by value** and every owner (A, H, M, both endpoints) is dropped inside the call on success and failure; one opening per commitment.

Whole-commitment check, not per-site rank: `protocol::audit_claims` runs on the real claim list in **both** prover and verifier and refuses unless every reserved pair row is touched by exactly one claim with nonzero coefficients, every evaluation claim carries exactly its own adjacent pair, only the LogUp sum claim is pairless and it covers the zero-sum rows, and no claim reaches the proximity pair. Under that structure the map (one pair per group, proximity pair) → (group vectors, proximity vector) is block triangular with invertible diagonal, so the opened vectors are jointly uniform for any data. The PCS challenge refusals (zero group coefficient, Fp-dependent proximity pair) are replayed from a cloned transcript before each opening.

**Premises that are NOT established by this delivery:**

- **D8 / D11 are open.** The endpoint commitments are caller-fixed roots. A prior authentication path or root-child hash query under such a root is allowed history; consuming the owner does not erase it, and this module does not claim it does. The general privacy game is unchanged.
- **The forced-challenge counterexample** (`ZK60_ENDPOINT_REUSE_DISPOSITION_20260918.md`) concerns two uses of one commitment passing their per-use checks while sharing mask coefficients. This profile opens every commitment once, so it neither triggers nor repairs that case: there is no joint-rank refusal across uses because there is no second use. A caller who prepares a second proof against the same endpoint values gets fresh commitments with fresh masks.
- The argument above is linear-algebraic and per commitment. Independence from the sampled columns / salted paths, the CFS channel (FA6's criterion on THIS slot table), cross-commitment correlation (A ↔ H helper planes, A ↔ endpoints share data but never masks), and transcript conditioning are **owed**: the captured-receipt joint-view gate of the construction's §7 has not been run, and no simulator is written.
- D9 (`fp()` reduction bias) applies unchanged. The witness builder's refusals depend on the private input, exactly as the kernel's do; a refusal publishes nothing but is itself observable to the caller.
- `no_published_word_is_a_small_integer` is a smoke test, not evidence of hiding.

## 5. Operation and byte counts (computed from the layout, unrun)

| Quantity | Value |
|---|---:|
| A rows (154 data + 150 site-pair + 2 proximity), 256 columns, rate 1/8 encoding of 512 symbols | 306 |
| H rows (218 data incl. `u` + 70 site-pair incl. `u'` + 2 proximity) | 290 |
| M rows | 40 |
| PCS opening groups: A / H / each endpoint | 30 / 8 / 1 |
| sumcheck rounds (main + extension), all slots | 129 + 20 |
| largest sumcheck domain | 2¹¹ (softmax, 25 tables, degree 4) |
| lookups: U8 / exp | 47,104 / 2,048 |
| receipt frame | 2,245,800 bytes (136 envelope + roots, 11,296 arguments, 223,232 M, 980,992 A, 768,000 H, 262,144 endpoints) |

`A_GROUPS = 30` and `H_GROUPS = 8` were counted by hand from the column-key rule. The prover and verifier compare the PCS's actual grouping against them and fail with `N opening groups, the schedule declares M` if I miscounted; the fix is those two constants (the wire shape follows). `prove_with_stats` returns a phase breakdown (commit A, commit M, helpers + commit H, 18 sumchecks, openings); the example prints it. Shared-box timings are diagnostic only; no timing was taken.

## 6. Review requests and interface requests to the parent

**R-1 (security reviewer).** Regenerate the pair-schedule rank check and the CFS slot check for THIS layout (75 A sites / 35 H sites; the 18-slot table of §3 with hosts `01←00, 10←09, 11←{04,08}, 12←{05,06}, 13←{03,07}` in this module's slot indices). `private_attention::schedule()` prints the declared schedule.

**R-2.** Re-derive the no-wraparound bounds of §2 and the isqrt / softmax exactness arguments; check that every slot polynomial has a public factor in every monomial (the extension-round premise stated at the top of `argument.rs`).

**P-1 (parent, optional, not needed to build).** `zk::fresh_poc::check_opening_challenges` and `determinant` are `pub(super)`. This module carries its own 12-line copy of the challenge refusal in `protocol.rs`, because `fresh_poc::check_masks` refuses sub-row slices, which this layout uses for the 32- and 64-entry planes. Making `check_opening_challenges` `pub(crate)` would let both profiles share one routine. I did not edit that file.

**P-2 (parent, naming only).** Endpoints are taken through `private_seam::PreparedPlane::into_ffn_endpoint` (`pub(crate)`), with this profile's own seam slots (21–24) so an FFN-IO endpoint cannot be presented here. A neutrally named alias would read better; no behaviour change is requested.

**P-3.** `private-block-kernel` is not a dependency of hashline, so the independent expected state in the tests is `causal_oracle::FixedCausalOracle` (which the kernel is pinned to). A kernel parity test would need a dev-dependency, i.e. a `Cargo.toml` change outside this lane.

## 7. Exact unrun commands

Run from the repo root of the worktree. The toolchain path is the one the repo's docs use. `hashline`'s release profile is `lto = "fat", codegen-units = 1`, so the **first release build may exceed five minutes on the loaded box**: it is given in the detached, locked form; the rest are light once the build exists.

Compile gate (light, no lock):

```
~/.rustup/toolchains/1.97.0-x86_64-unknown-linux-gnu/bin/cargo check --offline --manifest-path hashline/Cargo.toml --lib --tests --examples
```

Release build + unit tests, detached and queued (the parent owns the heavy queue):

```
setsid nohup bash -c 'flock /tmp/zk-heavy.lock ~/.rustup/toolchains/1.97.0-x86_64-unknown-linux-gnu/bin/cargo test --release --offline --manifest-path hashline/Cargo.toml --lib private_attention -- --test-threads=1 --nocapture >> /tmp/zk60-loop-20260917/private-attention-unit.log 2>&1; echo $? > /tmp/zk60-loop-20260917/private-attention-unit.done' >/dev/null 2>&1 &
```

Then, light (each is a handful of proofs at a 2¹¹ domain):

```
~/.rustup/toolchains/1.97.0-x86_64-unknown-linux-gnu/bin/cargo test --release --offline --manifest-path hashline/Cargo.toml --test zk60_private_attention -- --test-threads=1
~/.rustup/toolchains/1.97.0-x86_64-unknown-linux-gnu/bin/cargo test --release --offline --manifest-path hashline/Cargo.toml --doc private_attention
~/.rustup/toolchains/1.97.0-x86_64-unknown-linux-gnu/bin/cargo run --release --offline --manifest-path hashline/Cargo.toml --example zk60_private_attention -- prove /tmp/zk60-attn-demo
~/.rustup/toolchains/1.97.0-x86_64-unknown-linux-gnu/bin/cargo run --release --offline --manifest-path hashline/Cargo.toml --example zk60_private_attention -- verify /tmp/zk60-attn-demo
```

The `verify` command is the fresh-process check: it reads two files, rebuilds the public statement itself, accepts the frame and refuses three corrupted copies. The demo directory holds only the public receipt and the public endpoint policy; no witness, salt, output or log of private values is written anywhere by any of these commands. Freeze gates: nothing frozen was touched, but `python3 -m unittest discover -s tests` should be re-run by the integrator as usual.

If the unit tests fail, the most likely causes, in order: a compile error from writing without a compiler; `A_GROUPS` / `H_GROUPS` (§5); a table-index slip in one slot's polynomial in `argument.rs::define` (the failing slot is named in the verifier's error, `slot NN [name]: …`).
