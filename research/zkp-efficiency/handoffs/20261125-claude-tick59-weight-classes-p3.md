# Research handoff: which weight classes beyond the block matrices a P3 profile must commit (2026-11-25, claude tick 59)

From Claude, the background researcher (D50). Queue item 93 (added by tick 54). Clock at writing 2026-11-25T11:54Z.

**Scope.** Local reading and arithmetic only: 0 searches, 0 fetches. No build, run or Git. Written: this file and `20261125-claude-tick59-weight-classes-p3.py` / `.out.txt`. Read (tree that runs, `ops/zkp-mvp/gpu-metal/hashline/src/private_block/`): `trained_statement.rs:84-168, 207-250, 383-417, 631-690`; `token_io.rs:352, 423-432, 625-640, 728-760`; `token_io/classify.rs:839-846, 569-607`; `token_io/classify_tied.rs:360-430`; `shape.rs:1036-1050`; `slot_ir.rs:1167-1168`; `argument.rs:3377-3378`; `tables_attn.rs:132-156`; `accuracy_tables.rs:39-50`; `grow_tests.rs:770-805`; tick 54's handoff and script. **Triage material, not a work order:** committing any further class changes what the proof commits, so it needs the owner's ruling, a new profile and re-proving in Lean (D63); P3 stays at study level (D82). Labels: COUNTED (file:line), MEASURED, DERIVED (script), ASSUMED.

## 0. Headline

- **Pass.** The 8B profile's learned tensors are fully accounted for: block matrices 6,979,321,856 + norm gains 262,144 + embedding 525,336,576 + head 525,336,576 + the final norm's 4,096 gains = **8,030,261,248, exactly the checkpoint's `checkpoint_parameters`** (`trained_statement.rs:143`; DERIVED, difference 0). So no hidden weight class is missing from the list below at 8B.
- **Embedding and head are the only large classes left, 1.05 G words (13.1% of 8.03 G).** At tick 54's best row (n = 2^16, rate 1/4, k = 16, Q' = 172, one group) each costs **8,016 rows and 13.32 MB** to open once per request: **26.6 MB together, +12.1% on the block part (219.9 MB) and +3.3% of today's 818.7 MB receipt.** Total P3 add: **246.5 MB (x1.30)** against tick 54's 219.9 MB (x1.27).
- **Fail line for "has a committed form": none of the classes has one in the prover.** The block matrices have only the FA4 design and a slot journal (tick 54). The embedding and head exist as BLAKE3 digests of the whole table (`emb_digest`, `head_digest`, `token_io.rs:641`) plus an O(V d) fold done by both sides (`emb_fold`, `head_fold`, `token_io.rs:710-760`); the norm gains are public periodic tables (`argument.rs:3377`). All reduce to a flat word vector at one claimed point, so the row layout of tick 54 applies unchanged; what is new is the claim shape (section 3).

## 1. The list (8B first, Shieldstral beside it)

| class | words, 8B | words, W16R2 Shieldstral | rows at n = 2^16 | public by construction? |
|---|---:|---:|---:|---|
| block matrices Wq, Wk, Wv, Wo, Wg, Wu, Wd, true size | 218,103,808 x 32 = 6,979,321,856 | 116,391,936 x 26 = 3,026,190,336 | 3,328 / 1,776 a block | no: learned (tick 54) |
| same, padded to d_pad x f_pad | 243,269,632 a block | 243,269,632 a block | 3,712 a block | padding is zero; see below |
| norm gains gamma_a, gamma_m (int8) | 2 x 4,096 = 8,192 a block; 262,144 | 2 x 3,072 = 6,144 a block; 159,744 | 0.12 a block (1 extra row) | no: learned, today a public table |
| embedding (int16, V x d) | 128,256 x 4,096 = 525,336,576 (V_pad 2^17: 536,870,912) | 131,072 x 3,072 = 402,653,184 | 8,016 (8,192) / 6,144 | no: learned |
| head W' (int8, V x d) | 525,336,576 | none (tied; the classifier reads one margin row) | 8,016 | no: learned |
| head multipliers m_j, in [1, 2^12] | 128,256 | none | 1.96 (2) | no: per-row quantisation scale |
| classifier margin vector w_Delta (int16) | none | 3,072 | 0.05 (1) | no: yes-minus-no head rows |
| final norm | 4 scalars (g0, cn, tn, ceps), one uniform gain | same | 0 | scalars of the statement: public |
| calibration constants | 27 numeric scalars + 2 f64 (unit, RoPE base), up to 11 own overrides a layer (352) | same, 286 | 0 | public: in the statement the verifier is handed |
| RoPE cos, sin | 2 x 128 x 64 = 16,384 words, one set for every layer | same | 0 | public: generator of a public base |
| exp table, SiLU table | 256 + 4,096 words a layer (139,264) | same | 0 | public: generator members, bound by `table_sha256` |

COUNTED: every word count from the struct that holds it (`classify.rs:839`, `token_io.rs:625`, `trained_statement.rs:207-231, 383-417`) and `shape.rs:1036-1037` (`d_pad`, `f_pad` are next powers of two). The 8B closure to the checkpoint count is the check on the table. Shieldstral: text tower 3,429,006,336 words against the checkpoint's 3,849,090,048 (`trained_statement.rs:163`); the remaining **420,083,712** words are the image tower the comment names ("only the 26 text layers are proved, D38 (a)"). Under P3 the model identity (`weights_sha256`, whole file) covers a tower no proof touches; whether that tower must be committed is the owner's question, not a count.

**Padding matters more than tick 54 assumed.** The statement hashes the nine PADDED word vectors (`trained_statement.rs:388`), and the proof folds over padded widths (`shape.rs:1036-1050`, `grow_tests.rs:770-805`). Tick 54's 218.1 M is the true size, which equals the padded size only in the width. At 8B hidden 14,336 pads to 16,384, so a padded commitment is 243.3 M words (3,712 rows, x1.115). At Shieldstral width 3,072 pads to 4,096 and hidden 9,216 to 16,384, so the padded block is 243.3 M against 116.4 M true (x2.09). A P3 commitment of true words needs the claim's index map to skip pad columns inside each row; pad columns are not whole rows. Not read: how the verifier's claim point would address a dense layout. Both columns are priced below.

## 2. Added receipt bytes at tick 54's best row (DERIVED, script section 2, wire formula `wire.rs:106-108`)

| item | rows | MB |
|---|---:|---:|
| 8B blocks, one opening each, 32 blocks (tick 54) | 3,328 | 219.9 |
| 8B gains as one extra row a block | +1 | +0.04 |
| 8B embedding, one opening a request | 8,016 | 13.32 (vectors 2.19, columns 11.03) |
| 8B head W', one opening a request | 8,016 | 13.32 |
| 8B head multipliers as their own opening | 2 | 2.29 (vectors dominate) |
| **8B total, blocks + gains + embedding + head** | | **246.5 = x1.30** |
| Shieldstral blocks, true words, 26 | 1,776 | 123.1 (x1.18 of 669.6) |
| Shieldstral blocks, padded words, 26 | 3,712 | 192.4 (x1.29) |
| Shieldstral embedding | 6,144 | 10.75 |
| Shieldstral margin vector, as one extra row of the embedding's commitment | +1 | +0.001 |
| **Shieldstral total (true blocks + embedding)** | | **133.9 = x1.20** (embedding 8.0% of it) |

After B6a the clear vectors go and columns remain: embedding + head 22.3 MB against the block part's 146.5 MB (+15%). A multiplier opening alone is mostly vector bytes, so fold `m_j` into the head rows if the ranges allow (section 3). Stored encoded size at rate 1/4: embedding and head 33.6 GB on top of the blocks' 223.3 GB (+15%).

## 3. What each class needs that the blocks do not

- **Embedding and head are one claim each per request, not 32.** Stage IN folds the table at an eq point (`emb_fold`), stage OUT folds the head (`head_fold`, `Wf[i] = sum_j w[j] m_j W'[j][i]`). The verifier's O(V d) folds disappear and an opening takes their place.
- **The head is a committed-times-committed product.** The multiplier `m_j` scales each row inside the fold, so a hidden `m_j` needs either a second small commitment and a product claim, or the product `m_j W'_j` committed instead (words up to 2^19, not int8; the range statement and the `head-words=[-127,127]` class in `token_io.rs:584` change). Not read in code beyond the fold; T-C3 below.
- **Gains** have no committed claim today: the verifier builds the periodic table itself (`argument.rs:3377-3378`). Two claims a block (one per norm) at one point each; 8,192 words a block fit in one extra row of that block's commitment, so there is no new opening, only two more weight claims in the block's group (tick 54's T-P3c merge question applies).
- **Ranges.** Every word needs a range proof once per model: int8 for blocks and head, int16 for the embedding, [1, 2^12] for the multipliers. Scaling tick 53's tree bound by words (ASSUMED linear): blocks 3.3 to 4.6 s (tick 54), embedding and head +0.5 to +0.7 s, **3.8 to 5.2 s** in total.
- **Prover time.** The row combination for both tables, G = 1: 4.2 G base multiplications a request, **14 to 93 ms (0.4 to 2.5% of the 3.7455 s cadence)** at 300 to 45 G/s (tick 41's sparse-fold rate); small beside the block part's 0.09 to 2.5 s (tick 54).

## 4. Falsifiable tests (none run)

- **T-C1 (bytes).** `open_zk` wire length at 1/64 scale (125 rows at n = 2^16, rate 1/4, G = 1). Pass: within 1% of the table. Kill: more than 3% off, then the formula misses a term.
- **T-C2 (padding).** Does the claim index map let a dense true-words commitment answer a claim at a padded-domain point (pad columns skipped)? Reading of `fold_rows_i8` and the weight claim sites. Fail: padded commitments only, so Shieldstral's blocks are 192 MB, not 123 MB, and the 8B blocks 245 MB, not 220 MB.
- **T-C3 (head).** Read stage OUT's relation (`token_io/` `head_fold` caller) for whether `m_j` enters as a public multiplier only. Pass: a hidden `m_j` can fold into W' rows with a 19-bit range class; fail: a second commitment, +2.3 MB.

## 5. Effect

Committed words a request: **+1.05 G (+15% of 6.98 G) at 8B**, +0.40 G (+13%) at Shieldstral; gains +262 k (+0.004%). Proved tokens per second: the opening bytes and the row combination are after the stream's per-block clock; the embedding and head combination is at most 0.4 to 2.5% of the cadence at full pass-through, probably less (tick 22 rule a). Nothing here is a speed lever; it is the size of the P3 bill.

## 6. Risks and what was not verified

- The 818.7 MB (8B) and 669.6 MB (classifier) receipts: not read whether they already include stage IN and OUT bytes; the +3.3% and +8.0% shares are against those totals as given.
- The final norm's real checkpoint gains (4,096) are replaced by one uniform `g0`; where the per-channel gain went (folded into the head or the last block) was not read, and a hidden gain needs the same fold target.
- Embedding as a hidden table is selected by a private token: the lookup claim's point is secret, which the opening grammar must allow (FA4-style masked point); not read.

## 7. Status

Proofs / passes / positions: 0 / 0 / 0. Complete private 8B at the target: unachieved. Hypotheses: H168 (the P3 add at 8B is x1.30, of which embedding and head are 12% of the block part; padded commitments would raise Shieldstral's to x1.29 for the blocks alone; T-C1 to T-C3).
