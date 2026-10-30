# Token I/O, classifier variant: a public verdict over hidden content (design v2)

Token-I/O lane, round 12 (2026-10-21). Status: **design; v2 answers the adversarial check
`check/CHECK.md`; nothing built.** Not a privacy acceptance.
- v2.1 (§12) reads the product as content labels (D37 revised); v2.2 (§13) splits long content
  into chunks (D41). R-C1 is being built on frozen-r11 (`token_io/classify*.rs`).
- v2.3 (§14) ties the tables to the pinned tensor (R-C2); v2.4 (§15) adds short items and the
  library binding (R-C3); v2.5 (§16, token round 15) adds the label's whole-post check
  (`--expect-total`), the capture writers' slot list (F18-1) and the corrected causality
  argument (§15.2). Victor ruled all four pending items on 2026-10-29 (D45); the table below and
  §5 / §6 now say so.
- v1 is kept beside this file as `DESIGN_CLASSIFIER.v1.md` (sha256 `f9fe043f…`).
- It follows DESIGN v3 (`results/zk60_token_io_design_20261017/DESIGN.md`, cited "v3 §n") and the
  built token run on frozen-r11 / binary `0c9f247c…`.
- It rests on these rulings:
  - D38 (a)–(c): Shieldstral-1.0-3B, text only; the proof states z_yes − z_no > c; disclosed are
    the verdict, the model identity and the policy text;
  - D36, which is extended to frozen-r11;
  - D26 (the token endpoints);
  - D23 (endpoint roots are never registered or referred to later);
  - D34 (the stage-IN refusal is priced as a distance term).

Labels:
- [COUNTED]: from the layout replica or the code.
- [RAN]: a small script; mine in `rc0/`, the checker's in `check/`.
- [MODEL]: an estimate.
- [OPEN]: a fact to be fixed during implementation.
- **[RULING PENDING]**: a section that stays a set of marked options until the coordinator relays
  Victor's answer. (None is left: B-4, B-5, B-6 and B-8 were ruled on 2026-10-29 01:04 UTC as
  D45; each place is now marked **[RULED … D45(n)]**.)

## 0. Changes in version 2 (answers to `check/CHECK.md`)

| check | v2 |
|---|---|
| C-1 (high) template boundary | **B-1 adopted:** the prefix ends at `:` (84 ids for the card template); the content segment is tekken's plain-text encoding of `' ' + content`; the suffix is `[/INST]`. Reproduced 24/24 against Mistral's reference encoder (`check/tok_probe.json`, [RAN]); R-C0 re-runs it (§3.5) |
| C-2 (high) control-token injection | **B-2 adopted:** the canonical tokenizer is tekken's plain-text encoder (no special-token parsing), named in the statement by digest; content positions are proved free of control ids by one public column `ctl` in the stage-IN lookup tuple (§3.6) |
| C-3 margin vector | **B-3 adopted:** the verifier re-derives the margin vector, the yes / no ids and c from the export at the door and compares digests; it never takes them from the statement. **The difference row is quantised directly** (int16, one scale): no multipliers, |w_Δ| ≤ 32,767, B_Δ = 2^33.57 (§4.1) |
| C-4 refusals in the app | **B-4:** app rule "no accepted proof ⇒ handled exactly as flagged / not published" written as the app's obligation (§5); refusal-free final-norm constants preferred. **[RULED 2026-10-29: D45(4), fail closed]** (was RULING PENDING) |
| C-5 n public | **B-5: [RULED 2026-10-29: D45(1), n public]** (was RULING PENDING: n public for the MVP, or the hidden-length variant) |
| C-6 policies | **B-6: [RULED 2026-10-29: D45(2)]**, a fixed policy list with one threshold each, never re-proved under another (was RULING PENDING) |
| C-7 one endpoint; D34 recount | **B-7:** the coordinator records the one-external-endpoint classifier profile and the D34 recount (≈ 2^-112.7 at L = 26, T ≤ 512) as security owner; cited in §5 |
| C-8 D23 amendment | **B-8: [RULED 2026-10-29: D45(3)]**, the proof linked to the post (sealed input fingerprint stored and anchored, D39; the app keeps the opening; its transferability accepted) (§6) (was RULING PENDING) |
| §3.4 option (check) | **Seeded endpoint randomness** written up as option S for the security owner's reading, **not adopted** (§6.3) |
| C-11 / C-14 / C-15 | |w_Δ| typo fixed (two-row bound 2^19.99); "Ceps < 2^40" stated beside the tn = 10 window; c = ⌊θ/κ⌋ is **exact** for integer Δ (no rounding direction) |
| C-12 hidden length | the sketch now requires in-circuit length binding (§3.4) |
| C-13 T < T_pad | listed as a gate item (§5, §11) |
| C-16 variant tokens | F11 note: compare the single-id margin's verdict with the variant-aggregated reference scorer (§11) |
| C-17 F6 | gains corrected to 2.00 / 4.13 / 2.06 / ~1.93–2.00× (score domain `(n+1)_pad × T_pad`); the counter's width formula noted; the prefix guarantee moves into the public cache; the RoPE offset P0 is a bound constant (§8); F6 stays a sketch |
| C-18 count nit | stage OUT-C: λ in its own small lifted domain with one helper, or 13 lookups / 7 helpers on Do; counted exactly at R-C1 |

## 1. Plain-words summary

The run is the next-token run with two changes, plus the app rules the check asked for.
- **The input side.** A public template surrounds the hidden content. Stage IN gains a clause
  pinning every template position to its public id. A second, public lookup column proves that
  no content position carries a control token, so posted text cannot close the instruction early
  or supply its own answer. The content is encoded with Mistral's own plain-text encoder, pinned
  by digest.
- **The output side.** The 131k-row head and the argmax become one dot product: the normalised
  last row times a public int16 vector, the quantised difference of the "yes" and "no" head rows,
  re-derived from the export by every verifier. That gives the integer margin Δ. A five-byte
  range proof shows Δ > c when the public verdict bit b is 1, and Δ ≤ c when b is 0. b is in the
  statement and in the transcript.

There is no output endpoint and no owner opening. Hidden from the verifier: the content ids, any
activation, the logits, Δ and its size.

## 2. Exactly what becomes public, and what stays hidden

**Public (in the statement, or derived by the verifier from the export at the door):**
* the model: the trained-statement identity (26 blocks' digests and calibration; the YaRN RoPE
  table, F1; the tied-embedding derivation, F3) and the export variant;
* the tables: the int16 embedding (stage IN), the int16 margin vector w_Δ and its scale (§4.1),
  V = 131,072, d = 3072, BOS, and the final-norm constants;
* the yes and no ids as **profile constants**: the HF tokenizer gives yes = 13059 and no = 2649
  as single tokens ([RAN], check), [OPEN] to pin against Mistral's reference scorer;
* the threshold c (a profile constant) and its display form τ;
* **the canonical tokenizer**, by digest: tekken's `tekken.json`, used through its plain-text
  encoder, and the **control-id set** `ctl` (tekken's special ids, ids < `num_special_tokens`;
  §3.6);
* **the template**:
  - the prefix ids (positions 0 … P0−1; P0 = 84 for the card template);
  - the suffix ids (`[/INST]`, S = 1);
  - the policy text inside the prefix;
  - P0, S, and, if B-5 is ruled so, the content length n and T = P0 + n + S;
* **the verdict b** (b = 1: "flagged", the model answered "yes" with margin above c; the public
  Query text fixes what "yes" means);
* as in every run: the context label and context, the input endpoint root, the whole-run floor,
  the run and block profiles, and L = 26.

**Hidden:**
- the content ids and their embedding rows;
- every activation and inter-block plane;
- the final-norm values;
- both logits, which are never formed;
- Δ and the range limbs;
- everything the next-token run hides.

**Removed compared with the next-token run:** the output endpoint, its root, the owner
decommitment of an answer, and the head's vocabulary domain.

## 3. Input side: public template plus hidden content (stage IN-C)

**3.1 The template clause.** v3 §2.3, plus one batched clause in the query zero-check, with its
**own fresh coefficient** μ_tmpl drawn after A_in, M_in and H_in (v3 N-3):

  `eq(τ, t) · μ_tmpl · π(t) · (tok(t) − κ(t))`

- π is the public template indicator (prefix ∪ suffix).
- κ holds the public template ids, zero at content and pad positions.
- The door checks κ(0) = BOS. The BOS clause stays as built.
- The LogUp then gives `x[t, ·] = E[κ(t), ·]` at every template row. The check confirmed this
  holds (C-10).

**3.2 Soundness of 3.1.** With μ_tmpl fresh, the clause holds separately except with probability
deg / |F_p²|. A shared coefficient would let it cancel against the LogUp clause (CHECK2 N-1).
R-C0 shows both: the cancelling forgery is accepted under a shared coefficient and refused under
a fresh one (§10).

**3.3 Endpoint.** The input endpoint holds the whole token plane, as built: one site in the
public-row variant, IO-in unchanged.
- The template words are public values at known positions. Hiding never depended on a word being
  unknown (BOS and the zero pads are public today).
- The input owner's check gains the template and control-id comparisons (§6).

**3.4 Length.** [RULED 2026-10-29: D45(1), option N; was RULING PENDING, B-5]
- **Option N (public n, the built public-row variant).** T = P0 + n + S is in the statement.
  Blocks already run with tokens < t_pad (rung_g / rung_k4), but **at trained shapes T < T_pad is
  a new configuration**: the gate's pad controls must cover it before any figure is quoted
  (C-13). The run profile states the class of T, not one T per profile (a W-2 census item).
- **Option H (hidden length).** D26's two-site endpoint (the selector s sealed in half 1).
  - In the classifier the input owner **is** the prover (the app), so the owner's check of s
    gives the public nothing (C-12).
  - In-circuit length binding is therefore required:
    - the suffix id is checked through the selector (`Σ_t s(t)·tok(t) = id([/INST])`, its own
      coefficient);
    - every position after the selected row is pinned to a public pad id
      (`(1 − Σ_{u≤t} s(u)) · (tok(t) − pad)`, its own coefficient, cumulative selector public
      in shape, committed in value);
    - stage OUT-C reads row P−1 through SEL.
  - Not built; costed when ruled.

**3.5 The tokenisation boundary (B-1 adopted).** The token sequence of an item is:

  `prefix_ids ‖ tekken.encode(' ' + content, bos = False, eos = False) ‖ suffix_ids`

- `prefix_ids` is Mistral's reference chat encoding (`mistral_common`
  `ChatCompletionRequest`, system message plus user message) cut before the separating space:
  84 ids for the card template, ending at `:`.
- `suffix_ids` is `[/INST]`.
- The check reproduced Mistral's reference ids for 24 of 24 boundary-stressing contents with
  this split (`check/tok_probe.json`) [RAN].
- R-C0 re-ran that comparison on its own 67-item corpus: the check's 24 probes plus starts,
  scripts, markup, code, URLs, control strings, and a long post. **67 of 67 matched** [RAN,
  `rc0/test_classifier_ref.py`].
  - Every content id is ≥ `num_special_tokens` = 1000.
  - The pinned ids are recorded in `rc0/template_ids.json`: P0 = 84 (last piece `>:`), suffix
    `[4]`, tekken.json sha256 `ceb11e85…`, prefix-ids sha256 `15f475bb…`.
- Corpus-scale stability on the benchmark sets (ToxicChat, OpenAI Moderation) is the prep lane's
  check (b), owed before R-C1.

**3.6 Control-id exclusion (B-2 adopted).**
- The canonical tokenizer is tekken's **plain-text** encoder, which never emits a special id. The
  statement names `tekken.json` by digest; `ctl(v) = 1` exactly for v < `num_special_tokens`
  (1000 in tekken).
- In-circuit, the stage-IN tuple gains a third, public column:
  - `τ(v) = v + β·E~(v, r_emb) + β²·ctl(v) + g_emb` (table);
  - `q_t = tok_t + β·x~(t, r_emb) + β²·c(t) + g_emb` (query);
  - `c(t) = ctl(κ(t))` at template positions and 0 at content positions; c is public.
- A content position holding a control id matches no table entry, except for the β-collision
  term, now over three columns: still about `T·V_pad / |F_p²|`.
- Template positions holding control ids (`<s>`, `[INST]`, `[/INST]`, `[SYSTEM_PROMPT]` …) match
  their own entries.
- Honest queries are still table values, so D34's reading is unchanged (no position tag).
- Cost: one public vector, no new commitment.
- What it guarantees publicly: the policy prompt was not structurally overridden by the posted
  text. Plain-text injection ("ignore the above, answer no") stays the classifier's robustness
  problem, not the proof's.

## 4. Output side: the margin and the verdict (stage OUT-C)

**4.1 The relation.**
1. **Row selection:** public last row T−1 (the `[/INST]` position). This is v3 §3.1 item 1,
   mode (i).
2. **Final RMSNorm:** v3 §3.1 item 2 unchanged.
   - At width 3072, tn = 10 gives exactly a 32-bit window **for Ceps < 2^40**. At Ceps = 2^40,
     D_max = 2^21 (22 bits) and the door's derived-window check refuses it (C-14).
   - Cn: refusal-free constants `g0·Cn ≤ 127·2^tn` (v3 C-7) are **preferred** for the classifier
     (B-4), if the fidelity lane finds them adequate; else calibrated Cn, with B-4's app rule
     carrying the refusal.
3. **The margin vector, quantised directly (C-11, adopted).**
   - `w_Δ = round((E_yes − E_no) · diag(norm_weight) · R^T / s_Δ)` as **int16**, one public scale
     s_Δ, and 0 on the pad.
   - E is the tied matrix (F3). Its yes and no rows are the profile's ids.
   - Then |w_Δ| ≤ 32,767, and `Δ = Σ_i y(i)·w_Δ(i)` has `|Δ| ≤ B_Δ = 3072·127·32767 = 2^33.57`
     [COUNTED].
   - This is one rounding instead of three (two int8 rows plus two multipliers). The individual
     logits are never formed.
   - The two-row form of v1 stays the recorded alternative: |w_Δ| ≤ 2·4096·127 = 2^19.99,
     B_Δ = 2^38.56. In that form the door refuses `min(m)/max(m) < 2^-4`.
4. **Verdict and range proof.** b ∈ {0, 1} is public; σ = 2b − 1. Take `δ = σ(Δ − c) − b`, so
   b = 1 ⇔ δ = Δ − c − 1 ≥ 0, and b = 0 ⇔ δ = c − Δ ≥ 0. Commit L byte limbs `λ_0 … λ_{L−1}` of δ.
   - **L is derived (TF-1):** `window = bits(B_Δ + c_max + 1)` over the declared classes. With
     the int16 row and the class |c| ≤ 2^33, the window is 35 bits, so **L = 5**.
   - The door checks `2^(8L) + 2^window < p`. No top-limb pin.
5. **The margin identity, slot MRG:** `Σ_{i∈Do} [ y(i)·w_Δ(i) − σ·λ(i)·g(i) ] = σ·b + c`, with
   `g(i) = 256^i` for i < L and 0 elsewhere (public).
   - λ lives in its **own small lifted domain** (L live entries) with one byte lookup and one
     helper (C-18). The identity reads it through a public selector, or, if placed on Do, there
     are 13 lookups and 7 helpers per Do entry; R-C1 picks the cheaper one by count.
   - A pad-zero clause on λ beyond L, with its own coefficient.
   - Every monomial carries a public factor; the right side is public (v3 B-3).
   - MRG replaces HEAD, VZC, RSEL and IO-out.

**4.2 Why the verdict is right.** The check confirmed this (C-9).
- MRG at a random point, drawn after A_out, gives `Δ − σδ = σb + c` in the field.
- All terms are integers whose total is far below p/2: |Δ| ≤ B_Δ, δ < 2^(8L) = 2^40 (whatever a
  forger puts in five bytes) and |σb + c| ≤ c_max + 1. That is about 2^40.1 with the int16 row and
  2^40.7 with the two-row form [COUNTED; the check's figure for the two-row form].
- So the identity holds over the integers, and `Δ − c = σ(δ + b)`.
  - b = 1: Δ ≥ c + 1.
  - b = 0: Δ ≤ c.
- Flipping b needs δ' = −δ − 1 < 0, which is not five bytes.
- The tie Δ = c gives b = 0 and δ = 0, matching Mistral's "flagged above τ".

Completeness: the honest δ lies in [0, B_Δ + c_max] ⊂ [0, 2^40), so no honest verdict is refused.

Load-bearing relations, each shown in R-C0 (§10):
- the byte lookups on λ;
- λ's pad-zero clause (P-1);
- b in the transcript;
- the verifier's own derivation of w_Δ (B-3), because a swapped `−w_Δ` with a self-made digest
  would invert the meaning while every relation holds.

**4.3 Planes and slots of stage OUT-C** (U8, public row, T_out = 1)

| domain | A planes | lookups / entry | H helpers (Fp2) |
|---|---|---:|---:|
| To (1) | `D`, `Dsq` | — | — |
| Lo (16, lifted) | isqrt limbs | 1 | 1 |
| Do (d_pad = 4096) | `x`, `xl0`, `xl1`, `y`, `rho ×4`, `sigma ×4` | 12 | 6 |
| Mc (L = 5, lifted) | `λ` | 1 | 1 |
| Tab | U8 multiplicities | — | table helper + `u` |

Slots:
- unchanged: IO-in (`x` row = B_out row T−1), SS, TZC, LZC, DZC (with λ pad-zero), TAB, ZS;
- new: **MRG**.

There is no Vo domain and no IO-out.

**4.4 Statement and transcript.** The statement gains:
- `classifier`: yes / no ids, w_Δ digest and scale, c, τ, the rule text;
- `tokenizer`: the tekken digest, the plain-text mode and the ctl-set digest;
- `template`: the prefix / suffix ids, P0, S, n if ruled, and a policy-text digest;
- `verdict`.

**The verifier derives** the yes / no ids (profile), w_Δ and s_Δ (from the export's tied-matrix
artifact and the derivation rule), c (profile) and the ctl set (from tekken), and **compares**
them with the statement. A mismatch is refused at the door, before any segment is read (B-3).
`TokenRunStatement::transcript()` absorbs all of these before any segment. The classifier
variant gets its own schema and run-profile family; the next-token runs stay `/2`.

**4.5 The threshold.**
- For integer Δ, **c = ⌊θ/κ⌋ is exact**, where θ = ln(τ/(1−τ)) and κ = s_y·s_Δ is the margin's
  public scale: Δ > ⌊x⌋ ⇔ Δ > x. The approximation lives in κ and in the integer model (F11),
  not in c (C-15).
- At τ = 0.5, c = 0.
- c is a profile constant.

## 5. Leakage, refusals and the app's operating rules

* **One bit per proof** (check §3.3, "holds"). The limbs and multiplicities are committed, MRG is
  CFS-masked, the window and L are fixed by the class, and the proof's length depends only on T.
  [gate] The rank / CFS gate re-reads MRG (terminals on y and λ). The privacy statement's
  simulator is given b, the policy, c and (B-5) n.
* **B-4, refusals in the app** **[RULED 2026-10-29: D45(4), fail closed]** (was RULING PENDING on
  the rule's wording). The rule as ruled: a post without an accepted proof is not published and is
  shown as "could not be verified", never as safe. The proposal it answered: an
  item without an accepted proof is handled exactly as b = 1 (flagged / not published). It is
  never published unverified, and a refusal is never shown as a separate outcome.
  - This removes the third outcome and the bypass: content crafted to overflow the final norm or
    a block (CS-3 refusals stay possible for adversarial inputs, even under D32's zero refusals
    on evaluation sets).
  - Refusal-free final-norm constants are preferred (§4.1).
  - At the receipt level D20 / D29 / D21 hold as built.
* **B-6, policies** **[RULED 2026-10-29: D45(2), option P]** (was RULING PENDING).
  - Option P: one fixed, short, pre-registered policy list per profile family, one c per policy
    globally. The number of bits disclosed per item equals the number of listed policies, and the
    privacy statement says so.
  - Without it, each extra free-text policy is an arbitrary yes / no question about the hidden
    content (C-6).
  - Multiple thresholds under one policy are excluded by c being a profile constant.
  - Edits of an item leak which edit flipped its verdict. That is inherent, and goes in one
    sentence of the app's privacy note.
* **B-7** (recorded by the coordinator as security owner):
  - the classifier profile has one external endpoint plus a public verdict (a D12 / D12a
    deviation);
  - D34 recounted: `2·(768·26 + T + 256)/p²` ≈ **2^-112.7** at T = 512 [COUNTED, check]. The
    public template rows only lower it.

## 6. Binding the proof to the posted item [RULED 2026-10-29: D45(3), option R with the D23 amendment; was RULING PENDING, B-8]

From the receipt alone, a third party learns the template, that the content ids are below V and
free of control ids, the sealed root R, and the verdict. **Without a decommitment nobody can tell
that this content is the posted item.** That is inherent to hiding the content (check §3.4).

**6.1 Option R (recommended): the input endpoint root plus the input owner's check.**
- The statement carries R, and IO-in binds the proved plane to it.
- The app keeps the decommitment.
- Anyone given the item's bytes and the decommitment:
  1. re-encodes with §3.5's split (tekken plain text, B-1 / B-2);
  2. checks the template, the content ids and the absence of control ids;
  3. rebuilds R (the built `input-owner` check, extended).
- Tokenisation is checked by anyone with the bytes, not proved.
- **This needs the D23 amendment; D45(3) (2026-10-29) made it, and the register's wording
  governs. The text proposed then:** "An accepted classifier receipt's
  input root may be recorded beside its item by the app, and anchored on-chain with its statement
  (D39), provided no later proof ever claims or opens that root. The decommitment goes only to
  parties entitled to the content; it is a transferable proof that a given content is the one
  behind the root, which removes deniability for private items, and its recipients are outside
  the privacy statement's adversary."
- Recording R adds no information (R is already in the receipt; D19b rests on fresh per-column
  salts). What D23 guards against is a later opening or claim, and the amendment forbids exactly
  that (check §3.4).

**6.2 Rejected** (unchanged from v1):
- a plain or salted hash in the statement, because the proof does not compute it;
- D18 option B (an in-circuit hash of a third-party-sealed handle) is the end state, not built.

**6.3 Option S, seeded endpoint randomness (for the security owner's reading; not adopted).**
- Today the decommitment carries every row, the 256 pads per row and 2,048 leaf salts (about
  90 KB).
- Option S derives the endpoint's pads, mask rows and leaf salts from a fresh 32-byte per-item
  seed by keyed BLAKE3 under a domain separated from the proof's generator. The decommitment
  becomes `(content, seed)`, the D7 zkVM-line shape, with no change to the proof.
- What the reading must cover:
  - E-1 / X-1 gain a PRF step (the endpoint's randomness is pseudorandom in the seed instead of
    from the OS stream);
  - the seed must be fresh per item and never reused (reuse links two receipts and, with two
    openings, is D11);
  - the seed is as sensitive as the content;
  - the domain separation from the run's generator (D19 tag family) is new;
  - the owner check re-derives the randomness, so a wrong seed fails the root rebuild.
- Benefit: a 32-byte opening an app can store, publish or put on-chain beside a public item.

## 7. What the token stages need from the native lane (through the coordinator)

* **F3, tied embeddings.** The importer emits:
  - (i) stage IN's int16 table, with rotation and s_in;
  - (ii) the **int16 difference row** w_Δ with its scale s_Δ, from the same float matrix with
    norm_weight and R^T folded in.

  Both have digests in the trained statement. The export carries the row, so verifiers re-derive
  and compare without float weights (B-3).
* **F1 (YaRN) and F2 (head_dim 128, q width 4096 ≠ d = 3072):** block side.
* **Stage IN at V = 131,072, d = 3072:** the 8B class (V_pad = 2^17, one O(V·d) verifier fold of
  E, 403 M words).

## 8. F6, public-prefix reuse (sketch only; corrected per C-17)

**Idea** (unchanged). Prefix K and V are public tables per layer. Only rows P0 … T−1 are proved.
The score slot splits into a public-key part and a private part, the softmax statistics (the A_MX
row maximum, FN / DD dictionary, exp multiplicities) span both, and PV takes V_pub as a public
factor.

**What moves (C-17 c).** The prefix rows are no longer proved, so stage IN's template clause and
the BOS clause cover only the n + 1 proved rows. "The policy is X" now rests on **the cache**:
K_pub / V_pub must be exactly the integer model's prefix K / V.
- The statement binds the cache digest.
- Each verifier recomputes the cache once per (model, template), about 30 s [MODEL], or names
  whom it trusts.
- The RoPE offset of the proved rows is P0, a bound profile constant, and the YaRN table is
  evaluated there.
- F6 hides less work, not more data; P1 is unaffected.

**Counted gain, corrected** [COUNTED, `check/check_f6.py`]. The score domain is sized
`(n+1)_pad × T_pad × 32`, and Kv stays n + 1 because the prefix K / V are public:

| content n | T (pad) | F6 proved rows (pad) | gain (elements) |
|---:|---:|---:|---:|
| 32 | 123 (128) | 33 (64) | 2.00× |
| 48 | 139 (256) | 49 (64) | 4.13× |
| 64 | 155 (256) | 65 (128) | 2.06× |
| 128 | 219 (256) | 129 (256) | 1.00× |
| 200 | 291 (512) | 201 (256) | ~1.93× (2.00× on the speed-plan width ladder) |
| 256 | 347 (512) | 257 (512) | 1.00× |

- The gain appears exactly where npow2(n + 1) < npow2(n + 91).
- v1's `f6_count.py` width formula gives 2^13 at T_pad 32 (its comment said 2^12). On the
  speed-plan ladder the full counts are about 5% lower and the ratios are unchanged.
- Gate questions G1–G5 (v1) stand, plus: the cache's trust rule and the RoPE offset belong to G3.

## 9. Costs [MODEL unless marked]

- **Stage OUT-C:** about 110–120 A and 40–50 H rows at 2^12, so about 0.6 M elements and about
  37 k byte lookups, against 2.77 M / 0.97 M for the built 8B stage OUT. Its verifier folds w_Δ
  (4096 words). Counted exactly at R-C1.
- **Stage IN:** the 8B class.
- **The run:** dominated by 26 blocks; a 64-token post takes about 310 s on the laptop, or about
  200 s with F6 [EST, survey §5 fit].

## 10. Test-first plan

* **R-C0, reference (`rc0/`, started in v2).** These parts do not depend on rulings:
  - the margin slot (honest b = 0 / 1, the tie, Δ = c ± 1 at both b, |Δ| = B_Δ, c ≠ 0, the
    int16 difference row and the two-row alternative);
  - its forgeries, each accepted when its one relation is removed:
    - flipped b, where δ' = −δ − 1 mod p is not bytes;
    - non-byte limbs;
    - non-zero λ pad;
    - b not absorbed;
    - a swapped w_Δ with a self-made digest, refused by the door's re-derivation;
    - c ≠ the profile constant;
  - template pinning with B-1 (the reference encoder versus the split on a corpus; the lone-space
    boundary token refused; one template id changed and refused; the shared-coefficient
    cancellation accepted, the fresh coefficient refusing it);
  - control-id exclusion (a content control id accepted without the `ctl` column, refused with
    it; template control ids accepted).
  - Owed: T < T_pad pad rows (with R-C1), and the ruling-dependent parts (n, the policy list,
    binding).
* **R-C1, rung (synthetic generic witness; built prover and verifier).** Stage OUT-C plus the
  template clause plus the `ctl` column. Honest runs at b = 0, b = 1 and a tie. Every control is
  refused at its predicted site. The H-1 sealing pass covers stage OUT-C (δ's limbs as bytes,
  content ids free of control ids, before any header). The counted layout replaces §9's estimate.
* **R-C2, Shieldstral shapes** (after the native F1–F3): a generic dense witness, n ∈ {32, 64};
  count, time, gate captures.
* **CLI:** `classify-prove` / `classify-verify` / `classify-input-owner`. The frozen next-token
  commands stay byte-identical.

## 11. Rulings, readings and open facts

**Victor** (the coordinator is relaying; all four RULED 2026-10-29 01:04 UTC as D45, §15.1):
- B-5, n public;
- B-6, the policy list;
- B-8, the D23 amendment text in §6.1;
- B-4, the app's refusal rule.

**Security owner:**
- B-7 (being recorded);
- option S (§6.3);
- T < T_pad at trained shapes through the gate (C-13);
- the classifier run-profile family with T in a class;
- F6's cache trust rule, before F6.

**Gate, then review, then Victor:** the classifier privacy statement. It is a new argument,
because the verdict is a public output and D36's output-side parts are replaced.

**Open facts:**
- the yes / no ids against the reference scorer;
- refusal-free versus calibrated Cn;
- corpus-scale B-1 stability (prep lane check (b));
- **F11 (fidelity lane):** Shieldstral's int8 verdict agreement on ToxicChat and OpenAI
  Moderation, **comparing the single-id two-row margin with the variant-aggregated reference
  scorer** (which sums `yes` / `"yes"` / … variants, C-16).

## 12. Addendum v2.1 (2026-10-21): the product as content labels (D37 revised by Victor)

**What changed.**
- The proofs are content labels used for distribution. At creation, each item is proved once
  per category of a fixed, pre-registered list. The placeholder list is sexual / explicit,
  graphic violence and hate / harassment; Victor confirms it.
- **Both outcomes are published:** b = 1 and b = 0 are normal labels, not rejections.
- B-6 therefore becomes **a fixed list of N policy templates, one c each, with N proofs per
  item over the same content.**
- The per-item disclosure is exactly N bits (§5 B-6, option P, with N listed policies). If F6
  is built, its public cache is per policy template (§8).

**Linking the N proofs to one item.** Each proof has its own input endpoint, because the token
planes differ: same content, different template.
- **The N proofs must not share one endpoint commitment.** One commitment opened in N proofs
  is D11's two-openings recovery of the row. So each proof seals its own endpoint and opens it
  once.
- **Under option R as built (fresh OS randomness per proof),** the N roots R_1 … R_N are
  unrelated. A third party links them with **N decommitments over the same content**. For each
  category i, it re-encodes (policy i's template ‖ the same content ids, §3.5) and rebuilds R_i
  from decommitment i. The content ids are identical across the N by construction, so it
  compares them once. Cost: N decommitments of about 90 KB each.
- **Under option S (§6.3; recommended for this product, security owner's reading still
  owed),** the item gets one fresh 32-byte seed.
  - Each proof's endpoint randomness (pads, mask rows, leaf salts) is a PRF of
    (seed, policy id, run context), domain-separated per policy, so the N commitments are
    distinct, each opened once.
  - **One decommitment (content, seed) opens all N roots.** Anyone holding it re-derives each
    endpoint and checks R_1 … R_N. That is a 32-byte linking secret per item, which the app can
    keep, hand over, or publish with a public item.
  - Reading items S-1 to S-5 of §6.3 apply. In addition, the seed is reused across exactly the
    N proofs of one item, never across items, and the per-policy domain separation is what
    keeps the N commitments independent.
- **D23 / B-8 wording.** The amendment covers recording the N roots of an item (and anchoring
  them, D39) under the same condition: no later proof claims or opens any of them.
- **Fail-closed (B-4) is unchanged.** A category whose proof is missing or refused is handled
  as flagged for that category, never published as an unproved label.

**Code (R-C1).** The policy list is a registry (`token_io/classify.rs`). Each category becomes
one entry with its own template ids and c, and an item is proved once per entry. The
three-category Shieldstral templates are added once Victor confirms the list; their ids come
from the B-1 split, and each gets R-C0 corpus checks.

## 13. Addendum v2.2 (2026-10-21): long content in chunks (D41)

Victor's direction D41: content longer than one proof allows is split into chunks. Each chunk is
proved separately for each category, and the chunk size is tunable so the demo runs on different
hardware. The chunk layer sits **above** a single classifier proof: every chunk proof is an
ordinary classifier proof (§3–§6) whose content positions hold that chunk's ids.

**13.1 The split rule (public, fixed per deployment profile).**
- **Encode once.** `c = tekken.encode(' ' + content, bos = False, eos = False)`, with N = |c|.
  B-1 and B-2 apply once, to the whole content.
- **Chunk size per category:** `n_i = T − P0_i − S_i`. Every chunk proof is then at exactly the
  profile's T, so chunks need no T < T_pad shape. With the card template (P0 = 84, S = 1) this
  gives 43 / 171 / 427 at T128 / T256 / T512 [COUNTED]. D41's "about 40 / 168 / 424"
  corresponds to an 88-id template overhead; each of the three category templates fixes its own
  P0 when its ids are pinned.
- **Overlap** o, with 0 ≤ o < n_i: one value per deployment profile. The stride is
  `s_i = n_i − o`.
- **Ranges.** For j < K − 1, chunk j is `[j·s_i, j·s_i + n_i)`. The last chunk is
  **end-aligned**: `[N − n_i, N)`. Its overlap with the previous chunk is therefore at least o,
  and it is public. So every chunk has exactly n_i ids, and
  `K = 1 + ⌈(N − n_i) / s_i⌉` for N ≥ n_i.
- **Short content** (N < n_i) gets one chunk of N ids. That needs either T < T_pad (C-13), or
  trailing public pad positions pinned by the template clause with stage OUT-C reading the public
  row `P0 + N + S − 1`. The second route is preferred. Neither is built in R-C1: short content is
  refused by name. **Built in round 14 (R-C3) by the second route: §15.**
- **The prover never chooses n_i or o per item** (the spirit of O-1). Both sit in the classifier
  profile, so in its digest, and in the statement. The verifier re-derives the ranges from
  (N, n_i, o), as B-3 does for the margin vector, and refuses any other range.

**13.2 B-1 at a cut: what the model reads.**
- The model input of chunk j is defined **on ids**: `prefix_i ‖ c[a_j : b_j] ‖ suffix_i`. A
  chunk's text is never re-encoded, so the input is well defined and deterministic from the
  content.
- Chunk 0 begins with B-1's leading-space piece. A later chunk begins with whatever piece the
  whole-content encoding has at a_j: usually a word with its space marker, sometimes a piece from
  inside a word.
  - Those chunks have **no leading-space convention**, and no reference chat encoding of any text
    produces them.
  - Decoding the slice and re-encoding `' ' + text` is rejected. The round trip is not stable, and
    linking by slice (13.3) would break.
- **What still holds:**
  - **Template pinning:** the template clause pins positions 0 … P0−1 and the suffix positions,
    and T is fixed.
  - **The control-id column:** a slice of a plain-text encoding contains no control id, and a
    content control id is still refused.
- Soundness is unchanged. What changes is classifier quality on chunks that start mid-word.
  - The overlap is the mitigation.
  - The fidelity lane's agreement measurement at each chunk size is a new F11 item.
- **Later, if that measurement justifies it:** cut only before an id that begins with a space.
  Chunk lengths then vary, so this needs the short-content route above.

**13.3 Linking the chunks of one item.**
- Each proof (category i, chunk j) has its own input endpoint. The planes differ, and one
  commitment is never opened in two proofs (D11). So an item has N_cat × K roots.
- **Public in every chunk proof:** j, K, `[a_j, b_j)`, N, n_i and o. They are absorbed into the
  transcript (`classify-chunk`) and rendered in the statement.
- **Recommended now, L-R (as built; no new assumption).** The item's decommitment is **one
  bundle**: the content plus one endpoint decommitment per (i, j). A third party:
  1. re-encodes the content once (B-1 / B-2) and checks N;
  2. re-derives every range from (N, n_i, o);
  3. builds each plane `prefix_i ‖ c[a_j : b_j] ‖ suffix_i`;
  4. rebuilds R_{i,j} from its decommitment.
  - Consecutive slices and overlap are checked by construction: every slice comes from the one
    encoding, at the re-derived ranges.
  - Size: N_cat · K · ~90 KB, so about 10.8 MB for 3 categories × 40 chunks [MODEL].
- **Later, L-S (option S, §6.3).** One fresh per-item seed. Each endpoint's randomness is
  PRF(seed, policy id, chunk index, context), domain-separated per (policy, chunk).
  - The decommitment becomes (content, seed): 32 bytes beyond the content.
  - It needs the security owner's reading S-1 … S-5, plus the per-chunk domain separation.
  - A "per-item salt shared across chunks" is this seed. Without the PRF derivation, a shared salt
    alone does not let one decommitment open the K roots.
- **Without the bundle,** a verifier sees K receipts whose public ranges match the split and cover
  [0, N). It cannot tell that they are over one content; that is inherent to hiding, as in §6.
  - The app's signed manifest (D37) asserts it, and the bundle proves it to an entitled party.
  - Proving in-circuit that two chunks' overlap tokens are equal needs a cross-proof argument. Not
    built.

**13.4 The label: OR over chunks, fail-closed.**
- `label_i = OR_j b_{i,j}`. The verifier computes it from the public per-chunk bits.
- Under B-4, the label is 1 (flagged) when any of these holds:
  - a chunk index in 0 … K−1 has no accepted proof;
  - a chunk appears twice;
  - a range is not the split's;
  - the chunks name different N, policy or model.
- **Leaks:**
  - K bits per category instead of one, so a flagged label also shows the token range that
    triggered it;
  - N is public (B-5 already makes n public; under chunking the total is public);
  - §5's edit leak becomes per chunk.
- **Context:** each chunk is classified without the rest of the post.
  - Meaning spread across a cut can be missed, or a chunk misread out of context.
  - Overlap reduces the first.
  - Agreement with the unchunked reference at each chunk size is the F11 measurement above.
- Hiding the per-chunk bits needs one aggregation proof (the OR inside a proof over all chunk
  receipts). That is the end state, not built.

**13.5 Code (R-C1).**
- A `ChunkPlan { size, overlap }` in the classifier profile, fixed per deployment profile. The rung
  uses size = T − P0 − S = 23 and overlap 4.
- `chunk_ranges(N, plan)`, and a `ChunkRef` in the statement, absorbed under `classify-chunk`.
- `prove --chunk J` reads the whole content and slices chunk J itself.
- `verify` re-derives the range.
- `input-owner` checks the slice of the whole content.
- `label` verifies every chunk run of one item and prints the OR, fail-closed.

## 14. Addendum v2.3 (2026-10-28): the tables tied to the pinned tensor (rung R-C2)

**14.1 The gap R-C2 closes.** In R-C1 the classifier's public tables were checked only against the
digests their own manifests declared:
- `margin_int16.bin` (the row `w = yes − no`) was a given table, not derived from the model;
- `embedding_int16.bin` was never tied to the model's tied tensor;
- `classifier.json`'s BOS and final norm were not compared with the export's.

So a tables directory with a doctored margin row and a rehashed `classifier.json` gave a valid proof
about a row that is not the model's. This is the classifier side of native review finding R12-F1
(coordinator 2026-10-26 20:11).

**14.2 The rule.** Prove and verify both re-derive the tables and refuse any disagreement. There is
no "prefer the file" fallback (coordinator 2026-10-28 21:35, condition 1).
- **The margin row.** `w = floor((E[yes] − E[no]) · g / scale + 0.5)`, from the pinned tied tensor.
  - `yes`, `no`, the public `scale` and the threshold `c` come only from the export profile's
    `classifier_margin_parameters`, inside the profile digest the trained statement binds (reviewer
    requirement 1, REVIEW_R12B §5). The pre-registered policy (B-6 = D45(2)) must name the same four
    values, and any copy in `classifier.json` must equal them; either disagreement is a refusal. The
    scale is a policy constant too, written into the classifier profile text. (Corrected in round 14,
    REVIEW_R13 N-r13-4: this line said "only from the pre-registered policy".)
  - `g` is the checkpoint's final-norm weight vector.
  - A word outside [−32767, 32767] is refused, never clamped (condition 3).
  - `margin_int16.bin` must equal the derived row; the run uses the derived row.
- **The embedding.** The SHA-256 of the int16 table is derived from the same tensor. The file must
  have exactly that digest.
- **BOS and the final norm.** These come from the export's `profile.json.token_io_parameters`, which
  lies inside the profile digest the trained statement binds. The derivation's own read of
  `profile.json` must have the loaded export's digest. `classifier.json`'s copies must equal these
  values.

**14.3 Sources** (one per block profile; anything else is refused by name):
- **Shieldstral-1.0-3B** (every registered Shieldstral block profile). Native R12b's public
  `tied_tables::recompute_tied_tables(export, Some((yes, no, scale)))`, which authenticates and
  streams the 7.7 GB checkpoint: 17.3 s per call measured by the token lane with a warm page cache
  (round 13, r13/logs/shieldstral-r12b.log; the native lane's earlier figure was about 55 s cold)
  [MEASURED, n=1]. Every prove and every verify streams it TWICE (once in the export load's tied
  check, once in the recompute: REVIEW_R13 N-r13-5, open). The quantizer
  is the native lane's, spelled out in its SOL_REPORT_20261028.md. The registered card policy uses the
  native lane's chosen scale 4.08288030735373e-6 (zero coordinate refusals [COUNTED]).
- **The development rung** (d 384, V 300, synthetic export, no rotation). R12b's function cannot be
  called here: it is pinned to Shieldstral's 131072 × 3072 tensor.
  - The rung uses a pinned synthetic BF16 tensor, `dev_tied_tensor_bf16.bin` in `--tables`: 300 × 384
    rows, then 384 norm weights. Its SHA-256 is `bba6d094…`.
  - The tensor is quantized with R12b's own `quantize` / `bf16` / `norm` functions. Making them
    callable from the token lane took three visibility words and one re-export line, additive.
  - An independent Python reference (`r13/tools/dev_tied_reference.py`) reproduces the pin and the
    derived digests.

**14.4 Also in R-C2.**
- The statement schema becomes `zk60-classify-run/2`, adding `margin_scale` and `tied_source`.
- `--min-bits` below the run profile's floor is refused: 93 only at the development rung, 95
  everywhere else (D27).

**14.5 Cost and what it does not do.**
- At Shieldstral, every prove and every verify pays the checkpoint pass. A one-time public commitment
  to the tables (backlog S6), or a derivation cached under the checkpoint pin, would amortize it.
- R-C2 binds the tables to the model. It makes no privacy claim and no classifier-fidelity claim.

## 15. Addendum v2.4 (2026-10-29, token round 14 = rung R-C3): short items, and the binding in the library

**15.1 Rulings.** Victor accepted the four classifier rulings on 2026-10-29 01:04 UTC (register D45):
(1) the content length is public (B-5, option N, the built variant); (2) one fixed policy list, one
threshold each, never re-prove an item under another policy or threshold (B-6); (3) the proof is linked to
the post by its sealed input fingerprint, stored and anchored, the app keeping the opening (B-8, amends
D23); (4) fail closed (B-4). The ruling switches' text in the profile and the fail-closed line now name D45.
Round 14 stays inside D45(1): it reveals nothing beyond n, T, P0, S and public policy constants.

**15.2 Short items (Astra, 2026-10-29 00:29:56; the trailing-pad route of §13.1).** An item of N content ids
with `1 <= N < n_i = T − P0 − S` is ONE chunk `[0, N)` of its true length, at the profile's T:

  `tok = prefix ‖ c[0 : N] ‖ suffix ‖ pad^(T − P0 − N − S)`

- `pad` is a PUBLIC policy constant (the development rung: 2; Shieldstral's card policy: 11, tekken.json's
  `<pad>`, a control id, = generation_config.json's `pad_token_id`).
- **Pinning.** The template indicator π covers the trailing positions and κ(t) = pad there, so the template
  clause (§3.1, its own fresh coefficient) pins every one of them; the control column uses `ctl(pad)` there,
  so the LogUp matches the table's own entry. The owner's check (§6.1) compares them too.
- **The verdict row.** Stage OUT-C's IO-in reads the public row `P0 + N + S − 1` (the suffix's last
  position), `T − 1` when there is no pad. It is derived from (P0, N, S), all public.
- **Why the verdict is the model's on the short item** (v2.5: corrected per REVIEW_R14 N-r14-2; v2.4 gave
  the witness's `MASK_SCORE` as the reason, which is only what the HONEST prover computes, and the exp of
  `max − MASK_SCORE` is in general not zero). The reason that holds against a cheating prover is the
  RELATION of every block, native R12b's `argument.rs` (REVIEW_R14 §3, line numbers of frozen-r14):
  * the causal mask is a PUBLIC column, `causal_mask_at(sh)` (`:1053`), 1 on j ≤ t and 0 on j > t;
  * SC_RS (`:1308–1321`) sums `mask · E`, so each row's softmax denominator `Sum` is causal;
  * SC_SZC's division clause (`:1939`), `c2 = mask·E·2^F_P − P·Sum − ρ`, with P, ρ and σ = Sum − 1 − ρ in
    byte limbs (so each lies in a range far below p: P·Sum + ρ is about 2^40 at the largest registered shape),
    forces P = ρ = 0 wherever mask = 0; on a DD profile the dictionary tuple `(Sum, mask·E, P)` (`:1817`)
    looks P up as ⌊0 · 2^F_P / Sum⌋ = 0;
  * SC_PV (`:1431–1456`) sums P·V over every source position, so a masked weight would be the only way a
    later row could enter, and it is forced to 0;
  * every other block operation is row-local (norms, RoPE, FFN, residuals), and the max selector's value is
    read from the row's own scores (at a masked j it is −127, attainable only if every true score is −127).

  Hence each block's row t is a function of rows ≤ t of its input, and the verdict row `P0 + N + S − 1` is a
  function of the prefix, the content and the suffix only. The review's consistent forgery (S5b: a masked
  weight P = 1/8 at a pad column, with the cheating prover's PV over every position so every later plane is
  consistent; it moved the margin 5,269,429 → 5,214,444) was refused at block 0, slot 17, the softmax
  zero-check: the division clause above. The honest pad rows are computed and proved like every row; a test
  shows other ids at the pad positions give the same margin. A pad row can still trip a block's range
  refusal (CS-3, N-r14-6); then the item has no proof and D45(4) applies. At Shieldstral that pad-row
  behaviour is to be checked when its classifier run profile is registered.
- **The split.** `chunk_ranges(N, plan)` returns `[(0, N)]` for `1 <= N < size` and refuses N = 0. The
  verifier derives the plan's size from the shape and the policy (never from n) and requires n = the
  chunk's length, so the prover still never chooses n (§13.1). The label (§13.4) over the one chunk is its
  verdict; coverage of `[0, N)` is exact.
- **What becomes public.** Nothing new: n (= N) was public (D45(1)); the pad id, the item length
  `P0 + N + S`, the pad count and the verdict row are functions of public values. The profile text names
  `item-length`, `pad-id`, `pad-positions`, `verdict-row` and `short-content=one-chunk-of-its-length-pad-pinned`;
  the statement schema becomes `zk60-classify-run/3` with `item_length`, `pad_id`, `pad_positions`,
  `verdict_row`. **C-13 still applies:** the privacy gate's pad controls must cover the short-item
  configuration before any figure about it is quoted.
- **Coverage** [COUNTED, input lengths only, r14/short_item_coverage.json]: Astra's 4,872 benchmark
  item/policy pairs are all admitted at T128 and T256 (round 13: 23–67% at T128, 0–10% at T256).

**15.3 The binding in the library (REVIEW_R13 N-r13-1, N-r13-2, N-r13-6).**
- Every classifier run entry point (`ClassifyRunStatement::new` / `new_chunk`, `prove_classify_run(_with)`,
  `verify_classify_run(_with)`, and through them the run capture's replay) takes `BoundClassifierTables`, a
  type whose fields are private to `classify_tied.rs`. Outside it a value exists only as `load_bound_tables`
  returns it: the §14 re-derivation under the trained statement's own `export_profile_sha256` and residual
  unit, then the file comparison. Test builds alone have a second constructor for the relation tests'
  generic tables, marked not-derived; the capture replay refuses such a run.
- The statement constructor checks that the tables were derived for THIS trained statement (identity and
  profile digest), that the policy names the bound margin parameters, and that the block profile and the run
  profile name one tied source (N-r13-6). BOS and the final norm are the tables'. Prove and verify check the
  tables are the statement's.
- The post-derivation profile-digest check (§14.2) is now covered by a test that fails without it: a stub
  in place of native R12b's recompute returns another profile's digest (N-r13-2; the mutation run is in the
  round-14 ledger).
- The gate's capture fixture and `capture_a_classify_rung_run` prove with the derived tables (each placed
  policy with its own export profile, N-r13-3).

**15.4 Not done here.** N-r13-5 (two checkpoint streams per Shieldstral prove / verify), the Shieldstral
classifier run profile and its pad-row check, the hidden-length variant (§3.4 option H, not needed under
D45(1)), any privacy or fidelity claim.

## 16. Addendum v2.5 (2026-10-29, token round 15): the label's whole-post check, the capture format, notes

**16.1 The label checks the post's own length (REVIEW_R14 N-r14-1).** `label` verifies each chunk run and
checks that the runs are one item's whole split (§13.4), but the proofs cannot tell how long the POST is: a
proof set of only the post's first k < N ids (since §15 a short item of any k ≥ 1 is one chunk; before, a
k-id item of at least one full chunk) labelled cleanly with `content_total` = k. Round 15:
- `zk60_classify label … --expect-total N` is **required**; N is the post's own token count, counted by the
  caller with the policy's pinned tokenizer (public by D45(1)), never read from the proofs. Without it, or
  with 0 or a non-number, the label is refused with the fail-closed line (D45(4)).
- The library's `aggregate_label(seen, expect_total)` refuses unless every run's `content_total` is N, the
  runs' chunk count is the split's, each run's range is exactly its index's range in `chunk_ranges(N, plan)`,
  every index appears once, and the ranges together cover `[0, N)` with no gap and nothing beyond. The
  label event prints `expect_total` beside `content_total`.
- The app's recipe (cli/README.md): one item per post; pass the post's own count as `--expect-total`; the
  app's adapter makes the same comparison itself (the coordinator's 2026-10-29 03:05 note to Astra), so the
  CLI's check is defence in depth. `input-owner` already refused a content of another length; D45(3) ties
  each proof to its post.
- Nothing becomes public that was not: N is the statement's `content_total`.

**16.2 The capture format (gate round 18, F18-1).** The token-run and classifier run files listed all 24
entries of `Shape::slots()` (MAX_SLOTS; the 24th `(0, 0, 0)` on every non-DD shape) under `n_slots` 23. They
now list exactly `n_slots` = N_SLOTS triples, as the block run file does. Reader contract (written on the
writer): `shape.slots` holds exactly `shape.n_slots` triples, the block stages' slots in transcript order;
the replay admits only N_SLOTS-slot block stages, so no capture exists for a block running native R9's DD
slot. The gate's tools v21 already accept both forms (an all-zero extra triple is stripped). No receipt, no
statement and no transcript byte moves: only `run.json`'s slot list.

**16.3 The CLI-path capture of a short item (gate H18-1)** is now the token tree's own `#[ignore]`d hook,
`classify_capture_tests::capture_a_short_item_through_the_classify_cli` (`HL_PB_CLI_SHORT_N`, default 22),
adopted from the gate's round-18 patch; it asserts the published statement's short-item fields and the slot
count on the bundle.

**16.4 Observation O18-1 (the gate, round 18): the development rung's margin hardly depends on the
content.** The gate placed c from each item's own margin and found −190166 ± 1 at n = 11, 20, 22, 23 and for
both chunks of a 27-id item, and −202071 ± 1 at n = 1 (round 14 saw the same: the 20-id item's margin equals
the 23-id item's, 5,269,429). The synthetic generic blocks keep the verdict row's output close to a function
of its position. So the rung's captures and this tree's tests barely exercise the margin's dependence on the
content: the verdict-flip tests place c per item or swap the policy's yes / no ids, they do not flip a
verdict by changing the content. This is a generic-honest-witness note, not a soundness gap (the relation
does not depend on the margin's spread). Content-dependence of the verdict is a fidelity fact to be shown on
a trained export (Shieldstral, F11), not claimed here.

**16.5 Notes carried.**
- N-r14-2's last part (the `ctl_q` comment in `classify.rs`, "0 at content and pad positions": the trailing
  pads carry `ctl(pad)`) is NOT fixed in round 15: `classify.rs` is a capture source pin the gate ports by
  digest, so a comment-only change would force a re-port; it goes with the next round that changes the file.
- N-r14-4: the next-token test fixtures (`cli_tests.rs`, `r3_tests.rs`) write under TMPDIR when set, else
  `~/zk60-artifacts/token-io/test-fixtures/`, never `/tmp` by default.
- Open as before: N-r14-3 (stage-level primitives `pub(crate)` with raw tables), N-r14-6 / N-r13-5 and the
  Shieldstral classifier run profile; C-13 for any figure about short items; no privacy or fidelity claim.
