# CL10 — where the proof bytes actually are, before any redesign

Task: `zk60_claude_tasks.json` CL10 (`ready_analysis`). Owner: Claude.
Tool: `scripts/hashline_cl_artifact_profile.py` · tests:
`tests/test_hashline_cl_artifact_profile.py` (9, green).
Nothing in Codex's receipt/codec modules was touched.

**Sizes are sizes.** Nothing below says a smaller alternative is compatible,
hiding, or sound. Every candidate in §4 carries the gate it would have to pass
first, and one of them is already disqualified for the private tier.

---

## 1. The measurement

One Mistral FFN layer, `d 4096 / f 14336`, T=512, `inv_rate` 4, 256 column
checks, encoded columns 65,536 (Merkle path 16). Committed rows are the ones
the binary prints in its own mask-site dump: **W 10,774 / A 3,601 / H 3,033**.
Artifact sizes are the published, measured ones (lane AM rung 2, CL1 rung 4).

| component | P1 bytes | share | P3 bytes | share |
|---|---:|---:|---:|---:|
| **opened column DATA** (field elements) | 35,651,584 | **88.7%** | 35,651,584 | **88.6%** |
| opened column framing (index, salt, path) | 423,936 | 1.1% | 423,936 | 1.1% |
| commitment headers + mask root | 164 | 0.000% | 164 | 0.000% |
| residual: sumcheck arguments, claims, terms | 4,110,544 | 10.2% | 4,176,176 | 10.4% |
| **observed artifact** | **40,186,228** | 100% | **40,251,860** | 100% |

Both reconcile **exactly**: derived + residual = observed, by construction. The
residual's internal split is not claimed — it is measured by subtraction and
labelled as such.

### The cross-check that makes this credible

The published P1 → P3 delta is **+65,632 B**. The opened-column term is
mode-independent (same rows, same 256 columns, same paths), so the entire delta
must land in the residual. It does, to the byte:
`4,176,176 − 4,110,544 = 65,632`. A test pins this, because if the model were
wrong about what the columns contain, that identity would drift.

**Conclusion: ~89% of a proof is opened column field elements.** Framing is
1.1%. Headers are three parts in a million.

---

## 2. What this means for "make the proof smaller"

The proof is not carrying overhead worth trimming. It is carrying **opened
column data**, which is the Ligero-style argument itself. Concretely, the data
term is exactly

```
columns_opened  ×  committed_rows  ×  8 bytes
```

with `columns_opened = 256` fixed by the soundness parameter and
`committed_rows` fixed by the layout. Neither is framing, and neither can be
compressed away without changing what is proved or how strongly.

---

## 3. Byte-preserving improvements, ranked — and the ranking is short

"Byte-preserving" here means: the verifier accepts the same statement with the
same soundness, and the frozen digests do not move.

| # | candidate | ceiling | verdict |
|---|---|---:|---|
| 1 | per-column `u64` index → `u32` (65,536 encoded columns needs 16 bits) | 4 B × 256 × 3 = **3,072 B/layer**, 0.008% | real but negligible; **moves every digest**, so it is not byte-preserving in the frozen-artifact sense at all |
| 2 | deduplicate Merkle paths across the three commitments | 0 — the three trees are distinct, paths are not shared | not available |
| 3 | drop the per-column salt (32 B × 256 × 3 = 24,576 B, 0.06%) | 0.06% | **NO**: the salts are the hiding construction. Removing them is a privacy change, not a serialization one |
| 4 | compress the residual arguments (10.4%) with a general-purpose codec | unknown, likely small — these are field elements, i.e. near-uniform bytes | must be measured before it is claimed; near-uniform data does not compress |

**Honest total for byte-preserving work: under 0.1%, and the only candidate
that reaches even that moves the frozen digests.** There is no serialization
win here. Anyone hoping to shrink these artifacts must change the protocol,
which is §4.

---

## 4. Protocol-changing candidates, each with the gate it must pass

These are **costed, not recommended**. None may be called compatible, private
or sound on the strength of a size number.

**(a) Open fewer columns.** The data term is linear in `columns_opened`, so
this is the only lever with real leverage inside the current PCS. It trades
directly against soundness: 256 checks is the current parameter.
**Gate: an explicit soundness re-derivation and a review ruling on the target
security level.** Not a serialization change.

**(b) The compact (BaseFold-class) PCS, already measured by lane AF.** A
Mistral layer's proof **38.7 → 1.94 MB (19.9x)** at 4.4x prover; 8B modelled
`1.23 GB → ~62 MB` [COUNTED]. That is the only order-of-magnitude candidate on
the table, and it is **currently disqualified for the private tier on three
independent counts**:
- **Soundness is LOWER**: 2^-98.2 / 2^-95.1 against Ligero's 2^-106, and it is
  a *field-size* term, so it is **not fixable by adding queries**. A ruling is
  pending and has not been made.
- **It is not hiding**: `--pcs compact --zk` is refused by the code today. So
  it cannot serve P1 or P3 as things stand.
- **It is not device-resident** (slower on GPU), which cuts against everything
  CL1 just established about getting the private tier onto the device.
**Gate: its own codec gates, a soundness ruling, and a hiding construction that
does not exist yet.** Until all three, it is a fast-tier-only, ruling-pending
option and must not be quoted as a proof-size roadmap for the private product.

**(c) Pack field elements below 8 bytes.** Goldilocks elements are ~64 bits and
the opened columns are masked, so they are near-uniform over the field. There
is no headroom. **Gate: none needed — this one is simply not available**, and
recording that is more useful than leaving it as an open idea.

---

## 5. Transfer and allocation assumptions, stated separately

CL10 asks that disk/network assumptions not be folded into the byte count:
- The measured artifact is what `--proof-out` writes: the **concatenated layer
  proofs, flat LE**, with no container, no compression and no framing beyond
  the per-layer structure above.
- A 32-layer 8B proof is ~1.23 GB by the same arithmetic. Any statement about
  transferring that is a deployment question, not a proof-size one, and none is
  made here.
- Output-buffer allocation: `to_bytes` reserves `size_bytes()` up front, so the
  serialization is a single allocation of the final size, not a growing buffer.
  Serialization time was measured at 0.03-0.07 s and runs **outside** the prove
  clock (round-14 correction). It is not a bottleneck and should not be
  presented as one.

---

## 6. Handoff to Codex's codec/CLI owners

- The tool profiles a **declared** layout against a **measured** artifact size.
  It refuses unknown or underspecified layouts, and refuses any model whose
  derived components exceed the observed artifact — that condition means the
  model has drifted from `zk.rs` and every number would be fiction.
- To add a layout: read its serializer, declare its commitments' rows/columns/
  path lengths in `KNOWN_LAYOUTS`, and add its measured artifact size to the
  tests. Do not infer a layout from a file.
- **The actionable finding for a codec owner is that there is nothing for a
  codec to do.** 89% of the artifact is argument data. The lever is §4(a) or a
  different PCS with its own gates, not encoding.
- If a per-component dump is ever wanted from the Rust side rather than derived
  here, `LayerProofZk::size_bytes` already has the exact structure and a
  `debug_assert_eq!` tying it to `to_bytes`; exposing it would need a change in
  `zk.rs`, which is **read-only to this lane** and is therefore proposed, not
  made.
