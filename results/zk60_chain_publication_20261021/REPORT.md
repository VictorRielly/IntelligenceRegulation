# Publishing the media app's proofs on a cheap blockchain: feasibility (D39 item 2)

Lane: chain publication feasibility, 2026-10-21 UTC. Research and costing only.
No prover code was touched, no wallet was created, nothing was spent and no
transaction was sent. Prices are live reads taken 2026-10-21 02:40–03:10 UTC
(`prices_20261021.json`); the arithmetic is reproducible with `python3 costs.py`.
The lane could not write this file itself, so the coordinating session saved its
text verbatim.

Labels: **[V]** VERIFIED (source and date given), **[D]** DERIVED (arithmetic on
[V] inputs), **[E]** ESTIMATE (reasoned, not measured), **[UNV]** reported by a
secondary source and not re-checked.

## Summary in plain words

1. **It is feasible and cheap to *anchor*:** a small record (proof fingerprint, verdict, model, policy, salted content commitment) costs **under $0.001 per post** on Base, and far less when many posts share one transaction.
2. **The proof itself cannot go on a chain.** A 0.5 GB receipt would fill about 130 Ethereum blocks. The chain holds the fingerprint; the receipt lives in a storage network.
3. **Storing the receipt is the real cost.** Paid, renewable storage (Filecoin plus a Cloudflare R2 mirror) costs about **$0.12 per text post per year** (about $1,200/year per 10k posts). Permanent pay-once storage on Arweave costs about **$26 per text post** (about $257k per 10k posts).
4. **MVP recommendation:** receipts on Filecoin + R2, kept deletable. Small records and the model files go permanently on Arweave. A Merkle root of each batch is anchored on Base, with an optional daily checkpoint on Ethereum. **Anyone can re-check a post** with the public model files and our verifier (10–96 s on a CPU).
5. **On-chain verification is possible only through a zkVM wrapper.** Today that costs roughly 6–18 GPU-hours and **$2–18 per post**, so it is not an MVP feature. A verifier redesigned for recursion could bring it under about $1 per post and would shrink the public proof to about 800 bytes.
6. **Privacy:** only the verdict, the model and policy identity, and a **salted** commitment go public, never the content. The app keeps the salt and gives it to viewers. Deleting the salt makes the public record unlinkable, which is the GDPR answer.
7. **Don't publish receipts permanently** until the Shieldstral profile has its own privacy acceptance. A permanent receipt can never be withdrawn if a flaw turns up later.
8. **Rulings needed from Victor:** (a) how long full receipts are kept: renewable at about $0.12 per post per year, or permanent at about $26 per post; (b) Base as the anchor chain.

## 1. What we would publish

| Item | Size | Public? | Source |
|---|---|---|---|
| Receipt (proof bytes) | 0.25–0.93 GB measured; Shieldstral text **~0.3–0.7 GB** [E], image **~1–2 GB** [E] | yes (needed to re-verify) | MVP_STATUS: TinyLlama T32 251 MB, 8B T32 466 MB in 32 segments, 8B T128 928 MB [V, local] |
| Statement | a few KB of JSON | yes | brief |
| Verdict, model id, policy id, statement hash, content commitment | ~200 B | yes, on-chain | D38(c) |
| Model files (integer export) | ~3.9 GB for Shieldstral (3.85 B params, int8) [D] | yes, once per model version | classifier survey |
| Verifier source + build recipe | MB | yes, once per verifier version | — |

The Shieldstral size estimate scales the measured per-layer segment sizes:
11.4 MB per layer at TinyLlama T32, 14.9 MB at 8B T32, 22.6 MB at TinyLlama T128
and 29 MB at 8B T128. Shieldstral has 26 layers at d = 3072 and about 90 public
template tokens; public-prefix KV reuse (F6) would shrink it. Receipts already
come in per-layer segments of 15–30 MB, so each segment can be stored and
streamed separately. The verifier already verifies one segment at a time.

What a verifier does today (read-only code survey, `results/zk60_1b_native_20261017/r9/frozen-tree`):
- **Hashing:** it hashes every receipt byte. Roots, sumcheck rounds and clear vectors go through the keyed-BLAKE3 transcript; opened columns are hashed as Merkle leaves.
- **Weights:** it folds **every int8 weight** into Fp2 (Goldilocks p = 2^64 − 2^32 + 1) and re-hashes all the weights.
- **Cost shape:** work is O(model parameters) + O(receipt size). No weight commitment is cached.

## 2. Where the receipt lives: persistent stores compared

Costs are per 0.5 GB text-post receipt [D] from the [V] prices.

| Store | Per post | Per 10k posts | Permanence | Fetch and check | Speed [E] |
|---|---|---|---|---|---|
| **Arweave** (native) | **$25.71 once** | $257k once | Pay once; the endowment targets 200+ years. You can't delete. | `GET https://arweave.net/<txid>` or any ar.io gateway; the tx id commits to the data root; then compare SHA-256 with the manifest | slow for large files |
| Arweave via ArDrive Turbo (card) | $39.48 once | $395k once | same; **uploads under 100 KiB are free** | same | same |
| **Filecoin Onchain Cloud**, 2 copies | **$0.027/yr** | $273/yr | Lasts while paid; PDP proofs on-chain every 24 h stop payment if data is lost. Deletable. Price is "starts at" launch pricing. | HTTP from the provider or the FilBeam CDN by PieceCID (content-addressed) | tens of MB/s; CDN faster |
| IPFS pinning (Pinata class) | ~$0.21–0.42/yr [UNV] | $2.1k–4.2k/yr | Lasts while pinned; a CID alone guarantees nothing | any gateway by CID | varies |
| **Walrus** (Sui) | $0.64/yr | $6.4k/yr | Prepaid in 2-week epochs, up to about 2 years ahead, then renewed. Can be created deletable. | aggregator `GET /v1/blobs/<blobId>`; the blob id commits to the content | tens of MB/s |
| **Cloudflare R2** | $0.09/yr | $900/yr | Lasts while paid; trust in one company | HTTPS; integrity only from the on-chain hash; **egress free** | 100+ MB/s |
| Amazon S3 Standard | $0.14/yr + **$0.045 per download** | $1.4k/yr + egress | same as R2 | same; egress $0.09/GB | 100+ MB/s |
| Celestia (data availability) | $9.40 per publish | $94k | **Not storage.** Pruning nodes keep blobs about 7–30 days | by namespace and height, within the window | — |
| EigenDA | $18.15 per publish | $182k | **Not storage**; short retention [UNV] | disperser API, within the window | — |
| Ethereum blobs | — | — | pruned after about 18 days (EIP-4844) | — | — |

Price inputs:
- Arweave 14.377 AR/GiB × $3.84 = $55.21/GiB [V 2026-10-21]. Turbo fiat $84.78/GiB [V 2026-10-21].
- Walrus about $0.10 per raw GB-month (encoded size is 4.5 × raw + 64 MB per blob) [V: docs.wal.app costs page].
- Filecoin Onchain Cloud $2.50/TiB-month per copy, two copies by default [V: filecoin.io, 2026-03-26].
- R2 $0.015/GB-month with free egress; S3 $0.023/GB-month with $0.09/GB egress [UNV].
- Celestia $0.0188/MB and EigenDA $0.0363/MB [UNV].

Readings:
- **Data-availability layers are the wrong tool.** They guarantee publication for days, not persistence.
- **Permanence is priced by size.** At 0.5 GB per post, permanence costs about 200× a year of renewable storage. Arweave's pay-once model suits small things: statements, batch files, model files and verifier source.
- **Image and video posts** scale linearly. A 1.5 GB image receipt costs $0.35/yr renewable or $77 permanent; a video costs N frames times that.

## 3. Anchoring chains

The anchor transaction writes one 32-byte Merkle root, plus a count and a URI
hash, into **contract storage**, and emits an event. Gas estimate: 60k [E]. Gas
prices were read live from public RPCs at about 02:50 UTC on 2026-10-21 [V]; the
dollar costs are [D].

| Chain | Gas price now | Per anchor | Per post, 1,000/batch | Block time | Finality | Data permanence | Tooling |
|---|---|---|---|---|---|---|---|
| **Base** (OP Stack L2) | 0.0060 gwei, plus L1 data fee ≤1.0e-9 ETH | **$0.00088** | $0.0000009 | 2 s | seconds on L2; L1-final roughly 15–30 min [E] | L2 state, with commitments on Ethereum | Solidity/Foundry/viem; **RISC Zero verifier router deployed** [V]; Coinbase on-ramp |
| OP Mainnet | 0.0010 gwei | $0.00015 | ~0 | 2 s | as Base | as Base | router deployed [V] |
| Arbitrum One | 0.020 gwei | $0.0029 | ~0 | 0.25 s | about 15–30 min to L1 [E] | L2 state | router deployed [V] |
| Polygon PoS | 274 gwei POL × $0.095 | $0.0016 | ~0 | about 2 s | a few seconds [UNV] | its own validator set (not Ethereum-secured) | router deployed [V] |
| **Solana** | 5,000 lamports per signature | $0.00053 event-only; **$0.044** with 80 B in account state | $0.00004 | 0.4 s | about 12.8 s; Alpenglow scheduled for 2026-10-21 [UNV] | account state permanent while rent-exempt; validators do **not** keep transaction history | Anchor framework; groth16-solana; RISC Zero Solana verifier [UNV: mainnet] |
| Ethereum L1 | 0.040 gwei (unusually low) | **$0.0059 today**; $1.47 at 10 gwei; $7.34 at 50 gwei | $0.000006 | 12 s | about 12.8 min | strongest | best; router deployed [V] |

Market prices behind the table [V, CoinGecko 2026-10-21 02:42 UTC]: ETH $2,447.24, SOL $106.12, POL $0.0949.

### 3.1 Batching

**Batching is not needed for cost.** One Base transaction per post is $0.00088.
It helps with fewer keys and transactions, a batch file third parties can
mirror, and small inclusion proofs (about 10 × 32 bytes per post for 1,000
posts). The price is latency, up to one batch interval. Suggested: close a
batch every 10 minutes or every 1,000 posts; the batch file goes on Arweave
(about $0.013 native); the tree is a sorted, domain-separated Merkle tree.

### 3.2 Permanence notes

- **EVM logs are history, not state.** Ethereum clients ship partial history expiry (EF, 2025-07-08 [V]). Contract storage stays in state.
- **L2 state survives only while L2 nodes run.** An L2 anchor is weaker than an L1 anchor in the long run.
- **Cheap upgrade: a daily Ethereum checkpoint** writing the Base contract's accumulated root to L1: $0.006 today, about $1.50 at 10 gwei.
- **OpenTimestamps** (Bitcoin) is a free hash-only notarisation and can be added as well.

## 4. Can the proof be verified on-chain?

### 4.1 Directly: no

For one 0.5 GB receipt [D]: EVM calldata about 8 × 10^9 gas (about **133 full
Ethereum blocks**; about 48 ETH of calldata on Base); execution about 10^11 gas,
plus 3.4 GB of weights on-chain. On Solana the 1,232-byte transaction limit
means about 406k transactions just to upload. **Not feasible on any chain.**

### 4.2 Through a succinct wrapper (zkVM, then Groth16)

**Construction.** Run our verifier as a guest program in RISC Zero, SP1 or a
similar zkVM, with the statement hash and accept bit as public output; wrap in
Groth16 and verify that on-chain. The project has done this at toy size:
6.55 M cycles in 3,743 s on 2 laptop threads (about **1.75 kHz**); Groth16 wrap
197 s on CPU, receipt **785 bytes**, verify 8 ms [V, local,
`results/zk60_zkvm_hardening/cycle_gate/`]. This rests on D3 (about 97-bit
conjectured) and D4 (trusted setup), accepted for that intermediate; reusing them
for publication needs Victor's confirmation.

**Cycle estimate for one Shieldstral text proof** [E]:

| Work | Count | Cycles per unit | Cycles |
|---|---|---|---|
| Weight folds (int8 × Fp2 multiply-add) | ~3.4 × 10^9 | 15–30 | 5–10 × 10^10 |
| Weight re-hash (BLAKE3 in software) | ~3.4 GB | 18–25 per byte | 6–8.5 × 10^10 |
| Receipt hashing | ~0.5 GB | 18–25 per byte | 0.9–1.25 × 10^10 |
| Merkle node hashes | ~0.6 M | 1,200–1,600 | ~10^9 |
| Column checks (Fp2 × Fp) | ~0.7 × 10^9 | 60–90 | 4–6.5 × 10^10 |
| RS encodes | ~0.85 × 10^9 butterflies | 40–60 | 3.5–5 × 10^10 |
| **Total** | | | **~2–3 × 10^11** (8B T32: 3–5 × 10^11) |

**Proving time and cost:**

| Route | Shieldstral text proof |
|---|---|
| One RTX 5090 at 5–10.7 MHz [V] | **6–18 GPU-hours** |
| Rented RTX 5090 at $0.25–0.99/h [UNV] | **$2–18 per post** |
| Prover market at $0.04 per billion cycles [V, likely subsidised] | **$8–13 per post** |
| Our laptop CPU at 1.75 kHz | 3.6–5.7 years (useless) |
| Groth16 wrap | minutes |
| On-chain verify, about 300k gas | Base $0.0044, OP $0.0007, Arbitrum $0.015, L1 $0.03 today |

One aggregated Groth16 proof can cover a whole batch. Engineering: the guest must
stream 3.4 GB of weights and 0.5 GB of receipt through host I/O, and the verifier
must be ported to a single-threaded no_std guest: weeks of work [E].

**What would make the wrapper cheap** (prover-side changes, owned by the proof
lanes): (1) a precomputed public weight commitment the verifier opens, removing
the O(parameters) half; (2) recursion-friendly or accelerated hashing and field;
(3) smaller receipts. Together: **2–4 × 10^10 cycles, 0.5–2.4 GPU-hours, about
$0.2–2.4 per post** [E]. The public artifact would become a **785-byte** Groth16
receipt, and third parties would trust the zkVM and Groth16 setup in place of our
verifier.

### 4.3 Committee or optimistic alternatives (no new cryptography)

- **Committee attestation:** k-of-n independent verifiers each fetch the bundle, run the verifier, and co-sign the batch root (EIP-712, checked with ecrecover). About $0.001–0.01 per post per verifier [E]; trust is honest-majority.
- **Optimistic with a challenge window:** the root is posted with a bond; anyone can challenge within, for example, 7 days; disputes are settled by the committee or by producing the §4.2 zkVM proof for the disputed post only (the "ZK fraud proof" pattern). The receipt must be provably available during the window.
- **For the MVP:** neither on-chain path is needed. "Anyone can fetch the bundle and re-verify it" is already the strong property. Plan the committee as phase 2 and the wrapper as phase 3.

## 5. Privacy and legal

**What becomes permanently public:** the verdict (safe), the model identity, the
policy identity, the profile and verifier identity, the statement hash, the
bundle manifest hash, a random post id, the batch time and a **salted** content
commitment. The receipt is public while stored. Never published: the content,
the confidence score, any user id or per-user wallet; one app publisher key
signs every batch.

**The content commitment must be salted.** An unsalted hash fails: short posts
can be guessed (three words from a 50k vocabulary is about 3.5 hours on one GPU
[D]), and known texts or images can be confirmed instantly. Recommended form:
`c = SHA-256("zk60/proven-media/content/v1" ‖ salt₃₂ ‖ u64 len ‖ content bytes)`,
with a fresh 256-bit random salt per post. The app stores the salt with the post,
encrypted at rest, and serves it to viewers; the poster gets a copy; on deletion
the app erases content and salt (crypto-shredding), leaving the on-chain value
unlinkable. For the security owner: confirm which input commitment the
Shieldstral statement exposes, and the anchor must never add an unsalted or
deterministic hash of the content or its token ids.

**Permanent receipts and future breaks.** A Shieldstral receipt needs its own
privacy acceptance first. On permanent storage, any later flaw in the hiding
argument applies retroactively to every post ever published. Keep receipts on
deletable storage until the profile is accepted and the retention ruling is made.

**GDPR and the right to be forgotten.** EDPB Guidelines 02/2025 on blockchain
(v2.0 reported adopted July 2026 [UNV]): keep personal data off-chain, treat
hashes and commitments as possibly personal data while re-identification is
possible, design erasure in, run a DPIA. Under this design: no personal fields
on-chain; the commitment is salted and the salt can be destroyed; receipts stay
deletable; only non-personal artifacts go on Arweave. Whether a receipt (which
computationally hides the post) is personal data is unsettled: get legal review
before any permanent receipt publication. Only accepted posts are anchored.

## 6. Recommendation

### 6.1 MVP: off-chain bundle + batched anchor, which a third party can check alone

| Component | Choice | Cost |
|---|---|---|
| Receipt storage | **Filecoin Onchain Cloud** (2 copies, daily PDP) + **Cloudflare R2** mirror | **$0.117 per text post per year** [D]; 10k posts ≈ **$1,170/yr**; image posts about $0.35/yr |
| Statement + manifest per post | Arweave (Turbo, free under 100 KiB) | ≈ $0 |
| Batch file per batch | Arweave | about $0.013 per 1,000 posts |
| Anchor | **Base**, one transaction per batch | about $0.000001 per post; **$0.01 per 10k posts** |
| L1 checkpoint (optional) | Ethereum, daily | $0.006/day today; about $1.50/day at 10 gwei |
| One-off | Integer model export (about 3.9 GB) + verifier source on Arweave | about $200 per model version |
| **Total** | | **≈ $0.12 per post per year**; per 10k text posts **≈ $1,170/yr + ~$15 once** (+$200 per model version) |

Even at S3-like rates for both copies, about $0.30 per post per year. Option P
(permanent receipts on Arweave): **$25.7 per text post once, $257k per 10k**.

**Why Base:** cheapest tier; standard EVM tooling with the RISC Zero verifier
router already deployed (phase 3 lands in the same contract); Coinbase on-ramp
for a consumer app; Ethereum-settled, with an optional daily L1 checkpoint.
Alternatives: OP Mainnet (equivalent), Arbitrum (fine), Solana (the right pick if
preferred — Victor's song-provenance side project uses Solana NFTs; keep the root
in account state), Polygon PoS (own validator set only).

### 6.2 What to add later

| Phase | Adds | Cost [E] |
|---|---|---|
| 2 | Committee attestations ± optimistic challenge window | about $0.001–0.01 per post per verifier |
| 3 | zkVM + Groth16 wrapper of today's verifier, for disputes | $2–18 per post, 6–18 GPU-hours |
| 4 | Verifier redesigned for recursion | about $0.2–2.4 per post; makes every post on-chain verifiable |

## 7. Integration with `apps/proven-media/`

```text
publish(record: PublicationRecord) -> AnchorRef

PublicationRecord {
  schema: "zk60.publication/1"
  post_id: 128-bit random            # never a user id
  statement: bytes                   # canonical JSON, as the verifier prints it
  receipt_segments: [path]           # per-layer segment files
  verdict: "safe"                    # only accepted posts are published
  model_id, policy_id, profile_id, verifier_id: hex digests
  content_commitment: hex            # salted (section 5)
}
AnchorRef {
  status: "pending" | "anchored" | "l1_checkpointed"
  chain: "base-mainnet", contract, tx_hash, block_number, batch_id
  merkle_root, leaf_index, leaf_hash, merkle_proof: [hex]
  manifest_sha256, manifest_uri: "ar://..."
  receipt_uris: ["https://<r2>/...", "filecoin:<pieceCID>"]
}
verify_publication(anchor_ref) -> {accepted, reasons}   # third-party CLI
```

Steps: (1) publish only after the fresh-process verifier accepts the receipt;
(2) build a manifest of segment `{file, bytes, sha256}` plus ids, and hash it;
(3) upload segments to R2 and Filecoin, manifest and statement to Arweave;
(4) leaf = `H("zk60/anchor-leaf/v1" ‖ post_id ‖ manifest_sha256 ‖ statement_hash ‖ verdict ‖ model_id ‖ policy_id ‖ content_commitment)`;
(5) a batcher every 10 minutes or 1,000 leaves builds the sorted Merkle tree,
writes the batch file to Arweave and calls `anchor(root, count, batchFileHash)`
on a minimal contract from one publisher key; (6) each post links to its
AnchorRef, receipt URIs, salt (for viewers) and the verify command;
(7) `verify_publication` checks the root and Merkle path, fetches and hashes the
manifest and segments, fetches the model export by digest, runs the pinned
verifier, and optionally checks the content against `c` with the salt;
(8) deletion erases content and salt and deletes receipt segments, leaving the
on-chain leaf unlinkable; (9) Base Sepolia testnet first — a mainnet key and any
spending need Victor's approval.

## 8. Sources

See the lane's message of 2026-10-21 for the full annotated list (Arweave price
endpoint and ar.io docs; CoinGecko API snapshot; Walrus cost docs and USD-pricing
post; Filecoin Onchain Cloud announcements; R2/S3/Pinata pricing summaries;
Celestia retrievability docs and CIPs; EigenDA payments docs; read-only JSON-RPC
fee reads on Ethereum, Base, OP, Arbitrum, Polygon and Solana; Solana Alpenglow
reporting; EF history-expiry post; RISC Zero verifier router page; Ziren, OpenVM,
SP1 performance pages; Boundless network update; RTX 5090 rental pricing; EDPB
02/2025 summaries), plus local evidence: `docs/zkmatrix-poc/MVP_STATUS.md`,
`docs/zkmatrix-poc/ZK60_DECISIONS.md`, `results/zk60_zkvm_hardening/cycle_gate/cycle_gate.json`,
`results/zk60_classifier_survey_20261021/REPORT.md`, and the verifier code under
`results/zk60_1b_native_20261017/r9/frozen-tree`. `prices_20261021.json` in this
directory holds every live figure with its source and time.
