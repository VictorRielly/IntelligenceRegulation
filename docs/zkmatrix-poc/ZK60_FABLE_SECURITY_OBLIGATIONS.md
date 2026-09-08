# FA5 — arithmetic and security obligations of the fixed T32/d16/f16 block

**Status: analysis delivered, closure open.** Reviewer: Claude Fable 5.1, independent reviewer, 2026-09-07 session. Source pin: 52a13d1 (integrator baseline; review worktree /home/victor/wt-zk60-fa, branch zk60-fable-review).

This is an independent read-only review of the exact fixed integer profile approved by A00 ([ZK60_BLOCK_CONTRACT.md](ZK60_BLOCK_CONTRACT.md)), executed by E1 ([ZK60_CAUSAL_ORACLE.md](ZK60_CAUSAL_ORACLE.md)) and proven publicly by B3/B4/B5 ([ZK60_PUBLIC_BLOCK.md](ZK60_PUBLIC_BLOCK.md), [ZK60_PUBLIC_CHAIN.md](ZK60_PUBLIC_CHAIN.md)). Every row cites the verifier code it rests on. Where a row rests on the honest oracle or on frozen proof bytes instead of a proof-level bound, the row says so. No production code was changed; no security number from the lattice-era [SOUNDNESS_REFERENCE.md](SOUNDNESS_REFERENCE.md) is inherited (section 4.7 says what does and does not carry over). The table is mirrored row for row in `results/zk60_fable_fa5_obligations.json`; the numeric checks are in `results/zk60_fable_fa5_isqrt_alias.txt` and `results/zk60_fable_fa5_bounds.txt`.

## 1. Profile and parameter assumptions

| Item | Value used by every row |
|---|---|
| profile | A00 fixed T32/d16/f16, H=2, Hkv=1, d_h=8; INT16 x/AO/r1/r2; round RMSNorm tn=11 Cn=1024 ceps=1 wrho=29 n_limbs=2; fE=fP=9 fRo=7; shifts q/k/v/qr/kr/s/o/ao/r1/r2 = 7/7/7/7/7/6/9/7/0/0; FFN shifts (7,0,14,6) silu(-3,-11); PCS log_cols=8 inv_rate=8 Q=256 (nn=2048, 11-level Merkle) |
| field | Goldilocks p = 2^64-2^32+1 (log2 p = 63.99999999966); challenges in F_{p^2}, log2|F_{p^2}| = 128.000 |
| challenge_bias | challenge_fp2 = two independent 128-bit draws reduced mod p (transcript.rs:96-112): point probability <= (1+2^-64)/p per coordinate; every Schwartz-Zippel term below carries a (1+2^-64) factor (ignored) |
| column_indices | challenge_indices: 8 bytes per index masked to 11 bits, with replacement (transcript.rs:119-131); with-replacement sampling gives exactly the (1-e/nn)^Q bound |

The profile has no padded heads (hp = heads = 2, kp = Hkv = 1), no padded columns (dp = d = 16), `nb_d = nb_f = 1` in the FFN, and the seam point equals the FFN zero-check-D point. Sizes: attention A = 108 rows x 256, H = 106 rows, W = 4 rows; FFN A = 20, H = 16, W = 3 (public_block_wire.rs:120-157).

## 2. Classification legend

- **ACTUAL verifier constraint** — the verifier code path rejects a violating proof (file:line and the check are cited).
- **CHECKED public precondition** — checked before the argument by A00 `validate`, `check_profile`, `check_roots` or the wire codec; the arithmetic argument assumes it.
- **HOST-ONLY assertion** — a `debug_assert`/`assert`/refusal in the prover, oracle or packer that a malicious prover simply does not run.
- **UNPROVED assumption** — nothing in the verifier or its preconditions establishes it.
- **NOT APPLICABLE to this profile (stated for the record)** — recorded so closure can point at the owning task (FA1-FA4).

Host-oracle agreement (the E1 fixtures, `zk60_sequence_equivalence`) and frozen proof bytes are evidence about the honest prover only; no row below is classified ACTUAL on that basis.

## 3. Obligation table

### R01 — Field/integer conversion: every committed plane is a canonical Goldilocks residue and its integer meaning is the canonical lift of the table value it is looked up against

- **Classification:** ACTUAL verifier constraint
- **Source:** hashline/src/field.rs:27-34 (`Fp::new`, `Fp::from_i64`), :199-203 (`Fp2::from_bytes` reduces once, does not reject); hashline/src/public_block_wire.rs:213-216 and :396-400 (wire `fp` rejects words >= P); attention.rs:1271-1285 (`fill` writes `Fp::from_i64`); attention.rs:2729-2778 (LogUp identity, table rows via `Tbl::row` 890-898 and `Fp2::from_i64`)
- **Parameter assumption:** Goldilocks p = 2^64-2^32+1; every table value |v| < 2^16 so the map v -> Fp::from_i64(v) is injective on each table
- **Evidence / counterexample:** A committed field element passes a lookup only if it equals Fp::from_i64(v) for some table row v (LogUp multiset argument, R12-R14). Integer semantics therefore hold for every looked-up plane; planes that are not looked up (zsel, E, m, Sum, D, Dsq, a1, a2) get their integer meaning from other relations (R09, R16-R19). The B4/B5 byte decoder rejects non-canonical words before any verifier runs (public_block_wire.rs:396-400).
- **Remaining gap:** The legacy `Fp2::from_bytes`/`AttnProof::to_bytes` flat encodings have no decoder and would silently alias words in [P, 2^64) to canonical values; they are not on the B4/B5 path. Typed (in-process) B3 verification accepts whatever `Fp` the caller constructs; no typed-API canonicality check exists (H1 report states this).

### R02 — Integer class endpoints: the proof's classes are Int8 = [-128,127], Int16 = [-32768,32767], U16 = [0,2^16), U8 = [0,256); the honest oracle uses the narrower [-127,127] / [-32767,32767]

- **Classification:** ACTUAL verifier constraint
- **Source:** attention.rs:876-888 (`Tbl::index`: Int8 accepts -128, Int16 accepts -32768); attention.rs:201-208 (`Cls::limit` 127/32767/8388607 is the *host* limit); causal_oracle.rs:284-302,370 (`quantize(.., -127, 127, ..)`), :382,388,435 (`-32768..=32767`); layer.rs:1410-1421 (`multiplicities_v3` Int16 [-32768,32767]); tables_v3.rs:94-104 (int16out generator clamps to +-32767)
- **Parameter assumption:** Fixed profile classes: x/AO/r1/r2 = Int16, xn8/xm8/q8/k8/v8/qr8/kr8/o8/s8 = Int8, FFN g8 in ACT16 domain [-128,127], u16/h16/z16 Int16
- **Evidence / counterexample:** Verifier-side class is exactly the table set (R12). The proof therefore ACCEPTS witnesses with s8 = -128, x = -32768 etc. that the oracle refuses; all no-wrap bounds in this document use the proof's (wider) classes.
- **Remaining gap:** Documented semantic difference only (no soundness break found): the -128 score corner changes which position attains the masked maximum (R20). A00 does not pin the proof's class endpoints in its digest; the oracle's narrower range is HOST-ONLY.

### R03 — Attention requantisation identities acc = 2^sh * y + r with balanced remainder windows (Q, K, V, QR, KR, S, O, AO, residual r1/r2)

- **Classification:** ACTUAL verifier constraint
- **Source:** attention.rs:2574-2578 (QKV: acc_q = cq*2^sh_q + crq feeds the sumcheck claim), :2608 (score: cs8*2^sh_s + crs), :2660 (PV: co8*2^sh_o + cro), :2714 (Wo: ao_v*2^sh_ao + crao), :2378-2382 (residual pins), :1619-1622 (`Extra::Rope` 2^sh y + r); window tables layer.rs:1234-1249 (`rem_rows`, `rem_value`, `rem_index`: rows 2^sh, values i - 2^(sh-1); sh <= 0 -> the single value 0), attention.rs:2036-2051 (`Win(sh)` lookups), tables_attn.rs:77-80 (`tag_win_a`)
- **Parameter assumption:** sh_q = sh_k = sh_v = 7, sh_qr = sh_kr = 7, sh_s = 6, sh_o = 9, sh_ao = 7, sh_r1 = sh_r2 = 0 (causal_oracle.rs:121-153); all accumulators < 2^22 (R05)
- **Evidence / counterexample:** Each identity is a linear relation between MLE evaluations at a transcript-random point (Schwartz-Zippel, error <= arity/|F_{p^2}|) that then holds per element in F_p; since |2^sh y + r| < 2^25 and |acc| < 2^22 the field identity is an integer identity; y in class and r in [-2^(sh-1), 2^(sh-1)) determine y = floor((acc + 2^(sh-1))/2^sh) uniquely (export_v3.rs:37-44 states the balanced form). For sh = 0 the window is {0}: xres1 = x + ao exactly (an overflowing input has no witness).
- **Remaining gap:** None for the fixed profile. `pow2_signed` (layer.rs:1252-1254) inverts 2^-sh for negative shifts; the profile has none (A00 bounds shifts to 0..=16, private_block_contract.rs:274-285).

### R04 — FFN v3 requantisation identities, `int16out` membership (fused (g8, a16) pair in the frozen ACT16 member), INT16 class of u16/h16/z16, remainder windows of rg/ru/rh/rd, Hadamard a16*u16 = 2^sh_h h16 + rh

- **Classification:** ACTUAL verifier constraint
- **Source:** layer.rs:2177 (`c_had`), :2178-2180 (`helper_constraint` for (g8+beta*a16, rg), (u16, ru), (h16, rh)), :2182 (f1: g8*2^sh_g + rg, u16*2^sh_u + ru folded into zcF), :2205-2207 (zcD: (z16, rd) helper, z16*2^sh_z + rd), :2220-2240 (table side: ACT16 rows i-128 + beta*table[i], INT16 rows i-32768, rem windows); statement/table pin layer.rs:1394-1405 and private_block_contract.rs:327-332; tables_v3.rs:134-141 (`int16out_member` regenerates and digest-checks)
- **Parameter assumption:** shifts (sh_g, sh_u, sh_h, sh_z) = (7, 0, 14, 6); frozen member silu (-3,-11) digest 1001c138...; d = f = 16
- **Evidence / counterexample:** Same pin/lookup pattern as R03. The fused pair binds a16 = table[g8+128] as field elements (R14). The FFN never range-checks its own X plane: in the block it inherits X in Int8 from xm8's lookup through the X seam (R24); the standalone FFN proof leaves |X| unproven.
- **Remaining gap:** Standalone `verify_layer_v3` has no X range fact; only the composed block supplies it. W (Wg/Wu/Wd) entries are not range-checked (R31).

### R05 — No-wrap of every accumulation: QKV (inner d=16), RoPE (2 terms), scores (inner d_h=8), PV (inner T=32, P <= 2^9), Wo (inner 16), FFN gate/up (inner 16), FFN down (inner 16 of Int16 * Int8)

- **Classification:** ACTUAL verifier constraint
- **Source:** attention.rs:2558-2727 (the five matmul sumchecks and their terminal pins); layer.rs:2107-2157 (gu and d matmul sumchecks); operand ranges from the lookups of R02-R04 and the public int8 weights (R31)
- **Parameter assumption:** |xn8|,|q8|,|k8|,|v8|,|qr8|,|kr8|,|o8| <= 128; |W| <= 128 (registrar); P <= 512; |h16| <= 32768; |C|,|S| <= 128 (rope tables)
- **Evidence / counterexample:** Bounds (this document, verified in python): QKV/Wo/FFN gate-up acc <= 16*128*128 = 2^18; RoPE acc <= 2*128*128 = 2^15; score acc <= 8*128*128 = 2^17; PV acc <= 32*512*128 = 2^21; FFN down acc <= 16*32768*128 = 2^26; Hadamard <= 32767*32768 < 2^30; residual sums <= 2^16. All < 2^31 << p/2 = 2^63, so every field identity proven at a random point is an integer identity once the operands are in their looked-up classes.
- **Remaining gap:** Weight range is an input assumption (R31): a registrar that approved a root over non-int8 words (e.g. 2^40) would void every bound in this row without any verifier refusal.

### R06 — No-wrap of the FFN Hadamard/requant chain a16*u16 - 2^14 h16 - rh = 0 and of the down-projection requant

- **Classification:** ACTUAL verifier constraint
- **Source:** layer.rs:2177 (`c_had`), :2183 (h16 folded into zcF as f5), :2207 (z16*2^sh_z + rd)
- **Parameter assumption:** a16 in [-570, 32512] (frozen member min/max, tables_v3.rs:169-170) or generally |a16| <= 32767; |u16|,|h16| <= 32768; sh_h = 14; sh_z = 6
- **Evidence / counterexample:** |a16*u16| < 2^30, |2^14 h16| <= 2^29, |rh| < 2^13: sum of magnitudes < 2^31. Exact.
- **Remaining gap:** None for the fixed profile.

### R07 — No-wrap and exactness of the two residual pins xres1 = requant(x*2^sh_x1 + ao*2^sh_a1, sh_r1) and xres2 = requant(xres1*2^sh_x2 + z16c*2^sh_z2, sh_r2)

- **Classification:** ACTUAL verifier constraint
- **Source:** attention.rs:2374-2382 (`residual pin 1/2` on claimed evaluations at the zero-check-D point rho); class lookups d_lookups attention.rs:2022-2043; A00 scale equations private_block_contract.rs:302-314
- **Parameter assumption:** sh_x1 = sh_a1 = sh_r1 = sh_x2 = sh_z2 = sh_r2 = 0 (fixture); all four planes Int16; rr1, rr2 in Win(0) = {0}
- **Evidence / counterexample:** x + ao = xres1 and xres1 + z16c = xres2 hold exactly in the integers because |lhs| <= 2^16 and xres in Int16; a saturating input has no valid witness (the oracle refuses at causal_oracle.rs:388,435, the verifier refuses via the Int16 lookup).
- **Remaining gap:** Exponent equations (which words mean which scale) are only bound by the A00 digest (R30); the arithmetic proof itself checks words, not scales (zk60_block_contract.rs test `equivalent_integer_words_with_changed_boundary_scale_are_not_equal_values`).

### R08 — Norm sum-of-squares rows: SS_t = sum_i x[t,i]^2 for both norm sites, tied to the committed a1/Dsq rows

- **Classification:** ACTUAL verifier constraint
- **Source:** attention.rs:2255-2274 (degree-3 sumcheck over the D domain, claim = (a1+Dsq-ceps)(r_t) batched with lambda_ss; terminal on the class-reconstructed x_in / xres1 planes)
- **Parameter assumption:** x in Int16 (16 columns) -> SS <= 16*32768^2 = 2^34; ceps in 1..=16 (A00 validate_norm)
- **Evidence / counterexample:** SZ over lambda_ss then r_t gives per-row equality; SS < 2^35 << p so the field sum is the integer sum.
- **Remaining gap:** Exactness of D itself is R09.

### R09 — Norm isqrt: D_t = isqrt(SS_t + Ceps) exactly, i.e. the committed D row is a small nonneg integer with D^2 <= SSe < (D+1)^2

- **Classification:** ACTUAL verifier constraint  **[severity: HIGH for deployment profiles with n_limbs >= 3; NONE for the fixed profile (excluded by derivation); documentation/test debt for the fixed profile]**
- **Source:** attention.rs:2242-2253 (`isqrt: a2 = 2D - a1`, `a1 limbs`, `a2 limbs` pins at r_t), :2276-2299 (zero-check Square Dsq = D*D), :2532-2556 (LM zero-check: a1/a2 16-bit limbs in U16), norm.rs:1-29 (design), ATTENTION_INTEGER_SPEC.md 2.1
- **Parameter assumption:** a1, a2 each two U16 limbs -> a1, a2 in [0, 2^32); tn = 11; n_limbs = 2 so rho, sigma in [0, 2^32) (R10); Cn = 1024; x Int16, gamma int8
- **Evidence / counterexample:** D is NOT range-checked directly. Even branch (a1+a2 even): D = (a1+a2)/2 <= 2^32-1, D^2 <= (2^32-1)^2 = p - 2^32 < p, a1 + D^2 < p, so SSe = a1 + D^2 and a2 = 2D - a1 hold over the integers and force D = isqrt(SSe): EXACT. Odd branch: D = k + (p-1)/2 with k^2 - k + a1 = SSe + (p-1)/4 satisfies the SS sumcheck, both isqrt pins, the Square check and the a1/a2 limb ranges for EVERY int16 row (k = 2^31 whenever SS < 2^30; python scan: 100% of random rows admit a limb-range pair). It also satisfies NormDiv with y = 0 on every element, with rho = 2Cn x g + (2k-1)2^(tn-1) ~ 2^(31+tn). The fixed profile excludes it ONLY because rho ~ 2^42 exceeds the 2^32 two-limb range (margin 2^10). At tn = 0 the alias is excluded instead by the (p-1)/2 term of D*2^0 in NormDiv.
- **Derivation:** p = 1 mod 4; inv(2) = (p+1)/2, inv(4) = (3p+1)/4. For a1+a2 = 2k-1 odd: D = k + (p-1)/2, D^2 = k^2 - k + inv(4) mod p, so a1 + D^2 = SSe forces a1 + k^2 - k = SSe + (p-1)/4 (unique integer in range since LHS < 2^64+2^32 < SSe + (p-1)/4 + p). (p-1)/4 = 2^62 - 2^30, so k = 2^31 for SSe < 2^30 and a1 = 2^30 + SSe, a2 = 2^32 - 1 - a1, both < 2^32. NormDiv with y=0: rho = 2Cn x g + D*2^tn = 2Cn x g + (2k-1)*2^(tn-1) (mod p, exact integer for tn >= 1); sigma = (2k-1)*2^(tn-1) - 1 - 2Cn x g. Both ~ 2^(31+tn): 2^42 at tn = 11 > 2^32 (two limbs) but < 2^48 (three limbs).
- **Remaining gap:** SOUNDNESS GAP FOR OTHER PROFILES: any profile with n_limbs >= 3 (wrho > 32, e.g. an Int24 residual class at d = 4096: D <= 2^29, tn = 7 -> dvp = 2^37) and tn >= 1 accepts an all-zero norm output row (concrete counterexample reproduced in results/zk60_fable_fa5_isqrt_alias.txt). Fix candidates: a direct range fact on D (U16 lookup at this profile; U16+U8 limbs generally) or a parity/small-range fact on a1+a2. Until then the fixed profile's exactness rests on the (tn, n_limbs) coincidence derived here, which no source comment or test records.

### R10 — Norm division relation (ROUND form): y*(D*2^(tn+1)) + rho = 2*Cn*x*g + D*2^tn with 0 <= rho < D*2^(tn+1), via rho and sigma = D*2^(tn+1) - 1 - rho each in two U16 limbs

- **Classification:** ACTUAL verifier constraint
- **Source:** attention.rs:1602-1618 (`Extra::NormDiv`), :2324-2329 (both sites in zero-check D), :2363-2373 (`norm: sigma = 2 div - 1 - rho` on claimed values), :2030-2034 (rho/sig limbs in U16), norm.rs:72-84 (round form), :148-149 (host asserts)
- **Parameter assumption:** tn = 11, Cn = 1024, ceps = 1, wrho = 29 advertised, n_limbs = 2 -> proven range [0, 2^32) not [0, 2^29); D honest <= 131072 (R09)
- **Evidence / counterexample:** With D exact (R09): rho, sigma >= 0 and rho + sigma + 1 = 2D*2^tn (<= 2^30) give 0 <= rho < 2D*2^tn, and y*2D*2^tn + rho = 2Cn x g + D 2^tn (all terms < 2^37) has the unique integer solution y = floor((2 x g Cn + D 2^tn)/(2 D 2^tn)) = round-half-up(x g Cn / (D 2^tn)). The `norm_round` flag (attention.rs:247) is not read by the verifier: the argument is unconditionally the round form; A00 refuses norm_round = false.
- **Remaining gap:** The proven remainder width is the 16-bit chunk multiple (2^32), not `wrho` (ZK60_PRIVATE_BLOCK.md already notes this); this slack is exactly what makes R09 parameter-dependent.

### R11 — Norm output class y in Int8 and gamma vector range

- **Classification:** ACTUAL verifier constraint
- **Source:** attention.rs:2029,2032 (xn8, xm8 Int8 lookups); gamma read from the W commitment `gpack` rows attention.rs:2338-2339,2349-2352 (public W claims); causal_oracle.rs:527-576 (`cpu_weight_commitments` packs i8 gamma)
- **Parameter assumption:** |gamma| <= 128 assumed (int8 registrar); y in [-128,127] (proof) vs [-127,127] (oracle, norm.rs:148)
- **Evidence / counterexample:** y is looked up; gamma is a public committed plane whose root must equal the approved root (R31) but whose entries are never range-checked in the proof.
- **Remaining gap:** Gamma range is a registrar obligation (A00 report: 'Public-weight/gamma ranges cannot be established from a root alone').

### R12 — LogUp multiplicity histograms: exact table set, tags, row counts and per-table totals equal the number of lookups the layout performs

- **Classification:** ACTUAL verifier constraint
- **Source:** attention.rs:3249-3257 (`verify_attn`: count, tag order, `tb.rows(f_p)`, totals vs `lookup_totals` 2056-2070); layer.rs:2076-2094 (FFN: 2 + #distinct shifts tables, 256/65536/2^sh rows, totals tf/td); histograms absorbed before beta/gamma/alpha (attention.rs:3258-3261, layer.rs:2094-2097); wire caps public_block_wire.rs:60-80 (tags <= 400, total <= 65536)
- **Parameter assumption:** Attention tables at the profile: Int16(132) x_in/ao/xres1/xres2/z16c, Int8(131) xn8/xm8/q8/qr8/o8/k8/v8/kr8/s8, U16(128) rho/sig limbs and lm, Win(7)=343, Win(6)=342, Win(9)=345, Win(0)=336 (tag_win_a = 320 + sh + 16), Exp(129), Prob(130), Srem(14)=270; FFN: ACT16(3), INT16(4), rem(7)=79, rem(0)=72, rem(14)=86, rem(6)=78
- **Evidence / counterexample:** The histograms are public in P0. A value outside its table is counted into row 0 by the prover (attention.rs:1200-1214, layer.rs:1407-1409) so totals still match; only the identity (R13) catches it: the tamper tests in zk60_public_block / layer tests exercise this.
- **Remaining gap:** In the P1 target the histograms must be committed, not published (ZK60_PRIVATE_BLOCK.md item 2); inherited by FA3.

### R13 — LogUp helper columns: h = 1/(alpha - l1) + 1/(alpha - l2) per row enforced by hcon zero-checks; helper sums claimed on H equal the table side sum_i m_i/(alpha - t_i)

- **Classification:** ACTUAL verifier constraint
- **Source:** attention.rs:1565-1574 (`hcon`), :1640-1657 (`ZcPlan::eval`, degree 4), :2318-2344 (D), :2389-2408 (Q), :2429-2448 (KV), :2468-2481 (S, degree 5), :2536-2544 (LM), :2729-2777 (identity: `Cc::hsum` sum claims on H vs table side); layer.rs:293-308 (`helper_constraint`), :2214-2240
- **Parameter assumption:** alpha, beta, gamma in F_{p^2} drawn after A and the histograms are absorbed and before H is committed (attention.rs:2873-2881 / layer.rs prove; verify 3258-3262 / 2094-2098)
- **Evidence / counterexample:** hcon(h, l1, l2) = h(alpha-l1)(alpha-l2) - (alpha-l1) - (alpha-l2) = 0 forces h = 1/(alpha-l1) + 1/(alpha-l2) whenever both denominators are nonzero; both zero requires the committed value to equal alpha - gamma*tag, predicted before alpha is drawn (prob <= rows/|F|). Helper sums are PCS sum-claims on the H commitment (pcs.rs Claim.sum). Identity check attention.rs:2777 / layer.rs:2240.
- **Remaining gap:** None found. The per-helper sums are public in P0 (privacy, FA3).

### R14 — LogUp soundness: multiset equality of (value, aux, tag) triples between witness lookups and histogram-weighted table rows

- **Classification:** ACTUAL verifier constraint
- **Source:** attention.rs:2076 (`g(t) = gamma * tag`), :2118 (fused exp row d + beta*E), :2761 (table side v + beta*aux + gamma*tag); layer.rs:2178 (g8 + beta*a16), :2224
- **Parameter assumption:** N_attention = 26,624 lookups (this document's count from lookup_totals: 18*512 + 6*512 + 6*256 + 6*2048 + 512), N_ffn = 4,096; |F_{p^2}| = 2^128
- **Evidence / counterexample:** P(alpha,beta,gamma) = prod_j (alpha - phi_j) and Q = prod_i (alpha - psi_i)^{m_i} are monic in alpha of equal degree (totals checked, R12); P'/P = Q'/Q in alpha iff P = Q iff the triple multisets agree; otherwise P'Q - PQ' is a nonzero polynomial of degree <= 2N - 1 and the check fails to detect with probability <= (2N-1)/|F| + 2N/|F| (pole avoidance). Bound: 4N/2^128 = 2^-111.3 (attention), 2^-114 (FFN). This is a linear, not quadratic, term because (alpha, beta, gamma) are all uniformly random after the commitments.
- **Derivation:** LogUp with fused encodings: SZ on the trivariate polynomial P'Q - PQ' of total degree <= 2N-1; monicity from equal totals.
- **Remaining gap:** The bound assumes the histograms and A are committed before (beta, gamma, alpha) (true) and that H is committed before the zero-check challenges (true). The pcs.rs/attention.rs docs state no LogUp error term; this document supplies it.

### R15 — Causal mask: the mask [j <= t] is a public function, sM = mask*s8 - 127*(1-mask) is a derived read (never committed)

- **Classification:** ACTUAL verifier constraint
- **Source:** attention.rs:1693-1695 (SPlan: sm = mask*s8 + 127*mask - 127), :2012-2019 (`mask_table`), :1885-1895 (`mask_mle` verifier-side MLE), :2497,2524 (verifier computes it)
- **Parameter assumption:** T = 32 prefill; sentinel -127 = Int8 lower endpoint of the oracle (not of the proof's table, R02)
- **Evidence / counterexample:** Verifier recomputes the mask MLE itself; no committed mask exists to tamper with.
- **Remaining gap:** None.

### R16 — Row maximum m and attainment: d = m - sM in [0,255], zsel binary, sum_j zsel = 1 per (h,t), zsel*d = 0

- **Classification:** ACTUAL verifier constraint
- **Source:** attention.rs:1696-1697 (c1: fused (d, E) in Exp -> d in [0,255] via Tbl::Exp index 883), :1704-1705 (c4 zsel(1-zsel), c5 zsel*d), :2506-2530 (row-sum sumcheck: claim sum_cl + lam_z*1 proves sum_j mask*E = Sum and sum_j zsel = 1 at a random (h,t) point)
- **Parameter assumption:** d_h = 8, eS_raw = 0, fE = 9; Exp table has 256 rows
- **Evidence / counterexample:** d >= 0 for all j gives m >= max(sM); exactly one j with zsel = 1 and d = 0 gives m = sM[j] <= max: m is exactly the max of the masked array (integers, since d in [0,255] and sM in [-128,127] as looked-up values). zsel non-uniqueness under ties changes no output (spec 2.5). m is bounded as an integer through d and sM even though not looked up.
- **Remaining gap:** None for soundness. Off-support attainment is admitted (R20).

### R17 — Exp table member: E = ExpT_(eS,d_h,fE)[d] from the frozen generator, digest-pinned and regenerated by the verifier; E pinned by the fused lookup

- **Classification:** ACTUAL verifier constraint
- **Source:** attention.rs:2229-2231 (`exp_member` regenerated, digest compared to c.exp_digest), tables_attn.rs:88-132 (generator + structural asserts + digest); statement absorbs digest attention.rs:2821; A00 pins digest private_block_contract.rs:333-336
- **Parameter assumption:** member (0, 8, 9): E[0] = 512, E[1] = 360, E[2] = 252, E[d] = 0 for d >= 20 (python replication of the generator)
- **Evidence / counterexample:** The verifier trusts only its own regeneration; a prover cannot substitute a table. The fused pair (d + beta*E) in the histogram side uses the regenerated `exp`.
- **Remaining gap:** Determinism of f64 `exp`/`floor` across platforms is a MODEL assumption (a drift is a hard stop, never a silent table).

### R18 — Softmax denominator: Sum[h,t] = sum_{j<=t} E[h,t,j] (masked row-sum sumcheck), Sum > 0, Sum bounded by the remainder limbs

- **Classification:** ACTUAL verifier constraint
- **Source:** attention.rs:2506-2530 (row sums), :1698-1699 (c2: sigma = Sum - 1 - rho and rho both in Srem(wrho_s)), :2067 (Srem total 2*ls)
- **Parameter assumption:** wrho_s = fE + log2 T = 14 (A00 checks, private_block_contract.rs:342-345); T = 32
- **Evidence / counterexample:** Sum = 1 + rho + sigma with rho, sigma in [0, 2^14) gives 1 <= Sum <= 2^15 - 1 as integers; the row-sum sumcheck pins Sum to the actual masked sum (<= 32*512 = 2^14). Minimum possible Sum: if every on-support s8 = -128 (proof class) then m = -127 is attained off support and Sum >= E[1] = 360 > 0; otherwise the attaining on-support position contributes E[0] = 512. No zero denominator is reachable by a valid witness.
- **Remaining gap:** None. The oracle's stricter Sum in [512, 16384] (causal_oracle.rs:344) is HOST-ONLY.

### R19 — Softmax division: on support P*Sum + rho = 2^fP * E with 0 <= rho < Sum; off support P = rho = 0; P in [0, 2^fP]

- **Classification:** ACTUAL verifier constraint
- **Source:** attention.rs:1700-1703 (c3 = mask*on + (1-mask)*(P+rho)), :1698-1699 (rho, sigma ranges), :1431 (`Prob` lookup of P), Tbl::Prob 884 (513 rows)
- **Parameter assumption:** fP = 9; Sum <= 2^15; E <= 512
- **Evidence / counterexample:** |P*Sum + rho| < 2^24 + 2^14 and 2^9 E <= 2^18: no wrap; rho <= Sum - 1 (sigma >= 0) makes P = floor(2^9 E / Sum) unique; off support P + rho = 0 with both nonneg small integers forces P = rho = 0 (no wrap since P + rho < 2^15). Row-stochasticity is deliberately not claimed (spec 2.5).
- **Remaining gap:** None.

### R20 — The -128 score corner: the proof's masked-array maximum includes the -127 sentinel, so a row whose on-support scores are all -128 has m = -127 attained off support

- **Classification:** ACTUAL verifier constraint
- **Source:** attention.rs:876-879 (Int8 admits -128), :1704-1705 (zsel unmasked); causal_oracle.rs:284-302 ([-127,127] refusal), :326-328 (attainment must be on support)
- **Parameter assumption:** eS_raw = 0, d_h = 8: E[1] = 360
- **Evidence / counterexample:** The declared function is still a deterministic function of s8 (m unique, P/rho forced), so no false statement is accepted; the accepted function at that corner differs from the oracle's by a uniform shift of every d by 1 (all E scale by ~e^-lambda before rounding).
- **Remaining gap:** Semantic corner documented in ZK60_CAUSAL_ORACLE.md; the oracle excludes it, the proof admits it; A00's digest does not pin the narrower class. Not a soundness gap.

### R21 — RoPE rotation: 2^7 * qr8 + rqr = C*q8 + S'*q8_flip (and the same for K), with public cos/sin tables at fRo = 7, digest-pinned, and the coordinate-flip read

- **Classification:** ACTUAL verifier constraint
- **Source:** attention.rs:1604-1605,1619-1622 (`Extra::Rope`), :2392,2432 (plans), :2403,2443 (flip table i ^ half), :2410-2418,2450-2458 (verifier: `rope_mle` and the flipped-point claim), :2232-2235 (rope digest check), tables_attn.rs:134-168
- **Parameter assumption:** base 10000.0 (A00 pins bits), fRo = 7, |c|,|s| <= 128, T_max = 32 = T
- **Evidence / counterexample:** RoPE tables are statement constants recomputed by the verifier; the flipped read is a separate PCS claim on q8 at the point with coordinate log_t+log_hp negated. |C q + S q'| <= 2^15; requant window Win(7).
- **Remaining gap:** Absolute position offsets are unsupported: table row t is position t (R23).

### R22 — GQA/head padding map: the score matmul reads kr8 at the kv-head given by the high bits of the padded query-head index; the PV matmul reads v8 likewise; pad heads carry a dummy softmax

- **Classification:** ACTUAL verifier constraint
- **Source:** attention.rs:2603-2606,2639-2646 (score points [r_st, rg, r_lo, ri] / [r_sj, rg, ri]), :2656-2659,2691-2698 (PV points), :810-832 (`PadShape`), :1229-1268 (`dummy_head`)
- **Parameter assumption:** H = 2, Hkv = 1, d_h = 8: hp = 2, kp = 1, rep = rep_p = 2 -> no pad head, log_kp = 0 (the eq(r_hi, rg) factor is the constant 1)
- **Evidence / counterexample:** At the fixed profile the map is the identity on the head axis and the dummy-head code path is inactive (rep_p == rep).
- **Remaining gap:** The non-power-of-two head mapping and dummy heads are untested at this profile (PRIVATE_BLOCK.md asks for an audit); out of scope for A00.

### R23 — KV / position handling: prefill only; RoPE position = row index; no KV cache read/update relation; no sliding window; T = 32 exactly

- **Classification:** CHECKED public precondition
- **Source:** private_block_contract.rs:200-209 (shape T32 pinned), attention.rs:1-44 (module doc: 'prefill only'), causal_oracle.rs:20-25, ZK60_CAUSAL_ORACLE.md
- **Parameter assumption:** T = 32, positions 0..31
- **Evidence / counterexample:** A00 refuses any other T; positions are implicit in the layout.
- **Remaining gap:** Autoregressive decode, KV cache, absolute offsets and window transitions have no relation at all (A10 in ZK60_PRIVATE_BLOCK.md).

### R24 — Internal X seam: the attention's xm8 plane equals the FFN's X plane, checked as one MLE equality at the FFN zero-check-D point rho_d drawn after both A commitments

- **Classification:** ACTUAL verifier constraint
- **Source:** attention.rs:2895-2912 (`attn_seam`: claim on xm8 at pt vs `want_x` = FFN zcd_term[X]); layer.rs:2280-2314 (`v3_zcd_point` replay), :2031 (FFN opens X at rho_d with value zcd_term[c]); public_block_oracle.rs:166-175, public_block_receipt.rs:329-342; seam_points public_block_oracle.rs:235-251
- **Parameter assumption:** d = db = dp = 16 so nb_d = 1 and the seam point is rho_d itself (extra = 0); both planes are (t, i) row-major of 512 words
- **Evidence / counterexample:** Both claimed values are opened against their own commitments; equality of MLEs at a point drawn after both commitments implies plane equality with error <= 9/|F|. Ordering verified: attention A absorbed (attention.rs:2871) before the FFN transcript begins.
- **Remaining gap:** P0 only: the claimed values are public. The P1 seam needs the masked equality gadget (FA3).

### R25 — Internal Z seam: the attention's z16 copy (z16c) equals the FFN's Z output plane at rho_d

- **Classification:** ACTUAL verifier constraint
- **Source:** attention.rs:2901,2905,2908 (second claim in `attn_seam`), layer.rs:2032 (FFN Z claim at rho_d = zcd_term[nb_d + c]); tests zk60_public_block.rs:209-225 (`recommitted_residual_with_wrong_z_copy_reaches_second_seam_refusal`)
- **Parameter assumption:** as R24
- **Evidence / counterexample:** Same argument as R24; z16c is additionally Int16-looked-up (attention.rs:2041) so the residual pin (R07) operates on class-bounded words.
- **Remaining gap:** as R24.

### R26 — Residual seam between blocks: block 0's xres2 equals block 1's x_in

- **Classification:** ACTUAL verifier constraint
- **Source:** public_chain_receipt.rs:129-149 (`block_expectations`: the same public intermediate words are block 0's expected output and block 1's expected input), :340-354, :360-376; each side bound by R27; the private-seam gadget `layer_seam` attention.rs:2930-2947 is NOT used on this path
- **Parameter assumption:** B5 profile: exactly two blocks, layers 0 then 1, public intermediate tensor of 512 int16 words
- **Evidence / counterexample:** Equality is through a public tensor bound into both proofs (R27), not an MLE equality between two commitments; tests zk60_public_chain.rs:301-360 and :437-499 reach the arithmetic-endpoint refusals.
- **Remaining gap:** P0 only. The committed-to-committed private seam (A02/S2, `private_seam.rs`) is experimental and not integrated; the two-block private chain is UNPROVED.

### R27 — External I/O binding and request context: x_in equals the expected public input words and xres2 the expected output words; the context/request digest is bound before any commitment

- **Classification:** ACTUAL verifier constraint
- **Source:** public_block_receipt.rs:260-284 (`bind_endpoints`: role absorbed, fresh point, `cls_claim` vs `eval_mle_base(words)`), :177-185 (transcript absorbs contract and expected digests first), :36-55 (expected digest over context + input + output), :293-297 (request/approval equality); public_chain_receipt.rs:118-125 (per-block context derive-key)
- **Parameter assumption:** WORDS = 512 int16 per tensor; context must be nonzero
- **Evidence / counterexample:** MLE equality at a random point drawn after both A commitments and the seam; the claim is then opened in the attention A PCS opening. Stateless verifier: identical bytes under identical expectations remain valid by design.
- **Remaining gap:** Replay protection (nonce consumption) is an application obligation, not proven here. The expected-state file's provenance is trusted input.

### R28 — Zero-denominator behaviour: a table-side denominator alpha - t_i = 0 is refused (not a panic/abort); witness-side zero denominators cannot be exploited

- **Classification:** ACTUAL verifier constraint
- **Source:** field.rs:228-234 (`batch_inverse2_checked`), attention.rs:2770-2777 (verifier branch only), layer.rs:2237-2238; field.rs:77 (`inv` asserts on zero: prover-side `batch_inverse2` attention.rs:2771, :1557 unchanged); ZK60_VERIFIER_HARDENING.md
- **Parameter assumption:** alpha uniform in F_{p^2}; table rows with nonzero counts <= 2^17
- **Evidence / counterexample:** Table-side: explicit Err before any allocation. Witness-side: hcon with alpha = l1 and alpha != l2 fails (-(alpha-l2) != 0); alpha = l1 = l2 would let any h pass but needs a committed value equal to alpha - gamma*tag before alpha exists (prob <= 2^-128 per row).
- **Remaining gap:** Availability only: a prover whose witness collides with alpha panics in its own batch inversion (attention.rs:1557); probability negligible. `Fp2::inv` norm c0^2 - 7c1^2 vanishes only at zero since 7 is a non-residue (field.rs:329).

### R29 — Transcript binding of the arithmetic statements: attention constants (shape, shifts, classes, norm consts, table digests) and FFN statement (layer, shape, signed shifts, act name, table digest) are absorbed before commitments

- **Classification:** ACTUAL verifier constraint
- **Source:** attention.rs:2801-2823 (`absorb_attn_statement`), layer.rs:1394-1405 (`absorb_statement_v3`), transcript.rs:25-30 (domain prefix 'hashline-v1/'), :44-52 (length-framed label and data)
- **Parameter assumption:** Not absorbed by the attention statement: `norm_round`, `rope_base` (covered by the rope digest), `e_r/e_xn/e_r1/e_ao/e_xm` exponents, `n_limbs` (layout-relevant; but the commitment row count check attention.rs:3243-3245 catches a layout mismatch), `Cls` endpoints
- **Evidence / counterexample:** In B3/B4/B5 the verifier reads every constant from the approved contract, so the transcript binding is between the verifier's own statement and the proof, and the contract digest (R30) covers the unabsorbed fields.
- **Remaining gap:** For the standalone attention/FFN verifiers the exponents (scales) are 'documentation' (attention.rs:236-238): two statements differing only in exponents produce identical transcripts. Not a soundness defect of the word-level relation, but the meaning of accepted words is then unbound.

### R30 — Transcript binding of the block context: approved contract digest (profile string, model/calibration identities, shape, layer, all exponents, shifts, classes, norm consts, table digest + bytes, PCS params, both W roots) and layer order

- **Classification:** CHECKED public precondition
- **Source:** private_block_contract.rs:411-524 (`digest_registration`, length-framed LE), :142-145 (`bind_public_statement`), :149-165 (`preflight_next_boundary`: consecutive layers, identical ids, matching residual scale/class); public_block_oracle.rs:119-125; public_block_receipt.rs:138-156 (`check_profile` pins the B3 calibration and layers 0/1), public_chain_receipt.rs:20-30
- **Parameter assumption:** Fixed P1 policy string; identities are caller-supplied nonzero 32-byte digests
- **Evidence / counterexample:** Every constant the verifier uses is a function of the approved object, and its digest is the second absorbed message of the proof transcript. Tests: 42 hostile metadata mutations and 7 'needs new approval' changes (zk60_block_contract.rs:264-376).
- **Remaining gap:** The identities are opaque: nothing authenticates that a `model_identity` corresponds to the weights behind the roots (FA4 domain, R36). `preflight_next_boundary` compares metadata only.

### R31 — Approved public weights and gamma: the proof's W commitment root equals the independently approved root, and the approved words are int8

- **Classification:** CHECKED public precondition
- **Source:** public_block_oracle.rs:130-145 (`check_roots`), public_block_receipt.rs:310-318; causal_oracle.rs:527-576 (`cpu_weight_commitments` from `Vec<i8>`), :251-267 (`FixedCausalOracle::new` compares roots); private_block_contract.rs:350-359 (root shape only)
- **Parameter assumption:** |W|, |gamma| <= 128 is assumed by every no-wrap bound (R05, R11) and by the RoPE/score/PV bounds
- **Evidence / counterexample:** Root equality is checked; word range is not provable from a root. The oracle path only ever computes roots from i8 tensors, but `from_trusted_registration` accepts any root.
- **Remaining gap:** UNPROVED at the registrar boundary: an approved root over out-of-class words voids R05/R11 without refusal. A public-weight range lookup (W in Int8) would close this at ~w_len lookups; alternatively the registrar's authenticated manifest must carry the range obligation.

### R32 — Exact message counts and structure: claimed values, sumchecks, collapse proofs, helper_sums, commitments' rows, opening shapes

- **Classification:** ACTUAL verifier constraint
- **Source:** attention.rs:2781-2783 (missing values -> Err), :3289-3291 (exact `vals` count), :3296-3298 (exact collapse count), :1966 (missing sumcheck -> Err), :3243-3245 (rows); public_block_wire.rs:99-159 (`shapes`: 12 sumchecks with exact (rounds, width), 4 collapses, 133|135 vals, rows 4/108/106 and 3/20/16, 256 queries, 2048 columns, 11-digest paths), public_block_receipt.rs:302-308 (135 vals, 12 sc, 4 collapse, empty helper_sums)
- **Parameter assumption:** fixed profile message schedule (ATTN_SC constant matches this document's sumcheck table)
- **Evidence / counterexample:** The B4/B5 path is exact-count on every vector. The typed B3 API does not reject EXTRA trailing `proof.sc` entries or non-empty `helper_sums` (unused field) — extra data is ignored, not refused.
- **Remaining gap:** Minor: typed-API extra-data acceptance contradicts the PRIVATE_BLOCK.md 'reject extra data' gate; no soundness impact found.

### R33 — Claim collapse (L5): many evaluation claims inside an aligned A range reduced to one claim at one point

- **Classification:** ACTUAL verifier constraint
- **Source:** attention.rs:2984-3063 (`collapse_range`: nu drawn after the claim values were absorbed via `Cc::take`; degree-2 sumcheck; verifier recomputes G(rho) = sum nu_k eq(p_k, rho) and checks fin = G(rho)*aval; aval absorbed), :3097-3120 (`collapse_plan` binary decomposition, env-selectable), public_block_receipt.rs:158-174 (`runtime_policy` refuses HL_FOLD/HL_NO_FOLD)
- **Parameter assumption:** 4 collapses of 14/13/11/10 variables at the profile
- **Evidence / counterexample:** Random linear combination of claims (error <= 1/|F|) then sumcheck (<= 2*rounds/|F|) then one PCS claim. The plan depends on `HL_FOLD`, a process-global environment variable: B4 refuses non-default settings; B3 does not.
- **Remaining gap:** Environment-dependent verifier schedule in the typed B3 API (a mismatch is a refusal, not a false acceptance).

### R34 — Tiny short-W adapter: 7-variable claims on the 128-word Wk/Wv halves lifted to 8-variable claims on the enclosing 256-word row

- **Classification:** ACTUAL verifier constraint
- **Source:** public_block_oracle.rs:187-233 (`lift_public_weight_claims`, both sides, exact layout checks), attention.rs:1126-1136 (`sub_point`), test zk60_public_block.rs:89-148
- **Parameter assumption:** log_cols = 8, log_wkv = 7, wk = 256, wv = 384, w_len = 1024
- **Evidence / counterexample:** Exact subcube evaluation: MLE of the row at (selector, point) equals the MLE of the half at point; no value is padded or assumed.
- **Remaining gap:** Any other short slice is refused. The legacy `pcs::col_key` underflow for short slices remains in pcs.rs:218-225 (B3 report).

### R35 — Hiding masks and privacy of openings, sumcheck messages, helper sums and histograms

- **Classification:** NOT APPLICABLE to this profile (stated for the record)
- **Source:** pcs.rs:1213-1224 (test contrast: the non-zk commitment opens raw int8 values at systematic columns), attention.rs:1714-1731 (`AttnProof` publishes mults, vals, sc, openings); public_block_oracle.rs:1-6 ('P0 ... ordinary commitments, claims, histograms and opening columns are public'); inherited FFN defect: ZK60_FFN_MASK_DIAGNOSTIC.md (X-at-p2 and h16-at-p5 singleton groups; complete 32-value recovery at T2, 256 functionals at T32), ZK60_FFN_MASK_INVENTORY.md, FA1/FA2/FA3 in ZK60_FABLE_QUEUE.md
- **Parameter assumption:** B3/B4/B5 are P0: no mask, no pad, no salt; the A00 object's P1 policy is not satisfied by them
- **Evidence / counterexample:** Not re-derived here (FA1/FA2 own it). For the P1 target the relevant code is pcs.rs:498-1024 (ZkOpts q_pad >= Q asserted at 625 and checked at 947; salted leaves; mask-site assertion 864-879 is a nonzero-support check, not a rank argument) and zk.rs (CFS masks, mask_specs_v3 at 2210).
- **Remaining gap:** UNPROVED for the P1 target (FA1 reproduced a disclosure). The hiding code's column term is 2^-106 (rate 1/4 with n+Q = 512 of 2048), not the P0 profile's 2^-127 (section 4.3).

### R36 — Approved private-model consistency (P3): fresh hiding W commitments prove consistency with an approved model

- **Classification:** NOT APPLICABLE to this profile (stated for the record)
- **Source:** model_identity.rs:1-30 (P1 public-W identity boundary only; P3 refused), zk60_identity_gap.rs (known gap test), FA4 in ZK60_FABLE_QUEUE.md
- **Parameter assumption:** profile is P1 with public approved W
- **Evidence / counterexample:** Not part of this profile; recorded so that closure can reference FA4.
- **Remaining gap:** P3 identity is a missing constraint (FA4 owns the specification).

### R37 — Host-only assertions and refusals that the verifier never sees, with their verifier-side backstops

- **Classification:** HOST-ONLY assertion
- **Source:** attention.rs:1503-1507 (`pack` panics on out-of-table values unless tamper mode; backstop R12-R14), :1974-1984 (`Ctx::check` asserts prover-side, returns Err verifier-side), :1961 (prover sum == claim assert; backstop sumcheck round 0), :2904-2905,2941 (seam asserts; backstop R24-R26), :1406 (pad-head o8 saturation; inactive), norm.rs:148-149 (narrow [-127,127] and division fact; backstop R10-R11 with the wider class), causal_oracle.rs:284-302,326-362,370-388,419-428,435 (oracle refusals; backstops R02-R19 with wider classes), export_v3.rs:374-388 (`range_ok` flags), layer.rs:1463
- **Parameter assumption:** release build: a failed assert aborts the prover, never produces a proof
- **Evidence / counterexample:** Every host-only check found has a verifier-side relation that is at least as strong at the proof's class endpoints (R02) except the oracle's narrower classes and its Sum window, which are semantic restrictions, not soundness backstops.
- **Remaining gap:** Host-oracle agreement (the E1 fixtures, the sequence-equivalence tests) and frozen proof bytes are evidence about the honest prover, not proof-level bounds; this row records that no row above rests on them.

### R38 — Shape/parameter preconditions that the legacy layout and table code assert instead of checking: powers of two, kv heads, shift/limb/width bands, allocation arithmetic

- **Classification:** CHECKED public precondition
- **Source:** private_block_contract.rs:176-375 (`validate` runs before `attn_layout_of` at :350; bounds shifts 0..=16, residual shifts 0..=8, exponents -16..=16, norm window tn <= 12, ceps 1..=16, wrho/n_limbs derived from the whole INT16 range, W shapes), attention.rs:811-819 (`PadShape` asserts), :57-59 / tables_attn.rs:73-79 (tag asserts), :1614-1616 (`1u64 << (tn+1)` needs tn <= 62), norm.rs:52-57 (`window_rule` asserts; not called by validate)
- **Parameter assumption:** all constants come from the approved object in B3/B4/B5
- **Evidence / counterexample:** A00's validate is the precondition layer; the layout constructor is only reached after it succeeds (A00 report: 'Validation happens before calling assertion-bearing table/layout helpers').
- **Remaining gap:** Standalone `verify_attn` with hostile `AttnConsts` can reach shift overflow / allocation asserts (availability, not false acceptance); out of scope for the profile.

## 4. Parameter and composition review

### 4.1 Challenge distributions

All challenges are drawn from F_{p^2} by `Transcript::challenge_fp2` (transcript.rs:103-112): two independent 128-bit blake3 draws reduced mod p, so each coordinate is within a factor (1 + 2^-64) of uniform and every Schwartz-Zippel bound below is exact up to that factor. A degree-d SZ test therefore buys 128 - log2(d) bits; a batching challenge over m terms buys 128 - log2(m) bits; each of the Q = 256 column indices is an independent 11-bit draw (transcript.rs:119-131, with replacement, which is exactly the regime of the (1 - e/nn)^Q bound). The transcript state is 32 bytes; domain strings are prefixed by `hashline-v1/` and every label and message is length-framed (transcript.rs:25-52), so no two absorbed byte strings are ambiguous.

### 4.2 Sumcheck degrees and rounds (fixed profile)

| # | relation | rounds | degree | polynomial |
|---|---|---:|---:|---|
| A1 | SS row sums | 9 | 3 | eq*(x^2+lam*xres1^2) |
| A2 | D^2 | 5 | 3 | eq*mu-batched (Dsq-D*D) |
| A3 | zero-check D | 9 | 4 | eq*(hcon pairs + NormDiv x2) |
| A4 | zero-check Q | 9 | 4 | eq*(hcon x3 + Rope) |
| A5 | zero-check KV | 8 | 4 | eq*(hcon x3 + Rope) |
| A6 | zero-check S | 11 | 5 | eq*(c0..c5) |
| A7 | row sums | 11 | 3 | eq*(mask*E + lam*zsel) |
| A8 | zero-check LM | 8 | 4 | eq*hcon |
| A9 | QKV matmul | 4 | 2 | xn8*(Wq+lam Wk+lam Wv) |
| A10 | score matmul | 3 | 3 | eq_g*QR*KR |
| A11 | PV matmul | 5 | 3 | eq_g*P*V |
| A12 | Wo matmul | 4 | 2 | o8*Wo |
| C1 | collapse block 0 | 14 | 2 | nu-weighted eq * A |
| C2 | collapse block 1 | 13 | 2 | nu-weighted eq * A |
| C3 | collapse block 2 | 11 | 2 | nu-weighted eq * A |
| C4 | collapse block 3 | 10 | 2 | nu-weighted eq * A |
| F1 | gu matmul | 4 | 2 | layer.rs:2107-2212 |
| F2 | d matmul | 4 | 2 | layer.rs:2107-2212 |
| F3 | zero-check F | 9 | 4 | layer.rs:2107-2212 |
| F4 | zero-check D | 9 | 4 | layer.rs:2107-2212 |

The attention list matches `public_block_wire.rs::ATTN_SC` (rounds, degree+1) exactly. Per-sumcheck error is at most (rounds x degree)/|F_{p^2}| for the round checks plus n_vars/|F_{p^2}| for the eq-weighted zero-check reduction and 1/|F_{p^2}| per mu/lambda batching. Sum over the twelve attention sumchecks: 2^-119.4; the four collapses: 2^-121.4; the four FFN sumchecks: 2^-121.2.

### 4.3 Code parameters

- **Ligero PCS (pcs.rs)**: systematic RS(n = 256, nn = 2048) per row, inverse rate 8, Q = 256 column checks, blake3 Merkle over 2048 columns (11-digest paths). With the conservative interleaved-proximity regime the module documents (pcs.rs:16-19: e < d/3), the column test misses a far matrix with probability (1 - delta/3)^Q = (17/24)^256 = 2^-127.4 per opening, plus a field term (e+1)/|F_{p^2}| ~ 2^-119 for the random row combination and 1/|F_{p^2}| per lambda. Six openings per block (attention W/A/H, FFN W/A/H) -> 2^-124.8 per block by union bound. The proximity-gap regime (e < d/2, BCIKS20) would give (9/16)^256 = 2^-212 with a larger field term; it is NOT what the code documents and is not adopted here.
- **P1 hiding form (pcs.rs:480-1024, not on the B3/B4/B5 path)**: rows become RS(n + Q = 512, 2048), rate 1/4, column term (3/4)^256 = 2^-106.2 per opening; `commit_zk_owned` asserts and `verify_zk` checks q_pad >= Q (pcs.rs:625, 947). Its privacy is FA1-FA3's subject.
- **Compact PCS (pcs_compact.rs)**: `CompactCfg::DEFAULT` = disabled, inv_rate 4, queries derived from target_bits 106 -> `queries_for(4,106)` = 157 ((5/8)^157 = 2^-106.5), log_final 7, max_pieces 3; unit tests use inv_rate 4/2 with 40/30 queries. B4 `runtime_policy` refuses it (public_block_receipt.rs:165). Not part of the fixed profile.
- **LogUp (R14)**: 4N/|F_{p^2}| with N = 26624 attention lookups (2^-111.3) and 4096 FFN lookups (2^-114.0).

### 4.4 Cumulative query counts

Per block: 6 PCS openings x 256 columns = 1,536 authenticated columns (each carrying `rows` base-field words and an 11-digest path); two-block chain: 3,072. 20 sumchecks (12 attention + 4 collapse + 4 FFN) with 86 + 48 + 26 = 160 round messages in total; 135 claimed evaluations (B4) or 133 (B3) on the attention side; FFN vectors gu_claims 2, gu_term 3, d_claims 1, d_term 2, zcf_term 10, zcd_term 4, helper_sums 4. No column is reused across openings (fresh indices per opening after its own vectors are absorbed), so union bound is the correct composition rule.

### 4.5 Whole-proof composition and Fiat-Shamir order

Verified order on the B4 receipt path (public_block_receipt.rs:177-185, attention.rs:3234-3266, layer.rs:2058-2256, then :286-347): receipt format, proof mode, adapter label, approved-contract digest, expected-request digest -> attention statement -> Wa root -> Aa root -> histograms -> beta, gamma, alpha -> Ha root -> per-relation challenges with every claimed value absorbed at `Cc::take` before the next challenge and every sumcheck round absorbed before its round challenge -> FFN statement -> W, A roots -> histograms -> beta, gamma, alpha -> H root -> FFN challenges/rounds/terminals -> helper sums -> FFN openings (lambdas -> vectors -> prox rho -> prox vector -> indices) -> seam claims at rho_d -> endpoint roles and points -> collapse (nu after values, aval absorbed) -> attention openings. Every challenge is preceded by every message it must constrain; `v3_zcd_point` replays on a cloned state and absorbs nothing. Commitment `log_cols` is not absorbed but is checked against the (digest-bound) parameters in `pcs::verify` (pcs.rs:384). Opened columns and Merkle paths are not absorbed (authenticated by the root; standard).

### 4.6 Whole-proof estimate for the fixed profile

Union bound per block: 6 x 2^-127.4 (column tests) + 2^-111.3 (attention LogUp) + 2^-114.0 (FFN LogUp) + 2^-119.4 (attention sumchecks) + 2^-121.4 (collapses) + 2^-121.2 (FFN sumchecks) + ~40 pointwise pins at <= 12/|F_{p^2}| each. Two-block receipt: **about 2^-110.1 statistical soundness**, dominated by the attention LogUp term, and in any case capped by Fiat-Shamir over blake3-256 (128-bit class, MODEL; multi-round adaptive FS loss not quantified here). This is a bound derived in this document, not an inherited number, and it presumes R09's alias exclusion and R31's weight-range assumption.

### 4.7 What carries over from SOUNDNESS_REFERENCE.md

Nothing quantitative. That document analyses the BDLOP/quinary-challenge lattice line (2^-297 per-slot point mass, MSIS/MLWE, the ct-round). The hash line has no ring, no CRT slots, no lattice assumption and different challenge sets; its numbers (2^-264, 2^-296, 2^-486) do not transfer. What does carry over is the method: the challenge-ordering principle (section 1.5 there; verified for this proof in 4.5 above), the claim-discipline note that a published bound is min(statistical term, hash/FS term, parameter term), and the adversarial-test index pattern (section 9 there).

## 5. Tiny test profiles versus a deployment profile

| Profile | code parameters | column test / opening | LogUp term | whole-proof (union) | status |
|---|---|---:|---:|---:|---|
| pcs.rs / sumcheck unit tests | log_cols 4, inv_rate 4, Q 12-20 | 2^-5.0 (Q12) | n/a | n/a | correctness fixtures, not security |
| T2/d16/f16 mask diagnostic | log_cols 5, inv_rate 4, Q 12 | 2^-5.0 | n/a | ~2^-5 (column term) | disclosure diagnostic only (FA1) |
| H1 legacy v2 T1 fixture | log_cols 8, inv_rate 2, Q 2 | 2^-0.5 | n/a | ~2^-0.5 | branch regression only |
| **A00 fixed T32/d16/f16 (this table)** | log_cols 8, inv_rate 8, Q 256 | 2^-127.4 | 2^-111.3 | **2^-110.1** (two blocks) | analysis delivered |
| A00 profile, P1 hiding form (FA3 target) | same, rows RS(512,2048) | 2^-106.2 | 2^-111.3 | <= 2^-104 (6 openings) | privacy open |
| Deployment 125M/8B (log_cols 14, inv_rate 4, Q 256) | per layer 6 openings | 2^-106.2 | 2^-99.2 per layer (8B/T512) | **2^-94.1** over 32 layers | PROJECTION only |

The deployment row is a projection of the same relation set: 32 layers x 6 openings put the PCS union term at 2^-98.7 and the LogUp term at 2^-94.2, so the whole 8B proof would sit near **2^-94, not 2^-106 and not 2^-128**, before any FS/hash cap. Raising Q, lowering the rate, or batching openings across layers changes this; the tiny profile's 2^-110 does not scale up. Integer bounds at deployment also change class: the Int24 residual class exists in the code (attention.rs:198,206) and drives `n_limbs` to 3 at d = 4096, which is exactly the regime where R09's alias is not excluded.

## 6. Prioritised gap list (for Codex / FA3 / FA4)

1. **R09 (HIGH for deployment, documentation debt for the fixed profile)** — the norm's D has no direct range fact; the half-p alias D = k + (p-1)/2 passes every isqrt/SS/Square relation and the a1/a2 limb ranges for every row, and passes NormDiv with an all-zero output whenever the remainder limbs allow 2^(31+tn). Fixed profile: excluded by n_limbs = 2 and tn = 11 (margin 2^10). Any profile with n_limbs >= 3 and tn >= 1 accepts wrong norm outputs. Fix: a direct range fact on D (U16 lookup here; U16+U8 limbs at 8B) or an explicit parity/small-range fact on a1 + a2; add the alias as a tamper leg.
2. **R31 (registrar boundary)** — weight/gamma word ranges are unproven; every no-wrap bound assumes int8. Either range-look-up W (cheap at this profile: 1,024 + 768 words) or make the registrar's authenticated manifest carry the range obligation explicitly.
3. **R35 (P1 target)** — the profile proves nothing private; FA1 reproduced the FFN singleton-group disclosure. Closure of any privacy claim waits on FA2/FA3. The hiding code's column term is 2^-106, not the P0 profile's 2^-127.
4. **R10 documentation** — the proven remainder width is 2^(16 n_limbs), not `wrho`; record it in the statement or narrow the limbs.
5. **R29** — exponents and `norm_round` are not absorbed by the attention statement; only the A00 digest binds them. Acceptable inside B3/B4/B5, unbound for any standalone use of `verify_attn`.
6. **R32** — the typed B3 API ignores extra `proof.sc` entries and non-empty `helper_sums`; B4/B5 reject them. Align the typed API or retire it.
7. **R02/R20** — the proof's classes are wider than the oracle's (-128, -32768 admitted); pin the intended class in the contract digest or accept and document the corner semantics.
8. **R14** — no LogUp error term is stated anywhere in the code; adopt the 4N/|F_{p^2}| accounting (and the union bound of 4.6) in the ledger.
9. **R36** — P3 approved-model consistency is a missing constraint (FA4).

## 7. Status

**Analysis delivered.** Every row has a source location, an exact parameter assumption and a remaining gap; every estimate states its derivation and dependencies. **Closure is open**: final security acceptance incorporates (a) the implemented FA3 repair and its independent verification, (b) FA4's approved-model consistency for P3, and (c) independent verification of the rows above, in particular a test that reproduces and then refuses the R09 alias. No target-throughput eligibility follows from this document.

## 8. Limits

- Read-only source review at the pinned baseline plus python arithmetic (results/zk60_fable_fa5_*.txt); no Rust build or test was run by this review (two other reviewers were building on the shared box).
- Bounds use the conservative regimes the code documents; tighter external theorems are named but not adopted.
- The deployment row is a projection of the current relation set, not an implemented profile.
- Privacy (R35) and P3 identity (R36) are referenced, not re-derived.
- The R09 counterexample is verified as satisfying every field relation the verifier checks for one norm row; it has not been packaged as a Rust tamper leg (recommended in section 6).
- Fiat-Shamir is treated in the random-oracle model; grinding and multi-theorem use are not quantified.
