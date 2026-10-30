# Proven Media: design

A media feed in which every item carries **proved content labels**. The classifier is Mistral's
**Shieldstral-1.0-3B** (D37, D38). At creation, the item is classified **once per category** from
a fixed, pre-registered list. Victor confirmed three categories: **sexual / explicit content**,
**graphic violence** and **hate / harassment**. Each category is one fixed policy text with one
threshold, so an item has **three proofs**.

Every label is published with its proof, whether it is yes or no, and travels with the item in a
**signed proof manifest** (content-credentials style). The platform uses the proved labels for
**distribution**: explicit content is not sent to minors, for example. A "yes" label does not
reject an item. It decides who receives it.

**Chunks (D41).** Long content is split into chunks, and each chunk is proved separately per
category. The chunk size and overlap are a **deployment setting per hardware profile**
(`deploy.json`): about 40 content tokens on the laptop, 168 on a workstation and 424 on a
server. The stub caps the laptop's 40 at its own 31-token run.

An item of N chunks therefore has **N × 3 proofs**. A category is "yes" if any chunk is proved
yes, and "not proved" (fail closed) if any chunk lacks an accepted proof. The manifest lists every
chunk proof with its token range and category.

What is public per item:
- the labels;
- the model identity;
- the policy texts and the threshold;
- the content length in tokens (pending Victor).

The content is the proofs' hidden input. D39, as narrowed by Victor, covers **text and image**
items for the POC (video and audio are deferred) and asks for persistent public publication.

**Status (2026-10-21).** The classifier prover is being built by other lanes. This app runs
against today's next-token CLI as a clearly labelled **demo stub**. Every text item gets one real
zero-knowledge proof that the approved TinyLlama-1.1B integer model ran on the hidden post. That
one run **stands in for the three category proofs**. The labels come from an unproved placeholder
(a keyword list per category) and are marked "not bound by the proof" everywhere. Images are
accepted and canonicalised (§1). They stay "pending verification: image proof path in
development", visible to their author only. Publication and signing are local stubs: a
content-addressed store, a hash-chained block file and an Ed25519 **development** key. There is no
chain, network, wallet or real key.

## 1. User flow

**Text item.**
1. The user types a post. A live counter shows its token count and the proof plan, for example
   "50 tokens → 2 chunks × 3 categories = 6 proofs (profile laptop: 31-token chunks, overlap 8)".
   Posts longer than the profile's maximum chunk count (laptop: 4 chunks, at most 100 tokens) are
   refused; nothing is truncated silently.
2. **Post** queues the item and opens its page, which reads **"Pending verification: proving this
   item's labels, once, at creation"**. The page shows:
   - the queue position and the chunk being proved ("Proving chunk 2 of 4: …");
   - a progress bar ("1 of 2 chunk runs done · 3 of 6 category proofs");
   - an estimated time: about 150 s of work per queued chunk run, "if the shared machine is free";
   - the steps: prepare the hidden input → prove → verify from public files only → platform
     opens the sealed output → check the proof is about this post → publish the labels, anchor,
     sign the manifest;
   - a **chunk × category grid**: each cell is queued, proving (spinner) or done (the label), or
     "no proof";
   - "waiting for the shared machine" when another lane holds the box.

   The job is detached, so the user can leave. The item is distributed only once its labels are
   complete.
3. **Labels proved.** The item enters the feed with its label chips (`explicit: no`,
   `violence: no`, `hate: no`), a small **credentials** icon (a popover listing the manifest's
   entries and the signing key id), a `demo stub` tag and **"Check the proofs yourself →"**. The
   item page states **"proved once, at creation: \<timestamp\>"**.
4. **A "yes" label** (for example `violence: yes`) is published like any other label. Adults
   receive the item. Minors receive a placeholder: **"Hidden for this audience (Minor): violence:
   proved yes"**. The content itself is never served to that audience.
5. **No accepted proof** (refused, failed, timed out). Publication is all or nothing:
   no text, labels, record, manifest or proof bundle is served for a failed item.
   Only its authenticated author can see the per-post result **"Could not be verified."**
   It contains no chunk, category, reason, layer, timing or attempt count. Unpublished
   content is accessible only to the authenticated author. Query parameters do not
   establish authorship; the operator provisions random access keys, exchanged for
   revocable browser sessions. Failure diagnostics remain in private operator storage.

   The item is never re-proved. Existing D45 reservation and retry rules remain:
   a retry is eligible only if no proof ever started and the reserved context matches.

   **Tenant boundary before serving multiple platforms.** The current demo has one
   tenant. A hosted deployment must scope duplicate-content reservations to an
   authenticated tenant, rather than exposing a global duplicate lookup. Otherwise,
   submitting known text could reveal that another platform had already proved it.
   The tenant identity must come from server-side authentication and be included in
   the reservation's uniqueness key, lookup, queue claim and retry checks; a request
   field cannot select another tenant. Identical content in another tenant must not
   change the response or expose the other tenant's post, status or reservation.
   Before enabling multiple tenants, migrate existing reservations into an explicit
   demo tenant and test cross-tenant isolation alongside the existing within-tenant
   D45 refusal. This is a deployment requirement, not implemented multi-tenant support.
6. **Viewer audience.** A pill in the top bar ("Viewing as Adult / Minor") and the "Your audience"
   panel select the profile:
   - **Adult** receives every labelled item and may additionally hide any category.
   - **Minor (under 18)** receives only items proved **no** in all three categories.
7. **Delete** (author only): the text and the per-post salt are erased (crypto-shredding), and
   the receipt segments and private job files are deleted. The anchored leaves stay, and without
   the salt they are unlinkable.

**Image item** (spec from `results/zk60_multimodal_design_20261021/DESIGN.md` §2-§3).
1. The user picks one image (PNG, JPEG, WebP or GIF, at most 20 MB). The compose box previews the
   image and, beside it, **"what the classifier will see"**: an approximate 224 × 224 letterboxed
   canvas drawn in the browser.
2. On upload the server builds the **canonical pipeline** (`pm-img-area-v1`):
   - **Lossless master.** The image is decoded once to RGB8 with the EXIF orientation applied and
     the metadata dropped, and stored as PNG. The original upload is not kept; the master is the
     post.
   - **Resize.** The longest edge goes to **224 px** (the POC canvas, pending Victor) with an
     exact integer area average (`proven_media/image_preprocess.py`). The short edge rounds
     to the nearest integer (ties up, minimum 1). Pixel weights are exact area overlaps;
     rounding occurs once after both axes, to nearest with ties up. Portable vectors are
     in `tests/fixtures/image_area_v1.json`; a rational-area oracle independently tests the resize.
   - **Letterbox.** The image is centred on the square canvas. The margins are filled with the
     model's normalisation mean (RGB 123, 117, 104), so the normalised padding is about 0.
     Odd padding puts the extra pixel on the right/bottom.
   - **Layout.** A **patch-major uint8 tensor**: 16 × 16 patches of 14 × 14 × 3, 150,528 bytes.
3. **Binding.** The eventual proofs bind to the post through the **salted input commitment**: the
   run's hidden input endpoint (the design's L3), whose opening travels with the post. Until
   then, the app records its own salted commitment to the tensor,
   `SHA-256("zk60/proven-media/image/pm-img-area-v1" || salt_32 || u64-be len || tensor)`, using the post's
   per-post salt. The same canonical tensor is never submitted twice.
4. The item is **pending verification**: it is not in the feed, because its three labels cannot be
   proved yet. Its author sees the exact canonical canvas (served to the author only) and the
   planned proofs.

**Later (deferred by Victor): video and audio.**
- Video would use a public, deterministic, content-independent frame-sampling policy, with one
  image proof per sampled frame and category. One label per category: yes if any frame is yes.
  The per-frame proofs would be listed on the item page.
- Audio or transcripts would go through the text classifier.

Design and cost: the multimodal lane, §4-§5.

## 2. Architecture

```text
 browser (static/: index.html, app.css, app.js; hash routes #/, #/post/<id>, #/ledger, #/about)
    │  JSON API (FastAPI, proven_media/app.py); the feed is filtered per audience on the SERVER
    ▼
 SQLite (PRIVATE root: post text, encrypted salts, labels, manifests, jobs, checks)
    │  queue worker thread (proven_media/jobs.py): ONE proof job at a time from this app
    ▼
 ClassifierProver.start(...)  ──launch──►  setsid -f nohup tools/stub_pipeline.sh JOB_DIR
                                              each heavy leaf through scripts/zk60_resource_guard.py
                                              seqgen (light) → prove → verify → owner → input-owner (cpu)
 ClassifierProver.collect(...) ◄─ files ──  logs/*.log, *.guard.json, <run>/statement/
    │  labels per category (stub: one run for all three; placeholder values, not bound)
    ├─ per category with an accepted proof → Publisher.publish(PublicationRecord) → AnchorRef
    ├─ manifest.build_manifest(...) → zk60.manifest/1, Ed25519-signed (dev key)
    └─ failure → entire item withheld; authenticated author sees one generic failure result
```

* **Two data roots, both outside the repository.** The prover refuses owner files inside a git
  tree.
  - `~/zk60-owner-private/proven-media/` (mode 0700) holds:
    - the database;
    - the salt key (`app.key`) and the manifest signing key (`publisher-dev-ed25519.key`), both 0600;
    - the 0600 prompt files and the prover-private sequence directories (deleted after proving);
    - the owners' decommitments;
    - image masters and canvases;
    - job logs.
  - `~/zk60-artifacts/proven-media/` holds the run directories, the verifier's hard-linked copy of
    the public model files, the bundle store and the local chain.
* **Chunk jobs (D41).**
  - At creation the post's chunk plan is stored, and one queue job is created per chunk.
  - Each job is one detached guarded pipeline. The stub's run covers that chunk's three category
    proofs; Shieldstral would run three per chunk.
  - Per-chunk results go into `chunk_proofs`.
  - When the last chunk finishes, the item is **finalized**: labels aggregated, every accepted
    (chunk, category) proof published and anchored, the manifest signed.
  - The queue panel and the Status page show the running chunk, the per-item progress and an ETA
    for each queued item.
* **Detached, guarded, restart-safe.**
  - A job runs outside the web server and reports only through files. On restart, the server
    re-attaches by reading them. This was exercised twice with the real job.
  - A job whose process is gone without a done marker, or that predates a reboot, is treated as
    "labels not proved". It is never relaunched just because a status looks old.
* **Shared-box etiquette.**
  - Guard declarations are measured peaks plus a margin:
    - seqgen: 1.0 GiB (measured 0.52 GiB);
    - prove: 1.8 GiB with a 3.5 GiB cap (measured 1.28 GiB);
    - verify, owner and input-owner: 1.4 GiB each (measured 0.9 GiB).
  - The pipeline waits while `results/zk60_media_app_20261021/HOLD` exists.
  - The queue panel shows the guard's budget and locks.
* **The content never reaches a command line.** The post's ids go into a 0600 file, and `job.env`
  holds only paths and public pins. The tests check both.

### Why the stub needs `seqgen`
`zk60_token_io prove` also takes the prompt's hidden activations (`--seq-dir`). Its sealing pass
checks bit-exact parity against them at every layer, and the export ships activations only for
its calibration hold-outs.

`tools/seqgen.py` builds them. It chains the post through the calibration lane's integer
reference (`tlcalib.i_block`, imported read-only) and refuses any post that leaves an integer
range. Acceptance: it rebuilt the export's `seq_ho00` byte for byte, all 44 of 44 arrays
[MEASURED].

## 3. The prover interface

```python
class ClassifierProver:                         # proven_media/provers.py
    kind, label, supports, proves_verdict
    def prove(item) -> ProofRecord              # blocking convenience: labels for EVERY registered category
    def verify(record) -> Verdict               # blocking convenience: re-verify (never re-prove)
    # the app's non-blocking form of the same:
    def start(post_id, item, job_dir); def poll(job_dir) -> status; def collect(post_id, item, job_dir) -> ProofRecord
    def start_recheck(record, prove_job, job_dir); def collect_recheck(record, job_dir) -> Verdict
```

* **Typed items** (`items.py`): `TextItem(text)` and `ImageItem(path (the lossless master),
  sha256, mime, bytes, width, height, canvas_sha256)`, plus the canonical image pipeline.
* **`ProofRecord.labels`:** one entry per category,
  `{value yes|no, proof accepted|none, bound_by_proof, policy_id, policy_sha256, proof_ref}`.
* **`StubProver`** supports text only. It wraps the frozen round-11 `zk60_token_io` CPU build
  (sha256 `0c9f247c…`, checked by the pipeline): TinyLlama-1.1B, export `pg_rot1_b4_T32_cal128`,
  with pins from its approval record. One run stands in for the three category proofs.
* **`ShieldstralProver`** is a placeholder. When the classifier lands, it runs **one proof per
  category**: a different template, so a different input per category. Each statement carries
  that category's label bit, the model identity, the policy digest and the hidden-content
  commitment. Per-category status then comes from per-category runs.
* **`FakeProver`** exists for tests and UI work only; it proves nothing, and the UI turns red.
* **One encoding path** (`prompting.build_prompt(kind, content, category)`, check rule 3). This
  is the only function that turns a post into prover input.
  - **Shieldstral:** per category, the fixed template prefix (system prompt, `[INST]`, that
    category's `<Instruct>`/`<Query>`, `\n\n<Document>:`). The prefix ends at the colon. Then
    tekken's **plain-text** encoding of `' ' + content` (no special-token parsing), then
    `[/INST]`. This raises until mistral_common lands.
  - **Stub:** BOS + the TinyLlama SentencePiece plain-text encoding + `"\n"` pads to T = 32.
  - Both refuse empty content, content over the limit, and any control or unknown id. The tests
    check that `<s>`, `</s>`, `[INST]` and `[/INST]` stay plain text.
* **Chunking** (`prompting.chunk_plan`, `config.deploy()`). Chunks are windows over the post's
  token sequence: size C, overlap O, stride C − O, the last window ending at the last token. A
  chunk's prover input is BOS + its token slice + pads (stub), or the per-category template
  around the slice (Shieldstral). Deployment profiles live in `apps/proven-media/deploy.json`
  (laptop 40/8/4, workstation 168/16/8, server 424/32/16 as chunk / overlap / max chunks). The
  active profile is shown on the Status page; edit the file or set `PM_PROFILE`, then restart.
* **Category policies** (`policy/pm-cat-{sexual,violence,hate}-v0.txt`) are short descriptive
  placeholders. They will be swapped for the calibration prep lane's exact texts
  (`results/zk60_shieldstral_prep_20261021/`) under **new registered ids**, never by editing a
  file. The digests are pinned in `config.py`, and the app refuses to start if a file changed.

## 4. What is public, what stays private

| Item | Public | Notes |
|---|---|---|
| labels, one per category (yes / no / not proved) | yes | stub: **not bound by the proof** (placeholder source); "not proved" counts as yes |
| model identity (statement identity, token-profile digest) | yes | pinned by the approval record |
| category policies (text + SHA-256), category-set digest, threshold rule | yes | label yes iff z_yes − z_no > c, c = ln(τ/(1−τ)) = 0 at τ = 0.5 |
| content length in tokens | yes (pending Victor) | check rule 4 / C-5; stub: reported, not bound |
| statement and its SHA-256; receipt segments, sizes, SHA-256s | yes | 24 segments, 255 MB for TinyLlama T32 |
| hidden-input commitment (the statement's endpoint root) | yes, inside the statement | **not** repeated in the anchors or the manifest (O-2 / D23) |
| salted content commitment `c` | yes (anchored, in the manifest) | `SHA-256("zk60/proven-media/content/v1" ‖ salt₃₂ ‖ u64-be len ‖ UTF-8)`; the salt is encrypted at rest and served to viewers with the item |
| the signed proof manifest | yes, with the item | served only to audiences that may receive the item |
| **the post's token ids, hidden activations** | **no** | 0600 file; activations deleted after proving |
| **owners' decommitments** | **no** | D21: a decommitment would be a transferable proof of which content was posted |
| **the content, for an audience its labels exclude** | **no** | a placeholder with the reason is served instead |
| **confidence scores; the stub's opened next token; user identities** | **no** | item ids are 128-bit random |

## 5. Publication and the proof manifest

**Publication** follows `results/zk60_chain_publication_20261021/REPORT.md` §5–§7, with one
publication per (item, chunk, category) proof.

```python
publish(record: PublicationRecord) -> AnchorRef        # proven_media/publisher.py
verify_publication(anchor_ref) -> {accepted, reasons, checks}
PublicationRecord{schema "zk60.publication/1", post_id (128-bit), category, chunk, token_range, statement (bytes),
                  receipt_segments, verdict "yes"|"no", model_id, policy_id, profile_id, verifier_id, content_commitment (salted)}
AnchorRef{status pending|anchored|l1_checkpointed, chain, contract, tx_hash, block_number, batch_id,
          merkle_root, leaf_index, leaf_hash, merkle_proof, manifest_sha256, manifest_uri, receipt_uris, category,
          chunk, token_range}
```

* **When.** Only after the fresh-process verifier accepted the receipt. Every accepted label is
  published, whether yes or no; unproved categories are not.
* **Manifest.** Per-segment `{file, bytes, sha256}`, the statement hash and URI, the label, the
  four ids and the salted commitment, stored by its own SHA-256. Identical receipt segments are
  stored once (content addressing), so the stub's shared run costs one copy.
* **Leaf.** `SHA-256("zk60/anchor-leaf/v3" ‖ f(post_id) ‖ f(category) ‖ f(chunk) ‖ f(token_range) ‖
  f(manifest_sha256) ‖ f(statement_hash) ‖ f(verdict) ‖ f(model_id) ‖ f(policy_id) ‖
  f(content_commitment))`, with `f(x) = u16-be(len) ‖ bytes`. The chunk is written as an ASCII
  decimal and the range as `"start-end"`.
* **Batch.** A sorted, domain-separated Merkle tree is built every 10 minutes or every 1,000
  leaves. A node is `SHA-256("zk60/anchor-node/v1" ‖ min ‖ max)`. Each batch makes one
  `anchor(root, count, batchFileHash)` call in a hash-chained block. The Ledger page has a
  presenter button that closes the batch now.
* **Local stand-ins.** `local-cas://` stands in for Filecoin + R2 + Arweave, and
  `chain/blocks.jsonl` for the Base contract. Base Sepolia comes after Victor's chain and
  retention rulings.

**Proof manifest** (`zk60.manifest/1`, `proven_media/manifest.py`; D37 addendum).
- **When it is made.** It is produced when the item's labels are complete, whether proved or
  failed.
- **How it travels.** It is attached to the item in every API response that serves the item, and
  in `<item>.manifest.json`. It is also inside the downloadable bundle.
- **What it holds.**
  - `item`: post id, kind, creation time, salted content commitment and rule, content length.
  - `category_set`: id and digest; `chunking`: profile, chunk size, overlap, number of chunks.
  - `labels`: the aggregated label per category and the `label_rule`.
  - `proved_once_at_creation`: the proof timestamp.
  - `entries`, one per **(chunk, category)**: `chunk`, `token_range`, classifier, `model_id`, `profile_id`, `verifier_id`,
    `policy_id`, `policy_sha256`, threshold, `verdict` (yes / no / unproved), `proof_status`,
    `verdict_bound_by_proof`, `statement_sha256`, `bundle` (publication manifest hash and URI),
    `anchor` (chain, contract, leaf hash) and `content_commitment`.
  - `issued_at`, `issuer` (name, key id, public key).
- **Signature.** Ed25519 over the canonical JSON without the signature field. The key is a
  **local dev key** in a 0600 file. Its public half is in the manifest and at
  `/api/publisher-key`.
- **Verification.**
  - "Verify manifest" in the app, or `tools/verify_manifest.py MANIFEST [--public-key HEX]
    [--rehash] [--run-verifier]`.
  - It checks the signature, pinned to the publisher's key in the app.
  - For each proved entry, it checks the ledger's anchor leaf, the publication manifest (label,
    statement, policy, model, commitment), the Merkle path, the block chain and the batch file.
  - An unproved entry must name no anchor.
  - `--run-verifier` rebuilds each distinct run from the store and runs the pinned verifier
    through the guard.

## 6. Operating rules

1. **Labels for distribution (D37).** Each item is proved **once per category, at creation**,
   and never re-proved. Re-checks re-verify the stored proof. A repeat of the same content gets
   HTTP 409; a resubmission is allowed only if nothing ever ran on the first submission. "Yes"
   does not mean rejected: it narrows the audience.
2. **Fail closed per category.** A category without an accepted proof counts as the most
   restrictive label, so restricted audiences never receive the item. If a later re-check is
   **rejected by the verifier**, every label of the item becomes "not proved" and the manifest
   is re-issued saying so. A re-check that merely did not run changes nothing.
3. **Fixed category list.** One fixed policy and one threshold per category, pre-registered and
   pinned. There are no ad-hoc policies, and an item is never proved again at another threshold
   or policy (repeated proofs would leak the hidden score).
4. **One encoding function** (§3).
5. **Public per item:** the labels, the model, the policies, the threshold and the content length
   (pending Victor).
6. **Server-side distribution.** The feed and item endpoints take the viewer's audience. A hidden
   item is served as a placeholder with labels and reasons, never with its content or manifest.

## 7. How a third party verifies

1. **"Re-verify now"** (in the app): a fresh-process `zk60_token_io verify` of the stored run
   against the pinned model files, about 15 s of work through the guard, plus the platform's
   binding check (`input-owner`).
2. **"Verify manifest"** (in the app): the signature, then each entry against the ledger (§5).
3. **"Verify publication"** (in the app): per category, the store, the publication manifest, the
   leaf, every segment, the block chain, the anchor transaction, the Merkle path and the batch
   file.
4. **"Check it in my browser"**: recomputes the salted content commitment from the displayed text
   and the served salt.
5. **Offline.**
   - **Download bundle (.tar)** gives `VERIFY.md`, `record.json`, `publication.json` (the
     AnchorRefs), `<id>.manifest.json` and `run/`. Then run `zk60_token_io verify --export
     <public-model-dir> --emb <public-model-dir> --head <head-dir> --artifact <bundle>/run
     --expect-statement <model_id> --expect-token-profile <profile_id>`.
   - Or run `tools/verify_manifest.py <id>.manifest.json --run-verifier`.

## 8. Honest limits (shown on every item page and on "How it works")

* **Demo stub.** One next-token proof stands in for the three Shieldstral category proofs. The
  labels are placeholders and are not bound by the proof.
* **Coverage.** Text only, in chunks of at most 31 tokens on the laptop profile (the stub caps the
  configured 40), at most 4 chunks per post. Image proofs are in development; video and audio are
  deferred.
* **Speed.** About 2.5 min of work per chunk on a laptop CPU, plus waits for the shared machine;
  verifying takes about 15 s. Shieldstral is estimated at 3–5 min per category proof of a 64-token
  post, about 3× that per item. The ≥ 50 proved tokens/s target is far away.
* **Privacy.** No privacy acceptance covers this artifact.
* **Binding.** The platform checks binding to the displayed text with its private opening (D21).
  The salted commitment is not yet tied *inside* the proof (O4).
* **Soundness and fidelity.** Soundness is about 2^-95 per run (D27). The integer model's
  perplexity is about 1.2–1.3× that of the float model.
* **Local stubs.** Publication and signing run on this machine: no chain, network, wallet or real
  keys.
* **Maturity.** Research prototype, no external audit. A single-user demo with no accounts.

## 9. Open items

* **O1:** `ShieldstralProver`: one run per category, the label read from each statement,
  `bound_by_proof: true`, and real per-category status.
* **O2:** the prep lane's exact category policy texts, registered as new ids.
* **O3:** the image prover:
  - the pinned reference pipeline with test vectors;
  - the canvas size ruling (224 vs 448);
  - the L3 binding blob.
* **O4:** tie the salted commitment to the proof; today the platform attests the binding.
* **O5:** Victor's rulings on content length public (C-5), chain (Base) and retention, plus the
  D23 amendment for anchoring.
* **O6:** a refusal-free final-norm profile (C-4), so that "not proved" is hard to trigger. The
  app already fails closed.
* **O8:** chunking semantics for the classifier: whether overlap suffices for content that spans
  chunk boundaries, and whether a per-item context summary is needed. The measured cost per
  profile also has to be fixed: 3 proofs per chunk at Shieldstral sizes.
* **O7:** a real publisher key (KMS/HSM) and key rotation, C2PA interoperability, accounts, and a
  real age signal for the minor profile (today it is a viewer toggle).
