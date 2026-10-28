# Token I/O, classifier variant: a public verdict over hidden content (design v1)

Token-I/O lane, round 12 (2026-10-21). Status: **design for the adversarial check; nothing
built.** Not a privacy acceptance. It follows DESIGN v3
(`results/zk60_token_io_design_20261017/DESIGN.md`, cited as "v3 §n") and the built
token run on frozen-r11 / binary `0c9f247c…`. It rests on these rulings:
- D38 (a)–(c): Shieldstral-1.0-3B, text only; the proof states z_yes − z_no > c; only the
  verdict, the model identity and the policy text become public.
- D36, which is extended to frozen-r11.
- D26 (the token endpoints).
- D23 (endpoint roots are never registered or referred to later).
- D34 (the stage-IN refusal is priced as a distance term).

Labels: [COUNTED] is from the layout replica or the code; [MODEL] is an estimate; [OPEN] is a
fact to be fixed during implementation.

## 1. Plain-words summary

The run is the next-token run with two changes.
- **The input side** gets a public template around the hidden content: the system prompt,
  `<Instruct>` (the policy), `<Query>`, the `<Document>:` wrapper and `[/INST]`. Stage IN gains
  one clause that pins every template position to its public token id. The content positions
  stay hidden.
- **The output side** replaces the 131k-row head and the argmax with **one dot product**: the
  normalised last row times the public vector w_Δ (the "yes" head row minus the "no" head row,
  each row multiplied by its public scale). The result is the integer margin Δ. A five-byte
  range proof then shows Δ > c when the public **verdict bit** b is 1, or Δ ≤ c when b is 0.

There is **no output endpoint** and no owner opening. b is a field of the public statement,
absorbed into the transcript, so a proof made for b = 1 cannot verify under b = 0.

The verifier never sees the content ids, any activation, the logits, Δ or its magnitude. It
learns b, the model, the template, the content length n (public-row variant) and the
threshold c.

## 2. Exactly what becomes public, and what stays hidden

**Public (in the statement or its digests):**
* the model: the trained-statement identity (the 26 blocks' digests and calibration, the YaRN
  RoPE table under F1, the tied-embedding derivation under F3) and the export variant;
* the tables: the int16 embedding (stage IN), the two int8 head rows W'_yes and W'_no with
  their multipliers m_yes and m_no (or only w_Δ, which is derived from them; §4), V = 131,072,
  d = 3072, BOS, and the final-norm constants;
* the yes and no token ids [OPEN: pin both from the tokenizer and Mistral's reference scorer];
* the threshold c (an integer; §4.5) and its display form τ;
* **the template**:
  - the prefix token ids (positions 0 … P0−1, BOS first) and the suffix token ids (the last S
    positions; S = 1 for `[/INST]`);
  - the policy text (it is inside the prefix);
  - P0, S, the content length n and T = P0 + n + S. The survey's 7-category template gives
    P0 ≈ 90 [DER, survey];
* **the verdict b** ∈ {0, 1}. b = 1 means "flagged": the model answered "yes" with margin above
  c. Whether "yes" means unsafe is fixed by the public Query text;
* as in every run: the context label and context, the input token endpoint root, the
  whole-run floor, the run and block profiles, and L = 26.

**Hidden:**
* the content's token ids (positions P0 … P0+n−1) and their embedding rows;
* every activation and inter-block plane;
* the final-norm values y;
* both logits;
* the margin Δ and the range limbs δ (so no score and no magnitude);
* everything the next-token run already hides.

**Removed compared with the next-token run:** the output token endpoint, its root, the
owner's decommitment of the answer, and the head's vocabulary domain.

## 3. Input side: public template plus hidden content (stage IN-C)

**3.1 The relation.** Stage IN is v3 §2.3 unchanged, plus one batched clause in the query
zero-check, with its **own fresh coefficient** μ_tmpl drawn after A_in, M_in and H_in (the v3
N-3 batching rule):

  `eq(τ, t) · μ_tmpl · π(t) · (tok(t) − κ(t))`

- π is the public indicator of the template positions (prefix ∪ suffix).
- κ is the public vector of template ids, zero at the content positions and the pads.

This generalises the BOS clause, since BOS is the template id at t = 0. Both clauses are kept:
the BOS clause and its constant stay as built (D25 T8, C-d), and the door checks κ(0) = BOS.
The LogUp then forces `x[t, ·] = E[κ(t), ·]` at every template row, exactly as for content rows.

**3.2 Soundness.** With μ_tmpl fresh, a forger who satisfies the other clauses must satisfy
π(t)(tok(t) − κ(t)) = 0 at every t, except with probability (degree)/|F_p²|. Folding the
template clause into an existing coefficient would let it cancel against the LogUp clause, as
CHECK2 N-1 did for BOS (v3 §2.3).

**3.3 Endpoint.** The input token endpoint holds the **whole** token plane, as built: one site
in the public-row variant (`data + 5` rows, rate 1/8). Its IO-in slot is unchanged
(`end = supp_T · tok`, whole half).
- The template words in the endpoint are public values at known positions. Hiding does not
  depend on any data word being unknown: today's BOS word and zero pads are already public.
- The input owner's check (built: `input-owner`) re-encodes the plane at the derived geometry,
  rebuilds the root, and now confirms the template ids at the template positions as well as
  the content.
- Choosing a content-only endpoint would need a shifted IO-in slot (a new form); I chose
  against it.

**3.4 What the public-row variant discloses: n.** The content length in tokens is public
(T = P0 + n + S).
- Any T up to T_max is expressible, because blocks already run with fewer tokens than their
  padded size (`Shape::rung_g` / `rung_k4`: 24 tokens in 32 rows).
- The run profile states the class of T (for example 2 ≤ n, T ≤ 512), not one T per profile.
  Registering the profile family is a statement item: the W-2 census and the profile strings.
- *Hidden length* is a later option (sketch). D26's two-site endpoint with the selector s
  sealed in half 1. The content and suffix move, so the suffix is checked through the selector
  (Σ_t s(t)·tok(t) = id([/INST]), a linear clause with its own coefficient), and stage OUT-C
  reads row P−1 through SEL. Nothing here is built for it.

**3.5 The tokenisation boundary [OPEN, a check item].** Shieldstral's chat template tokenises
the user message as one string, so the first content token could merge with the wrapper's last
characters. The design defines the token sequence as **canonical_tokenize(full message)**, and
requires that the prefix and suffix ids are a stable prefix and suffix for every content.
- The app refuses content whose tokenisation would change the template's ids. In practice,
  content that begins without a separator after `<Document>:` may merge.
- To be measured with the model's tokenizer on a corpus before building
  (`results/zk60_classifier_survey_20261021/count_tokens.py` is the starting point).

## 4. Output side: the margin and the verdict (stage OUT-C)

**4.1 The relation.**
1. **Row selection:** public last row. Stage OUT-C's `x` row is B_out at row T−1 (the suffix
   token `[/INST]`, where the verdict token would be generated), with coordinates fixed to the
   bits of T−1. This is v3 §3.1 item 1, mode (i).
2. **Final RMSNorm:** v3 §3.1 item 2 unchanged (uniform gain g0, folded form, remainder
   windows exact, `y ∈ [−127, 127]` by the `sym` lookups, `x` int16 re-proved).
   - At width 3072, D_max = isqrt(3072 · 32768² + Ceps) has 21 bits, so **tn = 10** keeps the
     window at exactly 32 bits (as at width 2048) [DER].
   - Cn is the calibrated value [OPEN: calibration lane].
   - An int8 overflow of y is D20's refusal at the door, before any commitment, as built.
3. **The margin vector (public):** `w_Δ(i) = m_yes·W'_yes(i) − m_no·W'_no(i)` for i < d, and 0
   on the pad.
   - The two rows are v3 §3.1 item 3's per-row int8 head, derived from the **tied** matrix:
     `W' = round(E · diag(norm_weight) · R^T / s_j)`, with `m_j = max(1, round(2^12 s_j / max(s_yes, s_no)))`.
   - Then |w_Δ(i)| ≤ 2 · 2^12 · 127 = 2^20.99, and the integer margin `Δ = Σ_i y(i)·w_Δ(i) = l_yes − l_no`
     satisfies |Δ| ≤ B_Δ = d · 127 · 2^13 · 127 = **2^38.56** at d = 3072 [DER].
   - The individual logits are never formed, not even virtually. Only their difference enters.
4. **The verdict and the range proof.** b ∈ {0, 1} is public, and σ = 2b − 1 = ±1 is public.
   Define `δ = σ(Δ − c) − b`, so that b = 1 ⇔ δ = Δ − c − 1 ≥ 0 ⇔ Δ > c, and b = 0 ⇔ δ = c − Δ ≥ 0 ⇔ Δ ≤ c.
   Commit δ as L byte limbs `λ_0 … λ_{L−1}`, every limb a byte by the U8 lookup.
   - **L is derived (TF-1):** `window = bits(B_Δ + c_max + 1)` over the declared classes of d, the
     multipliers and c, and L = ⌈window / 8⌉. With c_max = 2^38, the window is 40 bits, so **L = 5**.
   - The door checks `2^(8L) + 2^window < p`.
   - There is no top-limb pin (as v3 C-4).
5. **The margin identity (one slot, MRG):** over the Do cube (d_pad = 4096),
   `Σ_i [ y(i)·w_Δ(i) − σ·λ(i)·g(i) ] = σ·b + c`, with λ lifted onto Do (entries 0 … L−1) and
   `g(i) = 256^i` for i < L, 0 elsewhere (public).
   - Every monomial carries a public factor (w_Δ or g), and the right side is public (v3 B-3).
   - A pad-zero clause on λ beyond L goes into DZC, with its own fresh coefficient.
   - MRG replaces HEAD, VZC, RSEL and IO-out.

**4.2 Why the verdict is right (soundness).**
- MRG at a random point, drawn after A_out, gives the field identity `Δ − σδ = σb + c`, with
  y the committed norm output (in [−127, 127] by the `sym` lookups) and δ = Σ_k 256^k λ_k.
- Every term is an integer: |Δ| < 2^38.56, δ ∈ [0, 2^(8L)) = [0, 2^40) by the byte lookups,
  and |σb + c| ≤ 2^38 + 1. So the field identity is an integer identity (the no-wrap condition
  of 4.1 item 4, far below p/2).
- Hence `Δ − c = σ(δ + b)`.
  - b = 1: Δ − c = δ + 1 ≥ 1, so Δ > c.
  - b = 0: Δ − c = −δ ≤ 0, so Δ ≤ c.
- A forger who flips b must exhibit δ' = −δ − 1 < 0 (or the mirror case) as five bytes, which
  is impossible.
- The inner product Δ is the true integer y · w_Δ: the MRG sumcheck runs at a random point,
  and every product term is below 2^28 ≪ p.

**Completeness.** The honest δ = |Δ − c| − b lies in [0, B_Δ + c_max] ⊂ [0, 2^40), so no
honest verdict is ever refused. The tie Δ = c gives b = 0 and δ = 0. That matches Mistral's
"flagged **above** τ".

**Every relation is load-bearing** (R-C0 must show each, as R0 V13–V15 did):
- Without the byte lookups on λ, δ can be negative mod p, and b flips.
- Without the pad-zero clause on λ, the identity still holds (g = 0 beyond L), but byte lookups
  on free pad entries are an unbound channel (P-1).
- Without b in the transcript before stage OUT-C's draws, a proof could be bound to either
  verdict after the fact. b goes into the run statement's transcript constructor, so every
  stage binds it.

**4.3 Planes and slots of stage OUT-C** (U8, public row, T_out = 1)

| domain | A planes | lookups / entry | H helpers (Fp2) |
|---|---|---:|---:|
| To (1) | `D`, `Dsq` | — | — |
| Lo (16, lifted) | isqrt limb plane | 1 | 1 |
| Do (d_pad = 4096) | `x`, `xl0`, `xl1`, `y`, `rho ×4`, `sigma ×4`, **`λ` (5 live entries, lifted)** | 12 (13 on λ's entries) | 6 |
| Tab | U8 multiplicities | — | table helper + `u` |

Slots, 8 in all:
- unchanged from stage OUT: IO-in (`x` row = B_out row T−1), SS, TZC, LZC;
- DZC (norm quotient, `x` limbs, helpers, pad, **λ pad-zero**);
- **MRG**;
- TAB, ZS.

There is no Vo domain, so no `e`, `tok`, `M`, HEAD, VZC, RSEL or IO-out.

**4.4 The statement and the transcript.** The run statement gains:
- `classifier`: the yes / no ids, w_Δ's digest (or the two rows' and multipliers' digests), c, τ
  and the rule text "flagged iff z_yes − z_no > c";
- `template`: the prefix and suffix ids by digest (the ids themselves in the statement file),
  P0, S, n, and a policy-text digest for display;
- `verdict`: "flagged" or "not-flagged".

`TokenRunStatement::transcript()` absorbs all of them before any segment, as it absorbs the
calibration today. The statement schema bumps (the next-token runs stay `/2`; the classifier
variant gets its own schema and run profile family).

**4.5 The threshold.** D38's rule is flagged iff z_yes − z_no > ln(τ / (1−τ)).
- At τ = 0.5 that is **c = 0**, exact at any logit scale: the MVP's value.
- For another τ, c = ⌊θ / κ⌋, where θ = ln(τ / (1−τ)) and κ is the integer logit's public scale
  (the y scale times max(s_yes, s_no) / 2^12). Rounding is toward "not flagged" at the
  boundary, and the statement prints both θ and c.
- **c is a profile constant, not a per-run choice** (§5 rule O-1).

## 5. What else could leak, and the operational rules

* **One bit per proof, by construction.** The verifier's view adds b to what the next-token run
  shows, minus the output endpoint. Δ's magnitude is hidden: the limbs are committed (hiding
  PCS), the window and L are public and fixed by the class, and the U8 multiplicities are
  committed. The MRG transcript is CFS-masked like every slot. **[gate]** The rank / CFS gate
  must re-read MRG: two public-factor inner products, terminal claims on y and λ.
* **O-1, one threshold per (content, policy).** Proofs over the same content at k thresholds
  reveal k bits: a binary search on Δ. The threshold is a profile constant (c = 0 for the MVP),
  and the platform publishes one verdict per item and policy. Proofs under several policies
  are each one intended bit. This is an operations rule for the app, Victor's to accept, with
  the policies listed.
* **O-2, the refusal channel.** D20's norm-overflow refusal precedes the header (D29's reading,
  built). D34's distance term carries for stage IN (only the content's τ rows are inverted;
  the template rows are public, so their inversions disclose nothing). Stage OUT-C's byte
  inversions are the 256 table values, which D34's count already includes. Refused runs are
  never transmitted (D21).
* **n is public** in this variant (§3.4).
* **The template is public by design** (D38 c): the policy text is part of what the app
  publishes.

## 6. Binding the proof to the posted item

**Recommended: R, the input endpoint root, with the input owner's check.**
- The statement already carries the input endpoint's root, and the IO-in slot binds the proved
  token plane to it. So "the verdict is about the token plane under root R" is what the proof
  already says. No new cryptography is needed.
- The app stores the accepted proof next to the item, and holds the endpoint's decommitment
  (all rows, pads and leaf salts).
- Anyone given the item's bytes and the decommitment:
  1. re-tokenises the full message with the public tokenizer (§3.5);
  2. checks the template ids and the content ids against the decommitted plane;
  3. rebuilds the root (the built `input-owner` check, extended to the template).
- When the item is public, the app may publish the decommitment with it: the decommitment
  reveals only the content, which is then public anyway. When it is private, only parties
  entitled to the content receive it.
- Tokenisation is **checked**, not proved: deterministic, by anyone who has the bytes.

**This needs a D23 amendment (Victor's).** Storing the root beside the item is "registering"
it under D23. Proposed wording: "an accepted classifier receipt's input root may be recorded by
the app beside its item, provided no later proof ever claims or opens that root, and the
decommitment goes only to parties entitled to the content." D11's concern (two openings) does
not arise: there is one in-proof opening, and the decommitment is the content itself. **[gate]**
The privacy statement must say whether recording the root changes D19b's hiding argument; the
security owner reads that.

**Rejected:**
- **A plain hash of the content (or its ids) in the statement.** The proof does not compute it,
  so it is the prover's unchecked claim: unsound. It would also leak short, guessable private
  content to a dictionary attack.
- **An in-circuit hash of a third-party-sealed handle (D18 option B).** This is the right end
  state, so the platform rather than the prover fixes the commitment. It costs about +13% on
  the private pass [COUNTED earlier, untested] and is not built.

## 7. What the token stages need from the native lane (coordinate through the coordinator)

* **F3, tied embeddings.** One float matrix gives (i) stage IN's int16 table (`x_in_L00 = table[tok]`,
  rotation and s_in applied) and (ii) the two int8 head rows with norm_weight and R^T folded in.
  The importer must emit both, with their digests in the trained statement. Then a verifier
  can re-derive w_Δ from the model files and the yes / no ids.
* **F1 (YaRN RoPE table) and F2 (head_dim 128 with q width 4096 ≠ d = 3072)** are block-side.
  The token stages see only d = 3072 (d_pad 4096) and V = 131,072 (V_pad = 2^17, as at 8B).
* **Stage IN at V = 131,072, d = 3072:** the table zero-check over 2^17 and the verifier's one
  O(V·d) fold of E at r_emb (403 M words) are the same class as Llama-3-8B's built stage IN.

## 8. F6, public-prefix reuse (sketch only)

**Idea.** Under P1 the weights and the template are public. Causal attention lets the content
and suffix rows interact with the prefix only through the prefix's K and V at each layer. So
the prefix rows (P0 ≈ 90) need not be proved.
- Every block proves only rows P0 … T−1 (n + 1 rows).
- Its attention reads the prefix K and V as **public tables**: post-RoPE K and V for positions
  0 … P0−1, computed by the integer model from the template.
- New slot shapes, per block:
  - the score slot splits into a public-key part (`q · K_pub`: a matmul slot with a public
    factor) and the private part;
  - the softmax normalisation (FN / DD) spans both parts;
  - PV becomes `Σ_k p(q, k) · V(k)` with V_pub as a public factor on the prefix keys.
- The prefix rows' own norms, projections and FFN vanish from the proof.

**Verifier.** The verifier must know K_pub and V_pub for all 26 layers.
- Recomputing them is a 90-token integer forward pass: about 309 G multiply-accumulates, about
  30 s at our witness builder's measured CPU rate [MODEL].
- So publish them as a **template cache** per (model, template), with its digest absorbed by
  the statement, and verify it **once** per template: by recomputation, or by a non-zero-knowledge
  proof, since nothing in it is private. It is then reused by every classification under that
  policy.

**Counted saving** [COUNTED by the layout replica `layout.py`, checked byte-exact against the
native lane's Rust ladder, on Shieldstral's padded domains; F2's exact layout may move it].
Per block: committed A + H elements and byte lookups, for the full run and for F6's n + 1 rows;
the score domain under F6 is (n+1)_pad × T_pad × 32. Output: `classifier/f6_count.py` /
`f6_count.json`.

| content n | T (pad) | full: elements / byte lookups | F6 proved rows (pad) | F6: elements / byte lookups (S as lower bound) | F6 score entries vs full | gain (elements) |
|---:|---:|---|---:|---|---|---:|
| 32 | 123 (128) | 123.8 M / 52.0 M | 33 (64) | 58.4 M / 24.3 M | 0.26 M vs 0.52 M | 2.12x |
| 48 | 139 (256) | 284.8 M / 121.8 M | 49 (64) | 58.4 M / 24.3 M | 0.52 M vs 2.10 M | 4.88x |
| 64 | 155 (256) | 284.8 M / 121.8 M | 65 (128) | 123.8 M / 52.0 M | 1.05 M vs 2.10 M | 2.30x |
| 128 | 219 (256) | 284.8 M / 121.8 M | 129 (256) | 284.8 M / 121.8 M | 2.10 M vs 2.10 M | 1.00x |
| 200 | 291 (512) | 675.3 M / 306.3 M | 201 (256) | 284.8 M / 121.8 M | 4.19 M vs 8.39 M | 2.37x |
| 256 | 347 (512) | 675.3 M / 306.3 M | 257 (512) | 675.3 M / 306.3 M | 8.39 M vs 8.39 M | 1.00x |

Reading:
- F6 gains exactly when npow2(n + 1) < npow2(n + 91), i.e. when the proved rows fall into a
  smaller power-of-two bucket than T:
  - n = 1–127: T pads to 128 or 256, the rows to at most 128;
  - n = 166–255: T pads to 512, the rows to 256;
  - and so on.
- The gain is 2.1–2.4x, and up to 4.9x where the rows pad two buckets lower (n = 38–63: rows
  64, T 256).
- It saves nothing where both pad to the same size (n = 128–165, 256–421).
- The power-of-two padding, not the prefix, sets the gain. Non-power-of-two row domains would
  be needed to turn the remaining ~35% of prefix rows into time. That is a native-lane question.
- With the survey's fitted formula [EST, survey §5], a 64-token post goes from about 310 s to
  about 200 s on the laptop.

**Privacy questions for the gate (F6):**
- (G1) The new public-key score slot and the split PV: rank / CFS on terminals that mix hidden
  q or p with public K or V.
- (G2) The softmax row statistics (FN / DD dictionary, exp multiplicities) now range over public
  and private keys. The joint view of exp and division multiplicities at the new geometry
  (D17 rule 3).
- (G3) The public cache's binding: the statement absorbs its digest, and the integer prefix
  computation must equal the proved block semantics exactly (calibration, RoPE positions,
  YaRN). Soundness first, but a mismatch would also be a channel.
- (G4) P0 and the content start are public. Under the later hidden-length variant only the end
  moves: confirm nothing in the cached part depends on n.
- (G5) The verifier-side cache is per policy, so policies are linkable across proofs. They are
  public anyway (D38 c), but say so.

## 9. Costs [MODEL unless marked]

- **Stage OUT-C** drops the Vo domain, which carried most of stage OUT. At the R2 layout,
  TinyLlama's stage OUT is 182 A / 110 H rows at 2^12, about half of them Vo (e, seven limbs,
  four helpers). Stage OUT-C is about 110–120 A and 40–50 H rows: **about 0.6 M committed
  elements and about 37 k byte lookups**, against 2.77 M / 0.97 M for the built 8B stage OUT.
  Its verifier folds w_Δ (4096 words) instead of a 525 M-weight head. Counted exactly at R-C1.
- **Stage IN** is the 8B class (V_pad = 2^17). Its verifier fold of E (403 M words) is the
  dominant verifier cost.
- **The run** is dominated by 26 Shieldstral blocks: per-block elements as in the table of §8
  (full column). Whole-run laptop time for a 64-token post is about 310 s, or about 200 s with
  F6 [EST, survey §5 fit, unvalidated].

## 10. Test-first plan

* **R-C0, reference (Python, beside R0).**
  - The margin rule with ties (Δ = c), |Δ| = B_Δ, both b, c ≠ 0.
  - Forgeries, each accepted when its one relation is removed (V13–V15 style):
    - flipped b;
    - δ negative mod p;
    - non-byte limbs;
    - non-zero λ pads;
    - b not absorbed;
    - a template position changed;
    - the template clause batched without its own coefficient.
* **R-C1, rung (synthetic generic witness, built prover and verifier).** Stage OUT-C and the
  template clause. Honest runs at b = 0, b = 1 and a tie. Every control refused at its
  predicted site (cheating prover). The H-1 sealing pass covers stage OUT-C: δ's limbs are
  checked as bytes before any header, so the t34 lesson is applied up front. The counted layout
  is printed (§9's estimate replaced).
* **R-C2, Shieldstral shapes (once the native F1–F3 land):** a generic dense witness at
  d = 3072, V = 131,072, P0 ≈ 90, n ∈ {32, 64}; the count and the time; the gate's captures.
* **CLI: new subcommands `classify-prove` / `classify-verify` / `classify-input-owner`** (no
  output owner). The frozen next-token commands, and with them D36's pinned behaviour, stay
  byte-identical. Arguments mirror `prove` / `verify`, plus `--template FILE` (ids, 0644
  public) and `--threshold` (checked against the profile constant).

## 11. For the checker, and the rulings this needs

Check items:
- §4.2's integer-identity argument and the derived L;
- that MRG alone binds b (no other slot sees it);
- §3.2's fresh coefficient;
- §5's claim that nothing beyond b leaks (O-1 aside);
- §3.5's tokenisation boundary;
- §6's soundness of binding through the root.

Rulings and readings needed:
- (i) the D23 amendment for app-recorded roots (Victor);
- (ii) O-1, one threshold per (content, policy), as an app operations rule (Victor);
- (iii) the classifier run profile family with T in a class (security owner, W-2 census);
- (iv) the classifier privacy statement: a new argument. D36's output-side parts are replaced,
  and the verdict is a public output (the gate, then review, then Victor).

Open facts:
- the yes / no ids;
- Cn at the final norm;
- template stability;
- Shieldstral's int8 fidelity on ToxicChat / OpenAI Moderation (F11, the fidelity lane).
