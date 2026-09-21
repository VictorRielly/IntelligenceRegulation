# The joint-law composition theorem for a SHAPED block and for a RUN of L blocks

**Drafted by a delegated Opus agent for the security owner.**
2026-09-20, 17:15 PDT (`date` read at 16:57 and again at 17:12 before anything
below was written). Read-only against the lane worktree
`/home/victor/wt-zk60-block125m`, branch `zk60-private-block-125m`, tip
**`caa9b9a`** (`caa9b9a07f14152e9b7753cd11614482a165d6b1`), and against
`/home/victor/wt-zk60-jointview` for the run gate. Nothing was built, nothing
was run against the Rust, no git write was made, no existing file was edited.
Evidence: `results/zk60_joint_law_composition_run/` (one Python file, exact
integer arithmetic, with its output beside it and a README naming every source
line it transcribes).

| Status | **A DRAFT FOR ATTACK. Nothing here establishes a privacy property, for any shape, for any number of blocks.** The accepted statement `ZK60_PRIVACY_STATEMENT_TOY_PROFILE.md` (register D22) covers exactly one artifact — the toy block — and §1 of that page bars the development rung, the 125M block and any multi-block run by name. This memo takes the toy's step 4 (the joint-law composition, `ZK60_JOINT_LAW_COMPOSITION.md`, disposition rulings J-1…J-5) as far as it honestly goes at the shaped layout and for a run, and marks every place it stops. |
|---|---|

**Reading order for a checker.** §7.2 first ("what the checker should attack
first"), then §3.5 (the single randomness stream), then §2.7 and §3.7 (the two
theorems and what they are conditional on), then the gap list in §7.1.

---

## 0. Plain words, for the project owner

One transformer block can now be proved with its input, output and internal
values hidden, and for the *smallest* version of that block the security owner
accepted, this morning, that the proof reveals nothing about them (register
D22). One of the five things that acceptance rests on is a theorem with a
long name: *the joint law of everything the receipt publishes does not depend
on the hidden data*. "Joint" is the whole point. The project has its own
example of two published numbers each of which is perfectly random on its own
and which together hand over the secret; showing each number is safe is not
showing the pair is safe.

Since that acceptance, two things grew.

* The block got **bigger and less tidy**. Real widths are not powers of two,
  so parts of the arithmetic run over padded space; a new term in the proof
  forces every hidden value in that padded space to be zero; attention now has
  fewer key-value heads than query heads, which leaves empty head slots; one
  more digit limb was needed; and the boxes that hold the block's input and
  output were generalised, with five extra random rows instead of the old
  layout, one of which is spare.
* Twelve blocks were **chained into one proof** — a run. Between two blocks
  sits a small sealed box, the *boundary*, claimed once by the block above it
  and once by the block below it, opened exactly once. That means the same
  hidden intermediate now sits inside **three** sealed boxes: block k's big
  one, the boundary, and block k+1's big one.

Neither growth is covered by the accepted theorem. This memo works out what
survives, what needs a new argument, and what simply is not there yet.

**The short answer.** The mathematical core survives, and the run is *less* of
a new problem than it looked: the three-boxes question is the two-boxes
question applied once more, and the run's theorem reduces cleanly to the
block's theorem applied L times plus one product rule. What does **not**
survive is anything that was checked *at the toy layout*: the per-box "nothing
disclosed" result has to be re-earned at each new shape, and a new gap opened
that nobody has written down before —

> **the whole run draws its randomness from ONE generator stream**
> (`run.rs:436`). At the toy, three of the five sealed boxes shared a stream
> and two had their own. In a twelve-block run, **47 of the 49 boxes share one
> stream**, and the design's own recommendation that each box get its own was
> not implemented. Nothing is broken by this — the assumption the project
> already makes covers it — but that assumption is now carrying twelve times
> the weight, and the page that records it says so nowhere.

Two numbers quoted elsewhere move (§6): the run's draw count, harmlessly, and
the probability of the one input-dependent refusal, by about eleven bits in
the wrong direction, because a toy figure was carried to a shape it does not
describe.

---

## 1. The setting, fixed precisely

### 1.1 The three shapes, and what is public about each

| | toy (D22's artifact) | rung-G (development) | 125M |
|---|---|---|---|
| constructor | `shape.rs:234` | `shape.rs:288-308` | `shape.rs:324-327` |
| profile | `…/private-block-t32-poc/1` | `…/private-block-rung-g-t24-dev/1` | `…/private-block-m125/1` |
| tokens / width / hidden | 32 / 16 / 16 | 24 / 96 / 192 | 512 / 768 / 2048 |
| query / KV heads, head dim | 2 / 1, 8 | 6 / 2, 16 | 12 / 4, 64 |
| padded head slots `h_pad` | 2 (none padded) | **8**, padding `{3,7}` | **16**, padding `{3,7,11,15}` |
| message width `n = 2^log_cols`, opened columns `Q` | 256, 256 | 1,024, 256 | 16,384, 256 |
| `A` rows / data rows / groups / claim sites | 455 / 213 / 35 / 120 | 623 / 377 / 36 / 122 | 5,681 / 5,435 / 36 / 122 |
| `H` rows / data rows / groups / eval sites | 384 / 280 / 9 / 51 | 576 / 470 / 9 / 52 | 7,120 / 7,018 / 9 / **50** |
| `M` rows | 50 | 50 | 50 |
| external endpoint rows | 7 | **9** = 4 + 5 | **37** = 32 + 5 |
| internal boundary rows (a run only) | — | **10** = 4 + 2·2 + 2 | **38** = 32 + 2·2 + 2 |
| carries the pad rule | **no** (`shape.rs:369-371`) | yes | yes |

[COUNTED, `run_law_counts.py`; the row formulas are `shape.rs:683-685`,
`endpoint_g.rs:143-149` with `MASK_ROWS = 5` at `:52`, and
`boundary.rs:180-182`. The method reproduces the two frozen receipt totals to
the byte — rung-G 4,234,648 B and 125M 40,782,792 B against `grow_tests.rs`'s
`MODEL_RUNG_G` / `MODEL_M125` — before it computes anything new.]

`H` has **50** planes at 125M and 52 at rung-G: correction C-6 drops two
`Dom::D` helpers because the top norm limb is exactly full there
(`shape.rs:428-430`). That is why the terminal count per stage is 176 at
rung-G and **174** at 125M, and it is the one place where a "same at both
shapes" reflex is wrong.

### 1.2 Everything a run's receipt publishes, in transcript order

A run is `L` stages under **one** transcript (`run.rs:423-535`, module doc
`run.rs:11-18`). Write `B_k` for the internal boundary between blocks `k` and
`k+1`, `k = 1..L−1`.

**The header, absorbed before any commitment exists** (`run.rs:265-283`), six
absorbs in this order: `b"run-shape"` (`L`, tokens, width, hidden, q_heads,
kv_heads, head_dim, `:272-276`); `b"expected-IO"` (the two **external**
endpoint roots, their scales and the IO spec, `:277`, encoding
`private_block.rs:663-672`); `b"public-statement"` (a digest over the `L`
block digests, `:278`, `:181-188`); `b"parameters"` (the run parameter line,
`:279`, `:195-207`); `b"calibration"` (**one** identity for the whole run,
`:280`, value `private_block.rs:198-200`); `b"schedule"` (the run schedule
digest — the parameter line, the layout description and one stage line per
stage, `:281`, `:246-261`, `:213-227`). The transcript state right here is
the **run binding** (`:285-291`), carried in every segment header and
**compared, never adopted** (`wire.rs:374-375`, `:430-432`; ruling M-6).
Under D19a the transcript is keyed by the *shape's* Fiat–Shamir key and the
run is separated from a single-block proof by its own profile domain string
(`protocol::tagged_transcript`, `run.rs:271`).

**Stage `k`** (`run.rs:448-533`), in the order the bytes are produced:

| # | object | field or hash | source |
|---|---|---|---|
| 1 | `start_tag`, 32 B, squeezed from a **discarded clone** of the transcript | hash object (2 `Fp2` rendered as bytes); **never absorbed** | `run.rs:453`, `:365-372` |
| 2 | absorb `k`; absorb block `k`'s public digest | — (absorbs) | `run.rs:455-456` |
| 3 | `B_k`'s root (k < L), absorbed with its rows and row width | **hash object**, and it is on the wire | `run.rs:459-466`; wire `wire.rs:271`, `:388-390` |
| 4 | `A_k`'s root | hash object | `protocol.rs:666` |
| 5 | `M_k`'s root | hash object | `protocol.rs:676` |
| 6 | — (the three LogUp challenges β, γ, α are squeezed here) | challenge | `protocol.rs:682-684` |
| 7 | `H_k`'s root | hash object | `protocol.rs:774` |
| 8 | the 23 slots, in index order: per slot one masked scalar (`b"pb-scalar"`), `(main+ext)` round messages of `d+1` `Fp2` each (`b"sc-round"`), then its terminals (`b"pb-term"`) | **field values** | `protocol.rs:782`; `argument.rs:331`, `:391`; slot ids `layout.rs:763-786` |
| 9 | `M_k`'s opening: `q` (1,024 `Fp2`), `prox` (1,024 `Fp2`), 256 opened columns × 50 rows, with salts and paths | field values + hash objects | `protocol.rs:790`; `zk.rs:373-375` |
| 10 | `A_k`'s opening: 36 group vectors + 1 proximity vector, each `n+Q` `Fp2`; 256 columns × 5,681 rows; salts; paths | field + hash | `protocol.rs:795-796` |
| 11 | `H_k`'s opening: 9 + 1 vectors; 256 columns × 7,120 rows; salts; paths | field + hash | `protocol.rs:799-800` |
| 12 | the **incoming** opening: `B_{k−1}` with **both** its claims (2 group vectors + 1 proximity vector, 256 columns × 38 rows) — or, at `k = 1`, the external input endpoint (1 + 1 vectors, 256 × 37) | field + hash | `run.rs:487-500` |
| 13 | at `k = L` only: the external **output** endpoint's opening | field + hash | `run.rs:501-506` |
| 14 | `end_tag`, 32 B, again from a discarded clone | hash object, never absorbed | `run.rs:512` |

The segment's bytes are the 88-byte header (magic, run binding, `L`, `k`,
`start_tag`), the objects above in that order, and the 32-byte trailer
(`end_tag`): `wire.rs:263-265`, `:269-284`, `:376-413`. Framing is therefore
**120 B per segment**.

**What the theorem's object is.** Exactly the rows marked *field values*: the
`23` masked scalars, the round messages, the terminals, the `M` opening's `q`
and `prox` and column values, and every PCS opening's group vectors,
proximity vector and column values, of **all** `4L+1` commitments. Everything
marked *hash object* — the `3L` block roots, the `L−1` boundary roots, the
two external roots, every leaf salt, every authentication path, the `2L`
position tags and the segment framing — is **handed to the hash layer**, and
§4.3 says exactly what the hand-over is.

**Counts** [COUNTED, `run_law_counts.py`]:

| per stage | rung-G | 125M |
|---|---:|---:|
| masked scalars | 23 | 23 |
| round messages / `Fp2` words in them | 240 / **1,034** | 357 / **1,519** |
| terminals | **176** | **174** |
| `M` opening | 2,048 `Fp2` + 12,800 `Fp` | 2,048 `Fp2` + 12,800 `Fp` |
| `A` opening | 37 × 1,280 `Fp2` + 256 × 623 `Fp` | 37 × 16,640 `Fp2` + 256 × 5,681 `Fp` |
| `H` opening | 10 × 1,280 + 256 × 576 | 10 × 16,640 + 256 × 7,120 |
| one boundary opening | 3 × 1,280 `Fp2` + 256 × 10 `Fp` | 3 × 16,640 + 256 × 38 |
| one external endpoint | 2 × 1,280 + 256 × 9 | 2 × 16,640 + 256 × 37 |

Whole runs, in base-field words (an `Fp2` counting twice): **1,375,206** at
rung-G with `L = 3`; **59,695,840** at 125M with `L = 12`. That last figure
times 8 bytes is 477,566,720 B of the measured 484,100,736 B receipt; the
remaining 6.5 MB are indices, salts, paths, roots and framing. [COUNTED; the
receipt figure is MEASURED by the lane, 2026-09-20 16:30 run.]

### 1.3 The order of commitments and challenges — the design's table, re-checked against `run.rs`

`ZK60_PRIVATE_RUN_MULTI_BLOCK.md` §2.7 tabulates "every challenge and what it
must follow". Re-read line by line against the code:

| challenge | drawn | must follow | code says |
|---|---|---|---|
| β, γ, α of stage `k` | `protocol.rs:682-684` | `A_k` (the three multiplicity planes), `M_k` | **yes** — `A_k` at `:666`, `M_k` at `:676` |
| slot `s`'s CFS multiplier `c` | `argument.rs:310` | `M_k`, `A_k`, `H_k` | **yes** |
| slot 21 / 22's `tau`, round and extension challenges | `argument.rs:1426` etc. | `A_k`, `H_k`, **and the boundary the slot claims** | **yes** — slot 22 claims `B_k`, absorbed at `run.rs:466` earlier in the same stage; slot 21 claims `B_{k−1}`, absorbed in stage `k−1` |
| `M_k`'s `theta` and proximity rhos | `zk.rs` inside `mask_open`, `protocol.rs:790` | all 34 functionals, i.e. all 23 slots | **yes** |
| each opening's group `lambda`s and proximity rho | `pcs.rs:835-856` | that commitment's root and **all** its claims | **yes** |
| `B_{k−1}`'s `lambda`s and column indices | stage `k`, `run.rs:491` | `B_{k−1}`'s root (stage `k−1`) **and both its claims** — block `k−1`'s slot 22 and block `k`'s slot 21 | **yes, and this is the new one.** The code comment is exact: *"the incoming commitment's claim list is complete NOW, and not before"* (`run.rs:486`) |
| the position tags | `run.rs:453`, `:512` | nothing; they are squeezed from a **clone** and advance no state | **yes** (`run.rs:365-372`) |

One difference from the design memo, in the design memo's favour: it withdrew
(correction C4) the claim that step 2 must precede step 3. The code agrees —
no challenge is drawn between the boundary commit and `A_k`'s commit, so the
two orders are equally sound, and step 2 is where it is because it is the
earliest natural point.

**Independent third witness.** The run capture's own transcript replay
reproduces this order (`run_capture.rs:344-366`), and the Python run gate
re-derives **375 transcript positions and 6,086 challenges** of a three-block
rung-G run with nothing left un-re-derived
[MEASURED, `ZK60_NATIVE_RUN_GATE.md` §2.2].

### 1.4 One structural fact that matters and is easy to miss

**The verifier computes the pending boundary claim itself; no claim is ever on
the wire.** `RunVerifier::step` re-derives every geometry from its own
statement and builds both claim lists from the slot terminals
(`run.rs:578-581`, `:622-631`; `protocol.rs:836-840`; the shared push site is
`argument.rs:395-401`, outside the prove/verify `match` that ends at
`argument.rs:384`). `SegGeom`'s doc says it in one line: *"Every number here
is a function of the VERIFIER'S OWN statement … and none of it is ever read
from a frame"* (`wire.rs:286-289`). So a claim contributes to the published
view **only** through its value, and that value **is** a published terminal
(`build_claim(..., value = terms[k])`, `argument.rs:398`) — exactly as at the
toy (`ZK60_JOINT_LAW_COMPOSITION.md` §1.3, last row). [VERIFIED IN THE CODE.]

---

## 2. The theorem for ONE shaped block

The toy theorem is Theorem 3.3 of `ZK60_JOINT_LAW_COMPOSITION.md` §3.3: at
fixed challenges `ρ` on which the prover does not refuse, and in the
uniform-blinding idealisation, the joint law of `(V_sc, V_pcs, V_M)` is the
same for every admissible hidden input, on five hypotheses (H1)–(H5). Take
them one at a time.

### 2.1 (H2) — the mask degrees-of-freedom identity. **Carries verbatim; counts change; still zero slack.** [PROVED HERE]

(H2) is `Im R = C` with every fibre the same size, i.e. Fact 2.1 of
`ZK60_JOINT_LAW_COMPOSITION.md` §2.1: for slot `s` with `N_s = main + ext`
rounds of degree `d_s`, the CFS mask has `L_s = N_s d_s + 2` coefficients, the
verifier's own chain defines a consistency subspace of dimension
`N_s d_s + 1`, and the mask map is onto it with a one-dimensional kernel.

The proof of Fact 2.1 uses only: (i) `d_s + 1` values are published per round
(`zkp-core/src/sumcheck.rs:148-150`, ruling G-3's invariant), (ii) the field
has odd characteristic, (iii) `L_s = N_s d_s + 2`. **All three are shape-free.**
In the code, `L_s` is *defined* as `(main+ext)·deg + 2` at
`shape.rs:662-669`, from the very same `(main, ext, deg)` triple that sets the
number of published values per round (`shape.rs:603-641`, wire check
`wire.rs:120`). So when the support indicator raises a slot's degree by one
(`shape.rs:638`), **both sides of the identity move together, by construction,
at every shape.** Zero slack is therefore not a fact to be recomputed per
shape; it is a consequence of one line of the shape module.

[COUNTED, per-slot, `run_law_counts.py`]:

| | toy | rung-G | 125M |
|---|---:|---:|---:|
| free mask coefficients `Σ L_s` | 583 | **840** | **1,208** |
| consumed, `dim C = Σ (N_s d_s + 1)` | 560 | **817** | **1,185** |
| left over `= Σ dim ker R_s` | 23 | **23** | **23** |
| largest `L_s` (budget `L_s + 256 ≤ 512`, `zk.rs:493`) | 50 | **72** | **117** at `SC_SZC` |

The kernel dimension is exactly one per slot at every shape — 23 of 23 — which
is the identity restated. The budget is comfortable at both new shapes.
(`ZK60_JOINT_LAW_COMPOSITION.md` §6 item 4 says "the worst `L` is 94 at 125M";
that is the value **without** the indicator's degree rise on `SC_SZC`. The
figure is 117, and the layout memo §3.7a already has it right. **A stale
number in the composition memo, corrected here.**)

### 2.2 The pad-zero term. **Publishes no new field value; adds one challenge class per padded domain.** [VERIFIED IN THE CODE / COUNTED]

Ruling P-1 proves every hidden plane zero off its support by adding, to each
padded domain's hosting zero-check, one term
`mu_pad·(1 − supp(x))·Σ_j ζ^j·plane_{p_j}(x)` (`pad.rs:10-22`, built at
`argument.rs:660-716`, the formula written out at `:667`, hosts at
`pad.rs:347-359`).

What it publishes, item by item:

| | rung-G | 125M | why |
|---|---:|---:|---|
| new **claim sites** | 0 | 0 | every plane it combines is already a claim site in the hosting slot (`shape.rs:551-586` has no indicator entry) |
| new **committed rows** | 0 | 0 | same |
| new **terminals** | 0 | 0 | the indicator enters as a `Tab::Pub` (`argument.rs:565`, `:212`); only private tables carry mask rows |
| new **sumcheck rounds** | 0 | 0 | `Shape::slots` changes only the degree (`shape.rs:626-640`) |
| new **challenges** `ζ` (refused on zero) | **8** | **5** | `argument.rs:931, 998, 1124, 1199, 1252, 1310, 1385`; the zero refusal is `argument.rs:735-740` |
| new **challenges** `mu_pad` | 8 | 5 | one extra entry of the slot's existing `mu` vector (`argument.rs:929` etc.; `SC_LZC` draws a dedicated one at `:997`) |
| extra `Fp2` in round messages (the degree rise) | **105** | **126** | the eight `INDICATOR_SLOT_DOMAIN` slots (`shape.rs:65-66`) gain one degree when their domain pads — all **8** at rung-G, only **6** at 125M (`Dom::Kv` and `Dom::F` do not pad there) |

**Does the degrees-of-freedom identity still have zero slack?** Yes, and
§2.1 is the reason: the degree rise enters `L_s` and `dim C_s` through the
same `deg`. What the pad term *does* change is the challenge vector `ρ` — it
is longer by one `Fp2` per padded domain, both of them refused on zero — and
therefore the refusal inventory (§5). It changes no published field value
other than by lengthening six or eight round messages, and it puts nothing new
into the linear channel at all. [PROVED HERE for the identity; VERIFIED IN
THE CODE for the publication list; COUNTED for the numbers.]

**One thing to keep an eye on for a future shape.** `mu_pad` is one more
entry of the slot's `mu` vector, and `nu`/`mu` entries are refused on zero
(`argument.rs:735-740`), but `ζ`'s powers *continue across the groups of one
slot* (`argument.rs:688-703`). Nothing in the law depends on that; it is
recorded because a change there would move which public combination of
terminals the verifier forms, and (H4) is a statement about exactly that
combination.

### 2.3 Support indicators and exemptions by name. **Public tables; no publication; one new construction refusal.** [VERIFIED IN THE CODE]

The indicators are public 0/1 tables that both sides evaluate
(`pad.rs:48-54`, closed forms `pad.rs:156-193`; `supp_L` has **no** closed
form and falls back to the table, `pad.rs:157-159`). They publish nothing.
Their only effect on the law is through the degree rise of §2.2 and through
which relations are switched off on the pad.

The exemptions matter to the theorem in one way only: an exempted plane is a
*hidden* plane that is **not** proved zero off its support, so its pad entries
are real hidden values and must be blinded like any other. They are:

1. **`A_E`**, the exp-table plane (`layout.rs:228`), exempt at `pad.rs:299-301`
   because `exp[0] = 2^{F_E} ≠ 0` is a genuine table row;
2. **every LogUp helper plane** (`pad.rs:325`, reason `pad.rs:305-307`): a
   helper is `1/(α − v)` and is never zero — 48 planes at rung-G, 34 at 125M;
3. **`H_U`**, the zero-sum masking pair — no pad rule at all (`pad.rs:319-321`),
   which is right: it is blinding, not witness.

Tally [COUNTED, and equal to the lane's audited `pad_table_recount.json` at
125M]: rung-G 85 ZERO / 49 EXEMPT / 1 none; 125M 64 / 35 / 1.

**Why this does not disturb the theorem.** The theorem never asks whether a
plane is zero; it asks whether the *law of the published view* depends on the
plane's contents. An exempt plane is an ordinary data row of `A` or `H` and is
covered by the same per-commitment statement as every other data row. The pad
rule is a soundness device. [PROVED HERE — it is an immediate reading of
Lemma 4.1 of the composition memo, whose `D` is "the data rectangle", with no
sub-classification of rows.]

One new refusal does arrive with the indicators, and it is a *construction*
refusal on the public weights, not on the witness: a public weight nonzero off
its axis's support is refused by name (`private_block.rs:261-277`, messages
at `:244`, `:246`, ruling P-2). It is shape-only.

### 2.4 Grouped-query attention with padded head slots. **No change to the law's structure; a changed count and one new plane-geometry refusal.** [VERIFIED IN THE CODE]

The padded head axis is cut into one equal block of slots per key-value group,
so each group's padding falls at the end of **its own** block —
`{3, 7}` at rung-G and `{3, 7, 11, 15}` at 125M, never a contiguous tail
(`shape.rs:338-354`). The padded slots' planes are ZERO by the pad rule
(§2.2). Two shape refusals make the geometry well-formed
(`shape.rs:173-175`, `:184-186`).

For the law this is a relabelling of coordinates inside `Dom::Q`, `Dom::S`
and `Dom::Ht`: the domains grow, the number of rows per plane grows, the
number of claim sites in the head-bearing slots grows, and nothing about the
*form* of a published object changes. **Carries over with a changed count.**
The one thing it does change, and the gate confirms this is where its new
coverage is, is which slot closures the cross-channel identity (H4) has to be
re-read for: slots 8 (`SC_SCORE`) and 9 (`SC_PV`) now carry the key-value
factor at the query head's group bits, and the run gate recomputes exactly
those two among its twelve
[MEASURED, `ZK60_NATIVE_RUN_GATE.md` §6.2, rows 08 and 09].

### 2.5 The third `sigma_s` limb. **A changed count, nothing else.** [COUNTED]

`limbs_sigma_s = ceil(wrho_s / 8)` (`shape.rs:431-433`) is 2 at the toy and
**3** at both new shapes. Its cost, all on `Dom::S`: +2 `A` planes, +1 `H`
plane, +2 `A` claim sites and +1 `H` claim site, hence +3 terminals per block,
+4 `A` and +2 `H` blinding rows, and 2 more `U8` lookups per `Dom::S` position.
A *fifth norm* limb is refused by name (`witness.rs:429-433`). Nothing in the
theorem's structure notices; the counts of §1.2 already include it.

### 2.6 The generalised endpoint's five appended rows, and the SPARE. **A harmless extra uniform row; it adds slack, it does not change what must be full rank.** [PROVED HERE, given the per-commitment rank statement]

`endpoint_g::prepare` fills **all five** appended rows with fresh draws
(`endpoint_g.rs:227-235`: `for x in &mut data[first_mask*n..] { *x = rng.fp(); }`),
then declares `mask_rows = [data, data+1]` and `prox_mask_row = data+2`
(`:236-237`). Rows `data+3` and `data+4` are declared to nothing. Of those,
`data+3` **is load-bearing**: `check_opening_challenges` requires
`determinant(rho[prox], rho[prox+1]) ≠ 0` (`protocol.rs:276-278`, `:289-290`),
which is a condition on `data+3`. So **`data+4` is the only spare row**, as
`run_tests.rs:146-153` says in those words.

What role does the spare play in the law? An endpoint's opening has one group,
so its published linear view at one message position is `2(G+1) = 4` base-field
functionals of the appended rows, and there are **5** free rows. The spare:

* cannot lower the rank — adding a column to a matrix never does;
* receives a fresh proximity coefficient like every other row
  (`zk_rhos` draws a proximity rho over **every** row, `pcs.rs:835-856`), so it
  is not inert;
* raises the fibre dimension by exactly 1 per message position. The run gate
  measures precisely this: for the external endpoints, "non-data rows 5,
  generators 4, rank 4, positions without a solution 0, **free `Fp` per
  position 1**" [MEASURED, `ZK60_NATIVE_RUN_GATE.md` §2.5].

So: **a harmless extra uniform row, and a changed slack, not a changed
degrees-of-freedom requirement.** The requirement is still "the `2(G+1)`
generators must have full row rank on the reserved rows"; the endpoint meets
it with one dimension to spare, the boundary meets it with **none** (§3.4).

Two cautions that belong with it. (i) The two DOF statements in this project
must not be conflated: the *mask-channel* identity of §2.1 is exactly tight by
construction (`ker R_s = 1` per slot), while the *commitment-channel* rank is a
lower bound that slack only helps. (ii) The spare's harmlessness is a
statement about rank, and rank is the linear channel. It says nothing about
the opened columns beyond what `H-pad` already gives.

### 2.7 (H1) at a shaped layout — **GAP G-R1**, and it is the biggest one

(H1) is: at any non-refused `ρ`, the law of `V_pcs` — every group vector,
proximity vector, opened column and terminal of every PCS commitment — is the
same for every admissible hidden input. At the toy it is
`ZK60_JOINT_LAW_COMPOSITION.md` §4.3, MIXED: Lemma 4.1 + Proposition 4.2′ +
the accepted generic-rank lemma's core + the `Fp2::ZERO` value of the LogUp
identity + the independently-reviewed terminal-surjection step.

At rung-G and 125M, **the generic-rank lemma does not hold and has not been
restated**. Ruling G-2 is explicit: the lemma covers the two toy layouts, at
the new shapes its `H` step concerns a claim that cannot even be formed until
the P-3 repair, `A_GROUPS` moves, the endpoints are re-tiled, a new refusal
joins the inventory, and *"'re-check' understates it; the errata pass says
're-prove'"*. Nothing since has re-proved it.

What **does** carry, and should be said, because it is more than nothing:

* **Lemma 4.1** (disclosed dimension zero *is* witness-independence of a linear
  view) is shape-free. [REDUCED to `ZK60_JOINT_LAW_COMPOSITION.md` §4.1.]
* **Proposition 4.2′** (independent per-role blinding gives the product law) is
  shape-free. [REDUCED to `ZK60_JOINT_LAW_COMPOSITION.md` §4.2.]
* **The terminal-surjection Proposition** is shape-free: its proof is the
  annihilator form, exact for every group size `m` and every `cw ≠ 0`
  (`ZK60_TERMINAL_SURJECTION_REVIEW.md` §1.4), and its three conditions are
  enforced by code that runs at every profile — the pair weight shape
  `(cm, cm·U)` (`argument.rs:247-262`), pair exclusivity (`protocol.rs:261`,
  `:271`), and `cw ≠ 0` which is an unconditional public fact. [REDUCED.]
* **`H`'s deliberate shared-pair exception** (two groups sharing the zero-sum
  pair) is structural and is present at every shape, so the joint-over-connected-
  components treatment travels with it.
* What does **not** carry is the numerical part: the factorisation of the
  non-data block's maximal minor, the `k0 = 0` verdict, the pad-budget rank,
  and the certifying minors — all of it is "at these captures' challenges, at
  the toy layout".

At rung-G there is now *evidence* where there was none: the run gate computes,
on two independent honest three-block runs, `A` 0, `H` 2 (shown by span
equality to be the public LogUp identity), the external endpoints 0, each
boundary 0 restricted to its reserved rows, `M` exactly its batched value, every
certifying minor nonsingular, and 243–251 distinct opened columns inside the
256-pad budget [MEASURED, `ZK60_NATIVE_RUN_GATE.md` §2.3, §2.4]. That is
evidence at two challenge vectors at one shape, not a lemma.

> **GAP G-R1. (H1) is owed from the start at rung-G and at 125M.** The
> generic-rank lemma must be re-proved at each layout. The structural steps
> above transfer; the certificate does not.

### 2.8 (H3), (H4), (H5) at a shaped layout

**(H3)** — `M`'s opening depends on the mask coefficients only through the
single `Fp2` value `V(a)` — is Lemma 3.1, whose proof uses `M`'s geometry
(`MASK_LOG_MSG = 9`, `MASK_LOG_DOM = 12`, `MASK_Q = 256`, 50 rows) and
`M-cols`. **`M`'s geometry is shape-independent** (`zk.rs:373-375`;
`M_ROWS = 2·23 + 4 = 50` at every shape, `layout.rs:896`), the `L_s + 256 ≤ 512`
budget holds at both new shapes (§2.1), and the inventory of `mask_verify`'s
five checks (`zk.rs:552-590` at the toy line numbers) is a property of that
function, not of the block. **Carries over with the counts of §2.1.**
[REDUCED to `ZK60_JOINT_LAW_COMPOSITION.md` §3.1, conditional on the reader
re-confirming that the tagged `mask_commit`/`mask_verify` path added by stage 17
changed no check — the security owner's own reading of the shared-file change
says additions only (`ZK60_D19_HASH_TAG_DISPOSITION.md` §2b), which is a
statement about lines, not about this inventory.]

**(H4)** — `V(α) = V_pub(V_sc, V_pcs)`, a public function of the already
published view, and `V` factors through `R` — is Fact 3.2, and at the toy it
is VERIFIED IN THE CODE *by reading all 23 slot closures*. At a shaped layout
the closures are different functions: eight of them now carry a support
indicator, six or eight carry a pad-zero term, two carry the grouped-head
factor, one carries the third limb. **The reading is owed again.**

There is real new evidence, and it is worth stating precisely because it is
easy to over-read: the run gate recomputes the verifier's own final identity
`fin_s = c_s·mask_eval_s + poly_s(vals_s)` from the *published* terminals, for
**12 of the 23 slots**, in all three stages of two runs — **36 of 36 equal**,
and equal to the stored `terminal_polynomial`
[MEASURED, `ZK60_NATIVE_RUN_GATE.md` §6.2]. The twelve include both boundary
claim sites (slots 21 and 22), the pad-zero terms on `Dom::T` and `Dom::L`,
the support gates, the grouped-head slots and the third limb. The other
eleven are open only because the bundles were taken without the *values* of
the public weight, gain, RoPE and exp tables, which a re-capture closes with
no new arithmetic (ruling of the disposition §2b round 2).

Two things that check is **not**. It is the verifier's own consistency check
recomputed — a receipt agreeing with itself — and it is at two challenge
vectors. Fact 3.2 needs the identity to hold **identically**, for every witness
and every non-refused challenge, which is a statement about the *construction
premise* `argument.rs:18-22` ("every slot polynomial has a public factor in
every monomial, so `poly(extensions) = 0`"), not about runs that verified. The
check is strong evidence that the premise survived the growth; it is not the
reading.

> **GAP G-R2. (H4) is owed at both new shapes as a reading of all 23 closures,
> as the independent check supplied it for the toy.** Twelve of 23 are
> machine-confirmed at rung-G on two runs; eleven are not evaluated at all; no
> slot is confirmed at 125M. Condition O-1 of the toy check — a Rust test that
> evaluates each `def.poly` on a vector supported on that extension round's
> private tables and asserts zero — would close it at every shape at once and
> is still not written.

**(H5)** — `α`, `π`, `μ` mutually independent and `α` uniform — is the
uniform-blinding idealisation plus M-3. Unchanged in form at a shaped block;
§3.5 is where a run changes what it costs.

### 2.9 Theorem A, stated

> **Theorem A (one shaped block, fixed challenges).** Fix an admissible public
> statement of the rung-G or 125M profile and a challenge vector `ρ` with
> `NR(ρ)`. Assume (H1^G), (H2^G), (H3^G), (H4^G), (H5). Then for every
> admissible hidden input the joint law of the shaped block's published field
> values is the same, and it is given by the same explicit formula as Theorem
> 3.3 with `dim C` replaced by 817 (rung-G) or 1,185 (125M).
>
> **Status: the proof of Theorem 3.3 applies unchanged** — it never uses a
> shape constant, only (H1)–(H5) and the algebraic form of the view, which §1.2
> shows is unchanged. [REDUCED to `ZK60_JOINT_LAW_COMPOSITION.md` §3.3.]
> **Of the five hypotheses: (H2^G) is PROVED here (§2.1), (H3^G) is REDUCED
> (§2.8), (H5) is ASSUMED as before, and (H1^G) and (H4^G) are GAPS G-R1 and
> G-R2.** So Theorem A is, today, a conditional statement whose two hardest
> conditions are open.

---

## 3. The theorem for a RUN of L blocks

### 3.1 What is genuinely new

Three things, and only three.

1. **A boundary commitment `B_k` with two claim sites**, one reserved pair per
   site, opened exactly once, its row count **derived** as `data + 2·sites + 2`
   (`boundary.rs:180-182`; the declared count is checked against the derived
   one and refused by name otherwise, `boundary.rs:146-151`). Site 0 is block
   `k`'s slot 22, site 1 is block `k+1`'s slot 21
   (`boundary.rs:192-201`, run side `run.rs:229-244`, `layout.rs:1108-1120`).
2. **The same hidden plane under three commitments**: `A_k`'s `A_X2` rows,
   `B_k`, and `A_{k+1}`'s `A_X` rows.
3. **A single blinding of `B_k` shared by two claim sites raised in two
   different stages**, and therefore under two different masking commitments
   `M_k` and `M_{k+1}`.

Everything else about a run — the extra stages, the segmentation, the framing,
the streaming verifier — either repeats a block or is outside the field view.

### 3.2 The ideal-world object, and whether the all-zero input is admissible at every boundary

For the toy, the ideal-world program is "the honest prover on the all-zero
input" (ruling of `ZK60_PRIVACY_CASE_FIRST_MVP_DISPOSITION.md` §1, from D18).
For a run the analogue is **the honest prover on the all-zero run input,
chained**: the fixed input is chosen once, and every later block's input is
whatever the block map produces.

Two separate questions, and the memo must not merge them.

**(a) Does the field-view sampler need the all-zero chain to exist? No.**
Step 2 of `O1` puts literal zeros in the data rectangle of every commitment,
and that is legitimate because (H1) says the law does not depend on the data
rectangle *at all* — the composition memo makes this point explicitly at
§3.4 ("it does *not* need the witness builder to accept the all-zero input").
For a run, the same holds for the `L` rectangles and the `L−1` boundary
planes. [PROVED HERE, conditional on (H1^run).]

**(b) Does the whole-receipt ideal-world program need it? Yes, and it exists
at rung-G.** The lane's test
`the_all_zero_hidden_input_proves_and_verifies_as_a_run`
(`run_tests.rs:529-543`) proves and verifies a **two-block** all-zero run at
rung-G, and asserts the segment lengths are the counted ones — i.e. the
receipt length does not move with the hidden input (`run_tests.rs:541`). The
chain is built by running the block forward (`Chain::honest`,
`run_tests.rs:243-259`), so every boundary plane is whatever the block map
gives.

And here the block is **zero-preserving**: the single-block rung-G test
asserts both `A_X` and `A_X2` are all zero on the all-zero input
(`rung_tests.rs:184-192`, `:187-188`), and the toy's zero-witness test records
the two constants that keep it defined — `NORM_CEPS = 1` (`layout.rs:64`) and
the pinned `exp[0] = 2^{F_E}` (`zero_witness_tests.rs:111-128`). So **every
boundary plane of an all-zero run is all zero**, and the all-zero input is
admissible at every boundary, at rung-G. Three-block all-zero runs exist as
captures (`run_capture_tests.rs:601-619`, `run-d-zero`).

Three precisions a checker will want.

* Zero-preservation is a property of *these public weights*, not a theorem.
  With a bias term, or an activation table whose entry at zero is non-zero, the
  chain's later inputs would not be zero. The construction only needs
  *admissibility* at every stage, which the chained construction gives by
  definition; the all-zero-ness is a convenience.
* The block's *internal* state is not zero even on a zero input: the norm
  denominator is 1, the exp values are `2^{F_E}`, and the softmax row sums are
  non-zero. The zero witness sits **exactly on two range boundaries with zero
  headroom** (`zero_witness_tests.rs:136-145`).
* **No all-zero run has been proved at 125M.** [GAP G-R3, a small one: it is
  an engineering item, the same half-day the toy's was.]

### 3.3 The sampler, `O1^run`

The toy's `O1` (composition memo §3.4) extends stage by stage. Written out so
that the new step is visible:

```
O1_run(run statement, layout, L, rho):
  0. PUBLIC PREPARATION, as at the toy, per stage, plus: the run schedule
     (which commitment each stage commits and opens, and which reserved pair
     each IO tab uses), which is covered by the run's schedule digest.
  for k = 1..L:
     1. the stage's SUMCHECK CHANNEL: uniform on C^k (dimension 817 or 1,185)
     2. the stage's COMMITMENT CHANNEL: zeros in every data rectangle of
        A_k, H_k; fresh uniform entries in every non-data row; fresh uniform
        pads; read the terminals off.
        AND, for the boundary committed in this stage: zeros in its 4 (or 32)
        data rows, fresh uniform entries in its 2*sites + 2 = 6 reserved rows,
        fresh pads; ITS group vectors, proximity vector and columns are
        emitted in stage k+1, when it is opened, not here.
     3. the CROSS-CHANNEL VALUE V^k, computed from this stage's rounds and
        terminals in the declared functional order
     4. M_k's opening, sampled conditionally on V^k
  output the L stage views and the L-1 boundary openings and the 2 external
  endpoint openings.
```

The one structurally new line is in step 2: a boundary's blinding is drawn in
stage `k` and its *opening* is emitted in stage `k+1`. The sampler has to hold
it across the stage boundary — exactly as the prover does (`prev = cur`,
`run.rs:530`) and exactly as the verifier holds its pending claim
(`run.rs:555`). No new randomness, no new conditioning.

### 3.4 Degrees of freedom, per commitment and jointly

Per commitment, the hiding requirement in the linear channel is: at each
message position, the `2(G_r + 1)` base-field functionals the opening publishes
must be reachable from that commitment's own free (non-data) rows. Counting
generators against free rows [COUNTED]:

| commitment | groups `G` | generators `2(G+1)` | free non-data rows | slack |
|---|---:|---:|---:|---:|
| `A_k` | 36 | 74 | 246 | 172 |
| `H_k` | 9 | 20 | 102 (125M) / 106 (rung-G) + the zero-sum pair | large; discloses 2, the public LogUp identity |
| `M_k` | — | 2 | 50 rows, no data | discloses exactly its batched value |
| external endpoint | 1 | 4 | 5 | **1** (the spare, §2.6) |
| **internal boundary `B_k`** | **2** | **6** | **6** | **0 — exactly tight** |

**The boundary is the only commitment in the whole construction with zero
slack**, which is why ruling M-1's derived row count is load-bearing rather
than tidy: a single proximity row gives 5 of 6 and discloses one real
dimension, and `audit_claims` accepts that geometry
(`ZK60_PRIVATE_RUN_MULTI_BLOCK_CHECK.md` §A1.4; reproduced on real captured
runs as control C2, disclosed 1, `ZK60_NATIVE_RUN_GATE.md` §2.6). Two claims
sharing one pair gives 4 of 6 and discloses 2 (control C1), **with each
claim's own per-claim figure unchanged** — the marginal/joint trap, on this
object, measured.

**Jointly.** Here is the structure of the argument, and it is the memo's main
positive result.

> **Proposition R.1 (the run's product law).** Let the roles be
> `A_1..A_L, H_1..H_L, M_1..M_L, B_1..B_{L−1}, E_in, E_out` — `4L+1` in all,
> 49 at `L = 12`. Suppose (i) each role's published objects are a function of
> the run's shared data `d` (all `L` witnesses and all `L−1` boundary planes,
> with the shared coordinates identified) and of that role's **own** blinding
> `β_r`, and (ii) the `β_r` are mutually independent. Then
> `law(V_pcs | d) = ⊗_r law(φ_r(d, β_r))`, so the `4L+1` per-role
> data-free statements give the joint one directly.
>
> **PROVED HERE** — it is Proposition 4.2′ of `ZK60_JOINT_LAW_COMPOSITION.md`
> §4.2 with `4L+1` factors instead of four, and its proof is one line of
> independence. Hypothesis (i) is a reading of the code and holds: a
> boundary's published objects are built from its own `CommittedZk`
> (`boundary.rs:269-275`), a block's from its own (`protocol.rs:795-800`).

> **Corollary R.2 (three commitments over one plane).** An interior boundary
> plane sits in `A_k`, `B_k` and `A_{k+1}`. That is a **shared data
> coordinate**, not a shared blinding coordinate, and Proposition R.1 says a
> shared data coordinate cannot couple the roles. So the triple is the toy's
> two-commitment endpoint case applied once more — *not* a new argument.
> **PROVED HERE, conditional on Proposition R.1's hypothesis (ii).**
>
> The caveat that makes it non-trivial: **a rank deficiency in any ONE of the
> three leaks the same plane.** The product law says the joint is the product
> of three data-free laws only when all three factors are data-free. That is
> the content of the run design's omitted condition O-7 and ruling M-8, and
> the gate obeys it: it ranks all three roles as one system, 154 × 1,248,
> **joint 0 = sum of parts** on both boundaries of both runs
> [MEASURED, `ZK60_NATIVE_RUN_GATE.md` §2.4(b)].

> **Corollary R.3 (two claim sites on one commitment).** `B_k`'s two published
> claim values are the only quantities in the whole run that are functions of
> two blocks' witnesses at once. With disjoint reserved pairs they are the
> `m = 1` singleton-group case of the corrected terminal-surjection
> Proposition, applied twice, and the two groups' joint system has rank
> `6 of 6` on the reserved rows. **REDUCED to
> `ZK60_TERMINAL_SURJECTION_REVIEW.md` §1.4** (whose annihilator proof is exact
> for every `m` and every group count) **plus the derived row count.**
> Disjointness is enforced by `audit_claims`' `uses[r] == 1` check
> (`protocol.rs:271`) on both sides, and the row count by the module
> (`boundary.rs:146-151`) because the audit does not.

### 3.5 Where independence is used, and whether it holds — **the new finding**

Proposition R.1's hypothesis (ii) is the load-bearing one, and it is exactly
condition O-2 of the toy memo ("no blinding variable enters two commitments"),
which the toy settled *by reading* and which the terminal-surjection review
declined to re-verify.

**At the toy** (`ZK60_JOINT_LAW_COMPOSITION.md` §1.2, correction C-11):
`A`, `M` and `H` are three disjoint consecutive segments of **one** BLAKE3 XOF
stream, so their independence is **computational** under M-3; the two
endpoints are built from **their own** `ZkRng::from_os`, so theirs is
**information-theoretic**. Three streams, five commitments.

**In a run, read from the code:**

```rust
// ONE OS stream per run; an entropy failure aborts the run, at any stage,
// before anything of that stage is public.
let mut rng = ZkRng::from_os(st.rs.profile.as_bytes())…        // run.rs:434-436
```

and that same `rng` is handed to **every** boundary
(`boundary::prepare(&spec, …, &mut rng, &tag)`, `run.rs:465`) and to **every**
stage (`protocol::prove_core(…, &mut rng, …)`, `run.rs:483`).
`boundary.rs:306-314` states the choice and its reason in as many words:
*"`rng` is the caller's stream so that a run draws its `L − 1` boundaries from
the same OS-seeded generator the rest of the stage uses, and a failure to
obtain entropy aborts the run rather than one boundary."* Only the two
external endpoints keep their own (`endpoint_g.rs:224`). `ZkRng` is a
counter-based keyed BLAKE3 stream with no reseed and no per-commitment domain
separation (`zkp-core/src/rng.rs:44-61`).

> **Finding R-F1. The code and the accepted design differ, and the difference
> is privacy-relevant.** Ruling R-D4 of `ZK60_PRIVATE_RUN_MULTI_BLOCK.md` §8.1
> recommends *"one `ZkRng::from_os` per COMMITMENT … per block (its `A`/`H`/`M`,
> as now) and per boundary commitment (as `endpoint_g::prepare` already does)"*,
> and O-R2 gives the reason: it "makes cross-block independence rest on
> operating-system entropy rather than on stream separation inside one
> generator". **That was not implemented.** At `L = 12`, **47 of the 49
> commitments share one stream** and only the two external endpoints are
> information-theoretically separate — against 3 of 5 at the toy. The code's
> reason (a single fail-closed entropy point) is a good one and it buys a real
> liveness property (§5.4); it is a trade, not an oversight, and it is
> nowhere recorded as one.

What this does and does not cost:

* **It costs nothing in Theorem B**, which is stated in the uniform-blinding
  idealisation (H5) and is indifferent to how the blinding is generated.
* **It costs in the real-prover statement.** The reduction to the named
  generator assumption (ruling C-3: "the generator's whole output stream is
  indistinguishable from uniform", two-sided) now covers **109,728,040 field
  draws** plus 2,473,984 salt draws over one stream feeding 47 commitments
  [COUNTED, `run_law_counts.py`; the salt figure is the subagent inventory's
  and I did not recount it], against 327,052 draws over three streams at the
  toy. The *form* of the assumption is unchanged; the amount of the stream
  that must look uniform, and the number of objects that must look mutually
  independent, grow by two orders of magnitude.
* **The two-sidedness gets a longer reach.** Ruling C-3 needed M-3 two-sided
  because `A`'s 256 published salts are drawn before `H`'s secret pads on one
  stream. In a run, **stage 1's whole segment — including its salts and every
  opened column — is written out and released before stage 12's mask rows are
  drawn from the same stream** (`run.rs:529`, `run_sink.rs:181-202`, eleven
  stage boundaries later).
* **It does not make the assumption adaptive.** The run is non-interactive:
  nothing anyone does between segments changes a later draw, because the
  stream is fixed at `from_os` and every challenge is a Fiat–Shamir squeeze.
  The assumption needed remains non-adaptive whole-stream indistinguishability.
  **This would change** if a future driver ever reseeded from anything a
  consumer could influence; a one-line note for the conditions list.
* **The compile-time premise survives.** "No draw count depends on a witness
  value", so the assignment of stream positions to commitments is a
  compile-time fact: each stage draws exactly
  `(rows−data)·n + rows·Q` per PCS commitment plus `2·ΣL_s + 46·256 + 4·1024`
  for `M` [COUNTED], all shape constants. The check confirmed "no
  data-dependent number of draws" for a block; for a run it follows term by
  term.

> **GAP G-R4. Cross-role blinding independence for `4L+1` roles is still an
> unproved hypothesis, now carried by one stream, and it is still not
> machine-asserted** (condition O-2 of the toy memo, unclosed; O-R2 of the run
> design, unclosed). The one thing that would close it cheaply — a
> stream-segment accounting test asserting that no two commitments' blinding
> ranges overlap — remains unwritten, and at run scale it is worth more than it
> was at block scale.

### 3.6 Is dropping block `k` before block `k+1` privacy-relevant, or only memory?

**Only memory, with one exception.** The drops are explicit and are justified
as peak-RSS measures in the code's own words (`protocol.rs:706-727`: the
difference between an 11.0 GiB and a 9.6 GiB modelled peak; `run.rs:411-422`
and ruling M-3: eleven unflushed segments are 423 MiB). The witness goes at
`protocol.rs:723`, `A` at `:797`, `H` at `:801`, `M` at `:791`, the segment at
`run.rs:526`.

None of that changes the law of the published view: the law is a function of
what is published and of the blinding's distribution, not of how long the
prover keeps a buffer. [PROVED HERE — trivially, from the definition of the
view.]

The exception is not a drop but a **consume**: `PreparedBoundary::into_opening`
takes `self` (`boundary.rs:269`), `PreparedBoundary` has no `Clone`
(`boundary.rs:232-241`), and `Endpoints` is taken by value and consumed on
success *and* on failure (`run.rs:423`, `:431`, `protocol.rs:460-461`). That
is what makes "opened exactly once" a type error rather than a convention, and
it is a condition of the accepted toy statement (§5 item 4 of
`ZK60_PRIVACY_STATEMENT_TOY_PROFILE.md`). It is discipline, not memory.

Two honest riders. (i) The honest prover must know all `L` boundary planes to
commit them, so the most sensitive material in the process is held for the
whole run (`ZK60_PRIVATE_RUN_MULTI_BLOCK.md` §3 failure mode 4, ~12 MB at
125M). Memory contents are outside the model (D20), but the operating rules of
D21 bite here. (ii) The drops interact with the single stream of §3.5 only in
that they do **not** reset it.

### 3.7 Theorem B, stated

> **Theorem B (a run of `L` shaped blocks, fixed challenges).** Fix an
> admissible run statement and a challenge vector `ρ` with `NR(ρ)`. Assume,
> for each stage `k = 1..L`, hypotheses (H2^G), (H3^G), (H4^G) of Theorem A;
> assume (H5^run): the `L` mask-coefficient families `α_k`, the whole PCS
> blinding `π` (all `4L+1` roles' mask rows, zero-sum rows and pads) and the
> `L` masking-commitment families `μ_k` are mutually independent and each `α_k`
> is uniform; and assume (H1^run): the law of `V_pcs`, the PCS channel of all
> `4L+1` commitments jointly, does not depend on the run's hidden data. Then
> for every admissible hidden run input the joint law of **every field value
> the run's receipt publishes** is the same, and it is
>
> ```
> Pr[V = (t, v, m) | w]
>   = [ Π_k 1[t'_k ∈ C^k] · |Fp2|^{-dim C} · Φ(m_k ; V_pub^k(t_k, v)) ] · P_pcs(v)
> ```
>
> with `t'_k` stage `k`'s messages in the claimed-sum coordinates and `P_pcs`
> the witness-free law of (H1^run).
>
> *Proof.* Condition on `π` and sum over `α = (α_1..α_L)`. Because block `k`'s
> slots are masked by `M_k`'s coefficients only, `F_sc^k(w, α_k, π)` does not
> involve `α_j` for `j ≠ k`, and because `V_M^k` is a function of `(α_k, μ_k)`
> only, the sum factorises over `k`. Each factor is then exactly the inner sum
> of Theorem 3.3's proof: (H2^G) makes the fibre count `|Fp2|^{23}` whenever
> `t'_k − T'_k(w,π) ∈ C^k` and zero otherwise, (H4^G) makes `V(α_k)` constant on
> each fibre with the public value `V_pub^k(t_k, v)`, and (H3^G) gives the last
> factor. What is left is `P_pcs(v)`, `w`-free by (H1^run). ∎
>
> **PROVED HERE**, i.e. the run adds no new step to the proof of Theorem 3.3
> beyond the factorisation over stages, which is (H5^run). **On hypotheses:
> (H2^G) PROVED (§2.1); (H3^G) REDUCED (§2.8); (H5^run) ASSUMED, and §3.5 says
> what it now costs; (H4^G) is GAP G-R2; (H1^run) reduces by Proposition R.1 to
> the `4L+1` per-commitment statements, of which the boundary's is REDUCED
> (Corollary R.3) and `A_k`'s and `H_k`'s are GAP G-R1.**

Three remarks, because they are where a reader will look for a hole.

* **The sumcheck channel does not factor by stage before conditioning on `π`.**
  Correction C-12 of the toy memo says `V_sc` is not a product across roles,
  because one extension round mixes reserved-pair evaluations from several
  commitments inside one slot. In a run, stage `k`'s slot 22 reads `B_k`'s
  site-0 pair and stage `k+1`'s slot 21 reads `B_k`'s **site-1** pair — two
  different stages touching one commitment, at two *different* coordinates of
  `π`. The proof above conditions on the whole of `π` first, exactly as the toy
  does, so this is handled; it is **not** handled by any argument that tries to
  factor the run stage by stage without that conditioning.
* **Nothing conditions on the witness anywhere**, which is the sentence the
  whole construction exists to support.
* **The real prover.** Every "equal" above is exact only in the idealisation
  (H5^run). Against the real prover the two laws are within the sampler
  residual of §6, and beyond that indistinguishable only up to the advantage
  against the named generator — which §3.5 says is now doing twelve times the
  work.

### 3.8 What the gate's "joint = sum" corresponds to, and what it cannot test

The run gate (`/home/victor/wt-zk60-jointview/docs/zkmatrix-poc/ZK60_NATIVE_RUN_GATE.md`,
tool `scripts/zk60_native_run_gate.py`) reports, on two independent honest
three-block runs at rung-G:

| gate figure | what it is in this memo's terms |
|---|---|
| per commitment, `disclosed = dim_Fp(F ∩ T) = 0` (`A`, both endpoints, both boundaries) or `2` (`H`, the public LogUp identity) | the **per-role** statement of (H1^run) for that role, at that run's challenges — i.e. Lemma 4.1's criterion, computed |
| each boundary, **restricted to its reserved rows**, rank 6 of 6, disclosed 0 | the zero-slack DOF statement of §3.4 for `B_k`, computed. Over **all** rows the rank is also 6, which is why the restriction is the whole content |
| the three roles of one boundary plane, 154 × 1,248, **joint 0 = sum of parts** | **Corollary R.2**, computed rather than assumed — and the gate computes *both* premises: that the non-data block is block-diagonal by role (no blinding source shared) and that each part is 0 |
| the whole run, 308 × 3,761, **joint 6 = sum 6** | **Proposition R.1** for the linear channel, computed: three copies of `H`'s public identity and nothing else |
| six controls firing: shared pair → disclosed 2; single proximity row → 1; a blinding row shared between the boundary and an adjacent commitment → marginals 0 but **joint 1,024** | the negative side. The third is the sharpest: it is exactly the failure of Proposition R.1's hypothesis (ii), and it shows the joint statement is not vacuous |

**What "joint = sum" means there.** The gate builds one generator system over
all the run's commitments with shared coordinates identified, and computes the
rank of the whole against the sum of the per-role ranks. Equality is a
*theorem* when the non-data block is block diagonal by role and every part is
zero — and the gate says so, and computes both premises rather than asserting
them (`ZK60_NATIVE_RUN_GATE.md` §2.4(b)). In this memo's terms, "joint = sum"
is **the linear-channel instance of Proposition R.1**, verified at two
challenge vectors.

**Which of this memo's hypotheses it tests.**

* (H1^run), restricted to the **linear channel** — group vectors, proximity
  vectors, opened columns, claim values — at rung-G, at two challenge vectors.
* The zero-slack requirement on the boundary, and both of its named failure
  modes.
* Corollary R.2 and Corollary R.3, at rung-G.
* (H4^G), for **12 of 23 slots**, as the verifier's own consistency identity
  (§2.8) — which is a check on the receipt, not on disclosure.

**What it cannot test, and must not be read as testing.**

* **The sumcheck channel `V_sc`.** It is nonlinear in the data and outside
  the gate's affine model by construction. The gate's channel table lists "the
  masked sumcheck rounds" and "any nonlinear functional" as OPEN.
* **The cross-channel link itself** — that `V(α)` is a public function of the
  view. The per-slot terminal identity is the verifier's arithmetic, not a
  disclosure statement.
* **Independence (Proposition R.1's hypothesis (ii)).** The gate's "no blinding
  source is shared" is a statement about *coordinate classes in its model*:
  distinct blinding rows are distinct free unknowns. That is precisely the
  uniform-blinding idealisation restricted to the linear channel. Real
  independence is O-R2/G-R4, and §3.5 shows it is now weaker than it was.
* **All challenges.** Two runs are two challenge vectors, not a distribution;
  turning that into a statement about all but a negligible set of challenges is
  what the generic-rank lemma does, and it is owed at this shape (G-R1).
* **The 125M shape.** Nothing numerical transfers; ruling G-2 and D17/R-3 say
  so, and the project has been burned once already by a gate result quoted
  across shapes.
* **The hash layer.** Argued, not computed (§4.3).

---

## 4. Adaptivity across stages

### 4.1 What the fixed-challenge theorem must deliver

The lift is the **sequential-kernel lemma** (`ZK60_MVP_JOINT_VIEW.md` §1.2,
branch `zk60-mvp-fable`; privacy-case item 17): if each message `m_j` depends
only on the witness, the prover's randomness and `r_{<j}`, each `r_j` is any
function of the public prefix, **and for every fixed challenge vector the
joint law of `(m_0 … m_n)` is the same for `w` and `w′`**, then for every
challenge function the law of the whole view is the same.

So the fixed-challenge theorem for a run must deliver exactly this and nothing
less:

1. **the JOINT law over the whole message sequence**, not per stage and not
   per channel. Theorem B delivers it for the field half. The joint hypothesis
   is the point; a per-stage statement would be the marginal trap one level up,
   and the project already has the counterexample at the claim level
   (two terminals sharing one pair: marginals unchanged, joint moves).
2. **at every non-refused `ρ`**, including the position tags (see below).
3. **for the message sequence as it actually is**, i.e. including the roots.
   `m_0` for a run is `B_1`'s root, not `A_1`'s (`run.rs:459-466` precedes
   `protocol.rs:666`) — a small ordering change with no consequence beyond
   getting the hybrid's indices right.

### 4.2 Does a run change anything about the lift?

| item | at the toy | in a run | consequence |
|---|---|---|---|
| number of messages / rounds | one stage | `L` stages; at rung-G `L = 3` the gate re-derives **6,086 challenges** at **375 transcript positions** [MEASURED] | the hybrid is `L` times longer. The lemma is stated for any `n`; nothing breaks, the bad-event union of §4.3 grows linearly |
| extra roots in the message sequence | 3 | `3L + (L−1)` absorbed + 2 in the statement | `L−1` more hash objects the field theorem does not cover |
| the position tags | none | `2L` of them, squeezed from a **discarded clone** (`run.rs:365-372`) | they are **challenges, not messages**: they advance no state, are compared and never adopted (`wire.rs:374-375`, ruling M-6/U-3). They join `ρ`, and at fixed `ρ` they are constants. [PROVED HERE: I read `Transcript::clone_state` at this tip — `zkp-core/src/transcript.rs:156-162` copies the 32-byte state, the counter and the profile **key** and nothing else, and the key is public (D19a, ruling T-7). Note the design memo's citation `transcript.rs:133-142` is **stale at `caa9b9a`**; stage 17 moved the function] |
| the segment framing | none | 120 B per segment, **outside** the Fiat–Shamir chain (`wire.rs:255-262`) | it is published but is a deterministic function of the transcript state, hence of the published prefix. It adds nothing to the law. [PROVED HERE] |
| the verifier computing the pending claim | n/a | it recomputes it (`run.rs:578-581`) | **it removes a message rather than adding one.** No claim structure and no claim value beyond the published terminals is on the wire (§1.4) |
| the run's own separation | n/a | the run's profile domain string is absorbed first, under the transcript key (D19a) | a run's challenge chain cannot coincide with a single-block proof's |

**Nothing in that list changes the form of the lifting argument.** What it
changes is the size of the object and the length of the bad-event union.

### 4.3 The hand-over to the hash layer, stated exactly

This memo covers field values. What it hands over is:

> **(H6^run), what the hash layer owes.** In the model of D19 as amended by
> D19a — BLAKE3 read as a *family* of independent random functions indexed by
> mode and key, the four keyed functions of the run's shape (transcript,
> column digest, salted leaf, Merkle node) being four of them — for every
> admissible hidden run input and every non-refused `ρ`, the conditional law of
> **(the `3L` block roots, the `L−1` boundary roots, the two external roots,
> the `5L + (L−1)` × 256 authentication paths, and the `2L` position tags)
> given the field view and the published salts** is the same fixed,
> witness-free function of (the opened column values, the published salts, and
> one independent uniform 32-byte value per never-opened leaf), except with
> probability at most a stated query-budget term.

Four precisions that are this memo's, not the toy's.

1. **The `L−1` boundary roots are new hash objects, and they are *not* part of
   the statement.** `run.rs:90-94` says so deliberately ("an internal boundary
   is a hidden intermediate, not an endpoint"), and the run statement file
   omits them (`run_statement_file.rs:326-344`). But they **are** on the wire
   (`wire.rs:271`, `:388-390`). So a boundary root is an *observed commitment*
   and belongs inside (H6^run) exactly like `A_k`'s root — which is how the
   gate labels it (ARGUED).
2. **The position tags are hash-layer objects even though they are squeezes.**
   They are `challenge_fp2_vec(2)` from a discarded clone rendered as 32 bytes
   (`run.rs:365-372`). At fixed `ρ` they are determined; in the lift they are
   oracle outputs on inputs the adversary already has.
3. **A run uses its SHAPE's keys, not a run-specific key set** (ruling of
   `ZK60_D19_HASH_TAG_DISPOSITION.md` §2b, register D19a). So a standalone
   125M block and a 125M block inside a run hash their columns, leaves and
   nodes under the *same* three keys; only the transcript is separated, by the
   run's own domain string. For hiding this is harmless — the trees are over
   different data with fresh salts — but it is a fact (H6^run) must state
   rather than assume away.
4. **The untagged 2^-241.42 domain-overlap term does not apply to a run**,
   because a tagged profile's node, leaf, column and transcript functions are
   different functions in D19a's model. What replaces it is the model
   assumption itself. This is a *simplification* relative to the toy and
   should not be quietly banked as a strengthening: it moves a counted term
   into an idealisation.

> **GAP G-R5. (H6^run) is not written, and the composition of Theorem B with
> it into ONE sequential argument is not written.** This is condition O-4 of
> the toy check, unclosed at the toy and now owed over `L` times the steps. The
> per-step kernel argument must be over messages that are **pairs** (field
> part, hash part), which is the form the check asked for and nobody has
> produced. Until it is written, Theorem B + (H6^run) is prose, not a proof.

---

## 5. Refusals in a run

### 5.1 The classes, counted

The toy's inventory is eighteen classes (`ZK60_PRIVACY_CASE_FIRST_MVP.md`
item 24, from the independent check). It lives in the docs; **there is no
refusal enum in the code**, and `private_block/refusals.rs` is a *test* module
about the witness builder's sites only.

**A shaped block adds these, over the toy** [VERIFIED IN THE CODE]:

| new class | site | kind |
|---|---|---|
| the pad-zero batching challenge `ζ` refused on zero | `argument.rs:735-740`, drawn at `:931, 998, 1124, 1199, 1252, 1310, 1385` — **8 slots at rung-G, 5 hosting slots at 125M** | **challenge-only** |
| a support indicator that does not tile its cube | `argument.rs:723-731`, message `:584-585` — a release-build refusal, not an assumption | shape |
| `Dom::Tab` pad-zero group mismatch (two messages) | `argument.rs:597`, `:600` | shape |
| a `Dom::T` / `Dom::Ht` plane outside its pad-zero group | `argument.rs:970`, `:1350` | shape |
| a public weight nonzero off its support (head slot, or width index) | `private_block.rs:261-277`, `:244`, `:246` | shape, construction-time |
| the grouped-head geometry refusals | `shape.rs:173-175`, `:184-186` | shape |
| the plane-list refusals that the third limb makes live | `layout.rs:316-318`, `:354-355`, `:357-358`, `:503-504`; a fifth norm limb refused by name `witness.rs:429-433` | shape |
| the generalised endpoint's own family (spec, NTT, length, its own entropy) | `endpoint_g.rs:105-134`, `:194-210`, `:219-239` | shape / environment |

**A run adds, per internal boundary, 28 distinct refusal sites** — the
`BoundarySpec` constructor's eleven (`boundary.rs:122-157`, including ruling
M-1's derived-row-count refusal at `:146-151`), `prepare`'s five
(`boundary.rs:288-319`, `run.rs:462-463`), and the single opening's twelve
(the seven `audit_claims` messages `protocol.rs:233, 242, 246, 256, 261, 264,
271`; the column-weight and group-count checks `:205`, `:302`; the prepared
context check `boundary.rs:270-271`; and the two challenge refusals). **Exactly
two of the 28 are challenge-only**: a zero group-member coefficient
(`protocol.rs:285`, two draws) and a vanishing proximity determinant
(`protocol.rs:289-290`). All 26 others are deterministic functions of the run
statement and fire identically at every boundary or not at all.

**A run also removes one class's multiplicity.** O-R4 of the run design warns
that *"a run makes 49 `ZkRng::from_os` calls (23 more than a block), and
`from_os` fails closed … at run scale that refusal can now happen in stage 12,
six minutes in."* **Against the code that is wrong in a good direction.**
`prove_run` makes **one** `from_os` call, at `run.rs:436`, before the stage
loop and before anything is public; the only others are the two external
endpoint preparations, which the *caller* makes before the run
(`endpoint_g.rs:224`). Three OS reads per run, all of them before stage 1.
An entropy failure cannot happen six minutes in.

### 5.2 Which are challenge-only, and the liveness union for `L = 12` at 125M

**A correction that matters more than it looks.** "About 2^-62 per class" is
not the shape of the figure. 2^-62 is `δ_deg`, the **whole per-proof**
degeneracy-refusal probability, and it is `4/p` — four base-field
**proximity-determinant** draws, one per PCS opening
(`ZK60_HASH_LAYER_AND_FS_LIFT_DISPOSITION.md` ruling L-4;
`ZK60_FABLE_TRANSCRIPT_REVIEW.md:427-438`). Every other challenge-only class
refuses on a zero `Fp2` value and is `O(2^-128)`, negligible beside it.

So the run's challenge-only liveness cost scales with the number of **PCS
openings**, which is `2L` (an `A` and an `H` per stage) `+ (L+1)` IO openings
(the external input, the `L−1` boundaries, the external output) `= 3L + 1`.
The masking commitment's opening has no determinant check.

| | openings | challenge-only liveness | [COUNTED] |
|---|---:|---|---|
| one toy block | 4 | `4/p` | **2^-62.00** — agrees with ruling L-4 |
| one shaped block | 4 | `4/p` | 2^-62.00 |
| a run, `L = 3` | 10 | `10/p` | **2^-60.68** |
| a run, `L = 12` | 37 | `37/p` | **2^-58.79** |

(`ZK60_PRIVATE_RUN_MULTI_BLOCK.md` §5.1 O-R4 gives `12 × 2^-62 ≈ 2^-58.4`,
which is the right order by a slightly different route — it scales per block
rather than per opening. 2^-58.79 is the counted figure.)

### 5.3 The one input-dependent class — **a number that changes**

The one refusal inside the proof that depends on a witness value is the **zero
LogUp denominator** (`protocol.rs:403`, denominators built at `:691`,
`:701-704`, `:734`). Its probability is (number of inverted denominators) over
`|Fp2| = 2^128`, and **it moves with the shape**:

| | inverted denominators | per block | run `L = 3` | run `L = 12` |
|---|---:|---|---|---|
| toy | 64,768 | **2^-112.02** | 2^-110.43 | 2^-108.43 |
| rung-G | 439,296 | **2^-109.26** | 2^-107.67 | 2^-105.67 |
| **125M** | **103,890,944** | **2^-101.37** | 2^-99.78 | **2^-97.78** |

[COUNTED, `run_law_counts.py`; the denominator counts are the lane's own,
`grow_tests.rs:282-284`, `:299-302`, `:337-340`, plus three table-helper rows
of `size(Dom::Tab)` — 256 at the toy, `2^log_cols` after the P-3 lift.]

> **Finding R-F2. 2^-112 is a toy figure and must not be carried.** The run
> design's O-R4 writes `12 × 2^-112 ≈ 2^-108.4` for a twelve-block run; at the
> 125M shape the correct figure is about **2^-97.8**, ten and a half bits
> worse. The cross-check that it is right: 103,890,944 / 2^128 = 2^-101.37 per
> block, which is *exactly* the dominant LogUp soundness term the layout memo
> already quotes (`ZK60_PRIVATE_BLOCK_125M_LAYOUT.md:510`, "`N/|F_p²| =
> 2^-101.37` at 103.8M lookups"). The same count drives both. Any run
> statement must carry 2^-97.8, not 2^-108.4.

Two riders. (i) Counting *distinct* denominator values would give a better
bound, as the toy write-up notes; nobody has done that count at 125M. (ii) The
run adds one bit of structure the block did not have: **which stage** refused
is itself observable, and conditioned on a refusal that identifies a block.
This does not change the additive term (the event has the probability above),
but a statement should say the refusal channel for a run carries `log2 L` bits
*given* the event, not one bit.

### 5.4 Terminality, and what happens to already-written segments

**A refusal is terminal for the whole run, and the code makes it so four
times over** [VERIFIED IN THE CODE]:

* `prove_run` returns on the first `Err`; there is no retry loop, no counter,
  no redraw anywhere in `run.rs:448-533`;
* the external endpoint owners are taken **by value** and consumed on success
  *and on failure* (`run.rs:423`, `:431`; `protocol.rs:460-461`), and
  `Endpoints` has no `Clone` (`private_block.rs:683-716`, with a compile-fail
  doctest);
* `PreparedBoundary` has no `Clone` and `into_opening` consumes `self`
  (`boundary.rs:232-241`, `:269`);
* one OS stream, drawn once (`run.rs:436`).

So a second attempt needs freshly committed endpoints, hence new roots, hence
a **different public statement** — not the same run.

**What happens to the segments already written.** They stay. The sink is
handed each finished segment exactly once, by value (`run.rs:529`), and
`DirSink::accept` writes to `<name>.partial`, `sync_all`s and **renames**
(`run_sink.rs:181-202`), so *"a file under a segment's own name either is the
whole segment or does not exist"* (`run_sink.rs:176-180`). A refusal at stage
`k` therefore leaves segments `0..k−1` on disk as complete, fsynced files, and
nothing deletes them. Three things bound what that means:

1. **The directory cannot be reused.** `DirSink::create` refuses a non-empty
   directory (`run_sink.rs:147-159`), and `accept` refuses an existing final
   path (`:191-193`).
2. **A partial directory does not verify.** `segment_paths` names the first
   missing file and refuses before a byte is read (`run_sink.rs:104-108`), and
   the run's closing check refuses an undischarged boundary claim
   (`run.rs:742-749`). A verifier that stops after segment `k` knows nothing
   about the run (omitted condition O6 of the design).
3. **Ruling D21 is implemented as "the statement is the evidence".** The
   public run statement is written beside the segments only after the whole
   run verified in this process (`run_statement_file.rs:155-175`, the
   `verify_run_from_dir` call at `:165` preceding the write at `:167-173`;
   sink-side rule `run_sink.rs:65-71`). The test
   `a_failed_run_leaves_no_statement_file` (`run_tests.rs:1213-1241`) pins it.

**Described, not fixed.** The live question a privacy statement for a run must
answer, and this memo does not: **a half-run's segments are real published-shaped
bytes of a run that refused.** D21 says a receipt the prover's own final check
rejected is never transmitted; the analogue for a run is "a partial run's
segments are never transmitted either", and the code's *storage* discipline
(atomic, non-reusable directory, no statement) supports that rule without
stating it. If those files are ever shipped or retained as a capture, D21's
"a retained bundle counts as publishing" applies to them, and they contain
stages `1..k−1` of a run whose refusal at stage `k` is — with probability up
to the figure of §5.3 — input-dependent.

> **GAP G-R6. A run's operating rule for partial segment directories is not
> written.** It is a D21-shaped ruling, not an argument, and it is the security
> owner's.

---

## 6. Residuals, sized

### 6.1 The sampler's reduction bias (decision D9)

D9 counts **every** mask and pad the prover draws, each within `2^-96` of
uniform; salts are raw bytes and contribute nothing. Per hiding commitment the
draw count is `(rows − data_rows)·n + rows·Q`
(`pcs.rs:673`, `endpoint_g.rs:227-235`, `boundary.rs:320-328`), plus
`2·Σ L_s + 46·256 + 4·1024` for the masking commitment (`zk.rs:434-457`), plus
`2(n−1)` for `H`'s zero-sum pair (`protocol.rs:763`).

[COUNTED, `run_law_counts.py`. The method reproduces the toy's published
327,052 draws and 2^-77.7 exactly, term by term, before counting anything
new.]

| | per block | per boundary | per external endpoint | run `L = 3` | run `L = 12` |
|---|---:|---:|---:|---|---|
| rung-G | 686,990 | 8,704 | 7,424 | 2,093,226 → **2^-75.0** | 8,354,472 → **2^-73.0** |
| 125M | **9,029,742** | 108,032 | 91,392 | 27,488,074 → **2^-71.3** | **109,728,040 → 2^-69.3** |

> **Finding R-F3 (a number that does not move).**
> `ZK60_PRIVATE_RUN_MULTI_BLOCK_DISPOSITION.md` §1 confirms "109.4 million
> draws, 2^-69.3 for one twelve-block run". Counted from the code's own
> formulas the figure is **109,728,040** — 0.33 % higher. **The residual is
> 2^-69.3 under both**, so nothing quoted anywhere changes; the count is
> corrected for the record. (My count and an independent inventory of the same
> code agree on 9,029,742 per block and 109,728,040 per run, and the same
> model reproduces the 125M and rung-G receipt byte totals exactly.)

The term is a **distance**: it adds across blocks and across runs with no
cancellation. A million twelve-block runs is 2^-49.3. It vanishes entirely if
`ZkRng::fp` ever moves to rejection sampling — one line plus a re-freeze, which
D9 records as available and not scheduled, and which at run scale is a better
bargain than it was at block scale.

### 6.2 Everything else, and which side of the ledger it is on

| term | toy (D22) | a run at 125M, `L = 12` | kind |
|---|---|---|---|
| sampler bias (D9) | 2^-77.7 | **2^-69.3** [COUNTED] | distance |
| the one input-dependent refusal (zero LogUp denominator) | 2^-112.0 | **2^-97.8** [COUNTED, §5.3] | distance |
| challenge-only refusals | 2^-62.0 | **2^-58.8** [COUNTED, §5.2] | **liveness, not distance** |
| the generator | the named assumption (ruling C-3) | the same assumption, over one stream feeding **47 of 49** commitments and 109.7 M draws [§3.5] | assumption |
| guessing an unopened leaf's salt; oracle collisions; challenge pre-query | `q·2^-242.4`; 2^-229.8 / 2^-233.1 / 2^-241.4; `q·2^-244.0` | **owed again** under (H6^run); the untagged-overlap term is replaced by D19a's model [§4.3] | distance / assumption |
| the generic-rank fallback, if a structural step is rejected | ≈ 2^-56 over the base field | **not derivable** — the lemma does not exist at these shapes (G-R1) | — |
| soundness of the run | — | ≈ 2^-97.5 (ruling M-2; **not** a privacy term, and its acceptance is the project owner's, pending) | out of scope here |

Two of those are worse at the run than at the toy by enough to be stated in
any run statement rather than inherited: the sampler at 2^-69.3, and the
input-dependent refusal at 2^-97.8.

---

## 7. The table of every step, and what to attack first

### 7.1 Every step

| # | step | label | where |
|---|---|---|---|
| 1 | The inventory of what a run's receipt publishes, in transcript order, split into field values and hash objects | **VERIFIED IN THE CODE** | §1.2; `run.rs:448-533`, `protocol.rs:666-800`, `wire.rs:269-284`, `:376-413` |
| 2 | Every challenge follows what it must bind, for a run | **VERIFIED IN THE CODE**, and cross-checked by the gate's 6,086-challenge replay | §1.3 |
| 3 | No claim structure or value beyond the published terminals is on the wire; the verifier recomputes the pending claim | **VERIFIED IN THE CODE** | §1.4; `run.rs:578-581`, `:622-631`, `wire.rs:286-289` |
| 4 | Shape counts: rows, sites, groups, slot table, `dim C`, `Σ L_s`, terminals, draws, published field words | **COUNTED** (`run_law_counts.py`; reproduces the toy's 560 / 721 / 173 / 327,052 / 2^-77.7, the 125M `L=117`, rung-G's 377 data rows and 176 terminals, and both receipt byte totals) | §1.1, §1.2, §2.1, §6.1 |
| 5 | (H2) the mask DOF identity, zero slack, at every shape and every degree | **PROVED HERE** (Fact 2.1's proof is shape-free; `L_s` and `dim C_s` move together by `shape.rs:662-669`) | §2.1 |
| 6 | The pad-zero term publishes no claim site, row, plane, terminal or round | **VERIFIED IN THE CODE** | §2.2 |
| 7 | The pad-zero term does not disturb the DOF identity | **PROVED HERE** (a corollary of step 5) | §2.2 |
| 8 | Support indicators are public; exempt planes are ordinary data rows for the law | **PROVED HERE** (a reading of Lemma 4.1) | §2.3 |
| 9 | Grouped heads and the third limb change counts only | **VERIFIED IN THE CODE / COUNTED** | §2.4, §2.5 |
| 10 | The generalised endpoint's spare row is a harmless extra uniform row, adding slack 1 and changing no requirement | **PROVED HERE**, given the per-commitment rank statement; **MEASURED** by the gate (free `Fp` per position = 1) | §2.6 |
| 11 | (H3) `M` publishes exactly one `Fp2` functional of the mask coefficients | **REDUCED** to `ZK60_JOINT_LAW_COMPOSITION.md` §3.1 (`M`'s geometry is shape-free) | §2.8 |
| 12 | (H1) per commitment, at a shaped layout | **GAP G-R1** — the generic-rank lemma is owed from the start (ruling G-2). Evidence at rung-G from the gate, at two challenge vectors | §2.7 |
| 13 | (H4) the cross-channel identity at a shaped layout | **GAP G-R2** — the 23 closures must be re-read; 12 of 23 machine-confirmed at rung-G on two runs, 0 of 23 at 125M | §2.8 |
| 14 | Theorem A, one shaped block | **PROVED HERE, conditional** on 12 and 13 | §2.9 |
| 15 | The ideal-world object for a run; the sampler does not need the all-zero chain | **PROVED HERE** (conditional on (H1^run)) | §3.2(a) |
| 16 | The all-zero run proves and verifies at rung-G, `L = 2`; the block is zero-preserving | **MEASURED by the lane** (`run_tests.rs:529-543`, `rung_tests.rs:184-192`) | §3.2(b) |
| 17 | No all-zero run at 125M | **GAP G-R3** (engineering) | §3.2 |
| 18 | Proposition R.1, the run's product law over `4L+1` roles | **PROVED HERE** (Proposition 4.2′ with more factors) | §3.4 |
| 19 | Corollary R.2, three commitments over one plane | **PROVED HERE**, conditional on R.1(ii); **MEASURED** by the gate (joint 0 = sum) | §3.4 |
| 20 | Corollary R.3, two claim sites on one commitment | **REDUCED** to `ZK60_TERMINAL_SURJECTION_REVIEW.md` §1.4 + the derived row count | §3.4 |
| 21 | The boundary is the only zero-slack commitment; both failure geometries disclose | **COUNTED** + **MEASURED** (gate controls C1, C2) | §3.4 |
| 22 | Cross-role blinding independence, `4L+1` roles on ONE stream | **GAP G-R4**, and **Finding R-F1**: the code and ruling R-D4 differ | §3.5 |
| 23 | Dropping block `k` is memory, not privacy; the consume is the discipline | **PROVED HERE** (trivially) + **VERIFIED IN THE CODE** | §3.6 |
| 24 | Theorem B, a run | **PROVED HERE, conditional** on 12, 13, 22 and (H5^run) | §3.7 |
| 25 | What "joint = sum" tests and cannot test | **ARGUED**, against the gate's own text | §3.8 |
| 26 | The position tags and the segment framing add nothing to the field law | **PROVED HERE** | §4.2 |
| 27 | The lift: what Theorem B must deliver, and that a run changes only the size | **ARGUED** | §4.1, §4.2 |
| 28 | (H6^run) and the composition into one sequential argument | **GAP G-R5** (= condition O-4, unclosed at the toy, now `L` times bigger) | §4.3 |
| 29 | Refusal classes: the shaped block's additions, 28 sites per boundary, 2 of them challenge-only | **VERIFIED IN THE CODE** | §5.1 |
| 30 | Only **one** `from_os` call per run, before stage 1 | **VERIFIED IN THE CODE** — corrects O-R4's "49 calls … six minutes in" | §5.1 |
| 31 | Challenge-only liveness `= (3L+1)/p`: 2^-60.68 at `L=3`, **2^-58.79** at `L=12` | **COUNTED** | §5.2 |
| 32 | The input-dependent refusal is shape-dependent: **2^-97.8** for a twelve-block 125M run, not 2^-108.4 | **COUNTED** (**Finding R-F2**), cross-checked against the layout memo's own 2^-101.37 | §5.3 |
| 33 | A refusal is terminal for the whole run; already-written segments stay on disk, complete, in a directory that cannot be reused, with no statement file | **VERIFIED IN THE CODE** | §5.4 |
| 34 | The operating rule for a partial segment directory | **GAP G-R6** (a ruling, not an argument) | §5.4 |
| 35 | The sampler residual for a run: 109,728,040 draws, **2^-69.3** | **COUNTED** (**Finding R-F3**: 0.33 % above the quoted 109.4 M, same residual) | §6.1 |
| 36 | A per-boundary declared scale is a public word of the statement | **GAP G-R7** — see below | §7.3 |

**The gaps, by name:** **G-R1** (H1) at a shaped layout — the generic-rank
lemma owed from the start; **G-R2** (H4) — the 23 closures owed as a reading at
both new shapes; **G-R3** no all-zero run at 125M; **G-R4** cross-role blinding
independence over `4L+1` roles on one stream, unproved and not machine-asserted;
**G-R5** (H6^run) and the one-argument composition (condition O-4); **G-R6** the
operating rule for a partial segment directory; **G-R7** the per-boundary
declared scale (§7.3).

### 7.2 What the checker should attack first

Ranked by my own estimate of where this memo is weakest.

1. **G-R4 and Finding R-F1 — the single stream.** I claim it costs nothing in
   Theorem B and everything in the real-prover statement. Attack the second
   half: is "the generator's whole output stream is indistinguishable from
   uniform, two-sided" really enough when 47 commitments' blinding is
   consecutive segments of one stream and the *earlier* segments' images are
   published before the later segments are drawn? I say the run's
   non-interactivity makes the assumption non-adaptive; check that, and check
   whether anything in `prove_run` could be influenced between stages (I found
   nothing, but I did not read `prove_core` line by line).
2. **The claim that Theorem B "adds no new step".** The factorisation over
   stages is the whole proof. I condition on `π` and then claim
   `F_sc^k(w, α_k, π)` involves no `α_j`, `j ≠ k`. That is a reading of the
   masking structure (each stage has its own `M_k` and its own `c_s`), not a
   theorem. If any slot of stage `k` were ever masked by a coefficient
   committed in another stage — a run-wide `M`, which §2.4 of the design memo
   rejected for exactly this reason — the factorisation fails. Verify the
   rejection is enforced, not merely recommended.
3. **G-R2, and my reading of what the gate's 12-of-23 buys.** I treat the
   verifier's own recomputed identity as evidence for (H4) but not as (H4). A
   checker might reasonably argue it is *less* than I say (it is a receipt
   agreeing with itself at two challenge vectors) or *more* (the construction
   premise is structural, and 12 slots covering every new mechanism is close to
   a reading). I have argued the first; the second is arguable.
4. **§2.6, the spare row.** I say it cannot lower the rank and therefore is
   harmless. That is true of the *rank*. It is committed, so it appears in
   every opened column and in the proximity vector, and my argument that this
   is covered by `H-pad` is one sentence. The terminal-surjection review's own
   control — one opened position beyond the pad budget discloses 2 `Fp` the
   message-half reduction misses — is the shape of the objection.
5. **§3.4's slack table.** I assert the hiding requirement is "the `2(G+1)`
   generators must be reachable from the non-data rows, per message position".
   That is the checker's model from `boundary_rank.py` and the gate's, and it
   is a *model*, not the full view. Slack on `A` (172 spare rows) is doing no
   work in my argument, but a reader could wrongly conclude from the table that
   `A` is "safer" than the boundary. It is not; it is differently constrained.
6. **§5.3's denominator count at 125M.** It is transcribed from
   `grow_tests.rs:337-340` plus three table rows at the lifted `Dom::Tab` size.
   If the lift's table rows are not three, or if a domain's lookups were
   recounted, the figure moves. The corroboration is that it lands exactly on
   the layout memo's independently derived 2^-101.37.
7. **§4.2's claim that the segment framing and the position tags add
   nothing.** I argue the transcript state is a hash of published bytes only,
   and I did read `clone_state` at this tip (`transcript.rs:156-162`: state,
   counter, key, nothing else; it asserts no masker is installed). The
   remaining objection is not about the clone but about `squeeze_bytes`: a
   position tag is an oracle output on an input the adversary already has, so
   in the ROM it is a *fresh uniform value determined by the prefix* rather
   than a constant, and my "at fixed `ρ` it is a constant" is a statement
   inside the fixed-challenge world only. Check that the lift treats it that
   way.
8. **The counts.** Every number carries a script and the script reproduces six
   published figures first, but three of its inputs are second-hand: `H`'s
   50-vs-52 planes at 125M, `h_data_rows = 7,018`, and the per-shape lookup
   denominators. All three came from a delegated read of `shape.rs` and
   `grow_tests.rs`, corroborated by the receipt totals reproducing to the byte.

### 7.3 One gap this memo found that no earlier document names

**G-R7. A boundary's declared scale is a public word, and nothing says it is a
function of the public statement alone.** Each internal boundary declares one
`i32` scale, shared by construction between block `k`'s output and block
`k+1`'s input (`run.rs:100-103`, `:120-129`; `boundary.rs:80-85`). It is
published (`run_statement_file.rs:331`), it is inside the boundary's statement
digest (`boundary.rs:210-229`), and — a precision worth recording — that digest
is **never absorbed into the run transcript**: the header absorbs only
`run-shape`, `expected-IO`, `public-statement`, `parameters`, `calibration`,
`schedule` (`run.rs:271-281`), and neither the parameter line nor a stage line
mentions an interior scale. The two *external* scales are bound, through
`expected-IO`.

The correctness consequence is O-R8/D12 item 5, already open. The **privacy**
consequence is new and is not in any document I read: a declared scale is a
statement about the dynamic range of a hidden intermediate. Today the scales
are constants of the statement (0 in every test), which is fine. But if a
deployment ever chose boundary scales by calibrating on the actual input — the
obvious thing to do for accuracy — **the scale would be a published function of
the hidden activations**, and no theorem here would cover it. Any privacy
statement for a run needs a condition in §5's style: *the declared scales are
a function of the approved calibration and the public statement, never of the
input.* Recorded, not fixed.

---

## 8. What this is not

* **Not a privacy acceptance, and not a claim about privacy at all.** D22
  covers one artifact — the toy block — and bars the development rung, the 125M
  block and every multi-block run by name. Nothing here narrows that.
* **Nothing about the hash layer beyond §4.3's hand-over.** The roots, the
  salts, the paths and the position tags are not field values, and this memo
  contains no rank, sampler or simulator for them. (H6^run) is a statement of
  what is owed, not a lemma.
* **Nothing about timing, memory or power** — out of scope by D20. The memory
  schedule appears in §3.6 only to say it is not a privacy fact.
* **Soundness is untouched.** The run's ≈ 2^-97.5 (ruling M-2) is quoted once,
  as a figure that is not a privacy term and whose acceptance is the project
  owner's, pending.
* **Weight privacy is untouched** — these profiles have no `W` commitment;
  P3 is a different problem.
* **D8 and D11 are untouched.** The run's two external endpoints are sealed by
  the prover under D18; sealing in advance by a third party is a different
  configuration and remains bound by D8 and D11.
* **Nothing was built, run or measured by this drafter.** Every [MEASURED] is
  the lane's or the gate's, attributed at the figure. Every [COUNTED] is exact
  integer arithmetic in `results/zk60_joint_law_composition_run/`, whose method
  reproduces six already-published figures before it computes anything new.
* **The two theorems are conditional.** Theorem A rests on two open
  hypotheses, Theorem B on those two plus one more. A conditional theorem whose
  conditions are open is a plan, not a result.
