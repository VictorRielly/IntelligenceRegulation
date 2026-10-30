# Proving as a service: product and architecture spec (draft for Victor)

Prepared 2026-10-30 20:35 UTC by Claude (coordinating session), reading only. Nothing was built, deployed,
registered, bought or published. No third-party service was contacted.

Victor's request (2026-10-30): *"I want to host a website where people can use the proving services as a service.
(For example, if facebook wanted to publish proofs of good quality content they could go on my site and use my
software to create and publish a proof)."*

**Labels.** **[MEASURED]** a recorded run or a count I made (file named). **[READ]** a figure taken from a project
document, keeping that document's own label. **[INFERRED]** my assumption or estimate, not checked; replace it with
a quote or a measurement before relying on it. The arithmetic is reproducible:
`python3 results/zk60_proving_service_20261030/capacity_cost.py` (inputs, labels and sources inside; output
`capacity_cost.json`).

**Not legal advice.** Section 5 lists duties and risks a lawyer must confirm. Nothing here replaces counsel.

---

## 0. Plain summary for Victor

Your example works, but not as "Facebook sends us its posts". **The proof hides a post from everyone who *checks*
the proof, not from whoever *runs the prover*.** If we run the prover, we read every post. A large platform will not
send its users' private posts to a small outside service. Also, one machine proves about **40 short posts a day**
today, against the billions of items a large platform handles.

Recommended path:
- **Phase 0 (now):** a public site that registers, verifies, anchors and displays proofs, plus a **self-host kit**
  (the open-source prover, D48). The platform proves on its own machines and we never see content. That is your
  sentence exactly: "use my software to create a proof, publish it on my site".
- **Phase 1:** a small, free, invited hosted pilot, for **text that is already public**, after a lawyer signs off.
- **Phase 2:** sensitive content. Self-hosting comes first. A confidential-computing enclave comes only if a named
  customer asks and pays.

**Decisions for you** (details in §7):
1. The trust model and phase order above.
2. Hosting: a small rented server for Phase 0. For Phase 1, a rented CPU server or the 5090 desktop. Never the laptop.
3. A domain and a name.
4. A free invited pilot (recommended under D47), or pricing.
5. A lawyer before any hosted content.
6. Receipt retention and the anchor chain (open since 10-21).
7. Astra's first build: the Phase 0 registry and verification page.

---

## 1. The central question: who sees the content

### 1.1 What P1 does and does not hide

D1 (P1) hides the inputs, outputs and activations **from the verifier and from every public artifact**. The draft
classifier privacy statement says it plainly: *"The app runs the prover, so the app sees the post (and keeps its
opening, D45(3)). The proof hides the post from everyone else who sees the proof"*
([draft v3 §0](ZK60_PRIVACY_STATEMENT_CLASSIFIER_SHIELDSTRAL_T128_DRAFT_v3.md), [READ]). The prover needs the
plaintext to compute the model. So a hosted prover means the operator sees the content, unless one of three
arrangements holds.

### 1.2 The three arrangements compared

| | (a) Customer self-hosts the prover; the site registers, verifies, publishes, anchors | (b) Hosted prover inside a confidential-computing enclave, with attestation published beside each proof | (c) Plain hosted proving; the customer trusts the operator |
|---|---|---|---|
| **Who can read the content** | Only the customer. The service receives receipts, statements and manifests, never content or openings. | The enclave only, if the TEE holds. The operator sees ciphertext and metadata (who, when, size, how long). | The operator, as with any cloud moderation vendor. |
| **What verifiers trust** | The proof (96-bit floor; privacy statement once accepted) and the registry's timestamp and anchor. | The same proof. The attestation adds evidence about how the operator handled the content. | The same proof. |
| **Can the operator forge a verdict?** | No. Soundness comes from the proof in every column. | No. A broken TEE leaks content to the operator but cannot forge verdicts. | No. |
| **Which prover binary made the receipt?** | **Not checkable from a receipt.** The end users' privacy against verifiers rests on the platform running the reviewed binary; the privacy statements cover named binaries only. | Checkable: the attestation names the measured image, and so the binary, if the image is built reproducibly. | The operator's word, signed. |
| **D45(2): one policy list, never re-proved under another** | The registry pins the policy ids, thresholds and model, and refuses anything else. It cannot detect the same post proved twice under the *same* list (fresh hiding roots each run), which repeats the same verdict and adds no new question. | Enforced in the enclave, as in (c). | Enforced by the service's keyed item reservation, per tenant (the app's existing D45 logic). |
| **Who attests the proof-to-post link (D45(3))** | The customer holds the opening. The registry can say "this receipt verifies", not "this receipt is about post X". | The enclave returns the opening encrypted to the customer. | The service checks it, then hands the opening to the customer and deletes its copy. |
| **Operator cost per short post** [INFERRED from §4] | About 3.6 min of CPU for verification, plus storage if the service hosts receipts. | About 35 min of prover work in a confidential VM, plus engineering. | About 35 min of prover work. |
| **Engineering effort** [INFERRED] | Low to moderate: the registry, the page and a kit around the D48 release. About 1–2 weeks of agent work after the release. | High: reproducible worker image, attestation client, encrypted envelope, key handling, external TEE review. 1–3 months. | Low: a multi-tenant API on the existing app. 2–4 weeks, plus legal lead time. |
| **Legal and abuse burden** | Lowest: no content is received. | Middle: content is received, encrypted. Counsel must say whether reporting duties attach to content the operator cannot read. | Highest: the operator receives plaintext, including illegal content (§5.1). |
| **Would a very large platform accept it?** [INFERRED] | **Yes, the most likely form.** It runs open-source code on its own machines and uses a neutral registry, or runs its own. | Possibly a mid-size customer that already uses confidential VMs. A very large platform would more likely self-host. | Not for private user content from a small startup. Possibly for already-public content in a pilot. |

### 1.3 What a confidential-computing enclave gives, and what it does not

**What it gives.**
- Memory encryption and integrity against the host, the hypervisor and the operator.
- **Remote attestation:** the hardware signs a report of the measured launch image (firmware, kernel, application).
  Before sending content, a customer checks that the enclave runs a specific image. The customer then encrypts the
  content to a key only that enclave holds.
- If the image is built reproducibly from the public source (D48), anyone can tie the measurement to code. That also
  shows which prover binary made each receipt, which (a) cannot show.

**What it does not give.**
- **Remote attestation proves which code ran in the enclave. It is not a zero-knowledge property.** It hides nothing
  from verifiers; P1 does that. The two are complementary: P1 hides the content from verifiers, the TEE hides it from
  the operator.
- It does not make the code correct. A logging bug inside the enclave leaks the content just the same. The
  attestation is worth only as much as the review of the attested image.
- Trust moves to the hardware vendor's keys and implementation. Published side-channel and physical attacks have
  broken TEEs repeatedly: SGX (Foreshadow, 2018) and AMD SEV (CacheWarp, 2023; BadRAM against SEV-SNP, 2024)
  [INFERRED from my knowledge of the literature; check current advisories before any claim].
- The operator still controls availability and scheduling, and sees metadata: which customer, when, how large, how
  long. The length is public anyway (D45(1)).
- **Hardware fit:** today's classifier prover is CPU only (r16b, `dfb8025e…` [READ, open release plan]). A CPU TEE
  (AMD SEV-SNP or Intel TDX confidential VMs from the major clouds) is the match. NVIDIA's GPU confidential computing
  is a data-centre feature (H100 and later); the GeForce RTX 5090 does not offer it [INFERRED; confirm in NVIDIA's
  documentation]. The 5090 desktop therefore cannot host route (b).

### 1.4 What a very large customer would actually do

- **Volume.** One prover slot proves about 42 short posts a day (§4). A billion items a day would need about 24
  million slots [derived; the billion is an order-of-magnitude assumption, INFERRED]. At that scale the proofs serve a
  **sample** (a daily published sample of public posts, or ads or content shown to minors), **audits** (items a
  regulator names), or **high-stakes items**, not everything.
- **Trust.** It would self-host the open-source prover on its own machines after its own security review. The
  service's value to it is **neutrality and a standard**, much as a certificate-transparency log is neutral: an
  independent registry, timestamp, public pages and verification.
- **Paperwork.** Even for the registry it would ask for an SLA, a security programme (SOC 2 or ISO 27001 class) and
  contracts [INFERRED]. These belong to a later company, not to the pilot.

### 1.5 An honest note on public content

For text that is already public, anyone can run the public Shieldstral model on it and get the verdict without our
proof. Hosted proving of public content (Phase 1) still gives three things:
- a binding made at creation time (the anchored proof shows the label existed then);
- a label that travels with the item (the signed manifest, as in Proven Media);
- a label checkable by audiences who are never sent the content (the "hidden for minors: proved yes" case).

**The zero-knowledge value appears with content the verifier cannot see:** restricted-audience posts, private
messages, regulator audits of private data. That is Phase 2, and self-hosting is its safest route. Phase 1 is a
staging step for operations and legal readiness, not the product's core value.

### 1.6 Recommendation

- **Phase 0:** route (a) now.
- **Phase 1:** route (c), for already-public text only, invited and free.
- **Phase 2:** route (a) for sensitive content by default. Route (b) only for a named customer who needs hosted
  proving of private content and pays for it.

---

## 2. Users and jobs

### 2.1 Who uses it

| User | Job | Route |
|---|---|---|
| **Platform (the customer)**, e.g. a media app, a publisher or an NGO | Get proved labels for its items under the fixed three-category list (D37), publish them with the item, and link each proof to its post (D45(3)). | Self-prove and register (a), or submit content (c, later b). |
| **The service** | Prove (hosted routes only), verify every receipt in a fresh process before listing it, publish, anchor, show the public page, delete on request. | Every route. |
| **Anyone** (a viewer, a recipient app, a journalist) | Check that a published label is backed by a proof that verifies, under the stated model and policy, anchored at a stated time. | The public page; the offline verifier. |
| **Auditor or regulator** | For sampled items: get the text and the opening **from the platform** (never from the service), run the input-owner check against the public receipt, verify the receipt, and read the anchor time. Optionally check completeness counts (below). | Offline verifier plus the registry's records. |

### 2.2 What a proof says, and what it does not

- **It says:** "The approved integer version of Shieldstral-1.0-3B gives verdict *v* for this chunk under
  category policy *P*", for each of the three categories and each chunk (D38, D41).
- **It does not say:** that the content is safe, lawful, accurate or "good quality". It does not cover any category
  outside the three. It does not show that the classifier is right: adversarial text can evade it.
- **Known limits that travel with every claim** [READ]:
  - soundness floor 96 bits per run, and no external audit;
  - the classifier privacy statement is a draft (v3), not accepted;
  - the full 4,872-item integer-fidelity benchmark is incomplete
    ([app README](../../apps/proven-media/README.md), [recovery report](../../results/zk60_astra_20261026/real_app_demo_1/RECOVERY_REPORT.md));
  - the moderate policy wording awaits Victor's strict-or-moderate ruling;
  - text only; images are in development, video and audio are deferred (D39).

### 2.3 The flows

**Self-prove and register (route a).**
1. The platform runs the kit on its own machine. The kit wraps the app's pipeline: prepare, prove, fresh verify,
   input-owner check, label.
2. It uploads to the registry the statement, the receipt segments (or their URLs, if it stores them itself) and its
   signed manifest. Openings and content stay with the platform.
3. The registry checks the model, profile and policy pins, re-verifies every receipt in a fresh process, lists the
   item, anchors the batch and returns the public page URL.

**Submit content (route c).**
1. The platform submits text over the API, with its own post reference.
2. The service plans the chunks (D41), reserves the item under the one list (D45(2), per tenant), proves each
   (category, chunk), verifies each in a fresh process and runs the input-owner check.
3. Publication is all or nothing. On failure the platform gets one generic result, "could not be verified" (D45(4),
   C-7).
4. On publish: anchoring, the public page, and the opening returned to the platform. Then the service deletes the
   content and its copy of the opening.

**Completeness log (optional, per tenant).** An auditor needs the denominator: how many items were submitted, how
many were published, how many could not be verified. Hosted routes can publish these counts per period. In
self-host mode they are the platform's own report. Whether per-period refusal counts reveal anything about a single
post is for the security owner to check before the counts are offered.

---

## 3. Architecture

### 3.1 Components

```text
 public web (static pages)            tenant API (HTTPS, API keys)             operator console (private)
   /p/<item>  verification page         /v1/jobs  /v1/register  /v1/items        queue, guard status, incidents
        │                                   │
        ▼                                   ▼
 public registry DB  ◄──────────  service core (grows out of apps/proven-media)
 (items, manifests, anchors,          ├─ planner: pinned Tekken encoder, D41 chunk plan per category
  segment hashes, counts)             ├─ reservation: per-tenant keyed item fingerprint (D45(2))
        │                             ├─ job queue (SQLite WAL on one host; Postgres only if multi-host)
        │                             ├─ worker: detached guarded pipeline, one job per (category, chunk)
        │                             │    seqgen → prove → fresh verify → input-owner → label   [hosted]
        │                             │    fresh verify only                                     [registry]
        │                             ├─ publisher: Merkle batch → anchor (Base Sepolia today)
        │                             └─ manifest signer (service key in a KMS/HSM; tenant co-signs)
        ▼
 object store (content-addressed by SHA-256): receipt segments, statements, manifests, batch files
 private store (per tenant, encrypted, short-lived): content, salts, openings, job logs without content
```

### 3.2 The API

All routes are versioned. Every mutation takes an `Idempotency-Key`. Responses never carry content, openings
(except the one delivery below), margins or scores, failure reasons, or per-step timings.

| Route | Who | What |
|---|---|---|
| `POST /v1/plan` | tenant (routes b, c; Phase 1 on; in Phase 0 the kit plans locally) | Text in; returns the token count, the chunks per category, J proofs and an estimated time. Refuses empty text, control ids and anything over the profile's limit (336 tokens at T128 [READ, deploy.json]); nothing is truncated silently. Proves nothing. |
| `POST /v1/jobs` | tenant (routes b, c) | Text, the tenant's post reference and an optional webhook. Reserves the item under the one list (409 inside the tenant if already reserved), queues J jobs and returns the job id. The policy list is not a parameter: there is one (D45(2)). |
| `GET /v1/jobs/{id}` | tenant | queued / proving *k* of J / verifying / ready / could-not-be-verified. Generic on failure: no chunk, category, reason, timing or attempt count (C-7). |
| `POST /v1/jobs/{id}/publish` | tenant | Anchors, makes the page live, returns the page URL, the manifest and **the opening, once**. The service deletes its copy after the tenant acknowledges receipt, or after 7 days [INFERRED default]. |
| `POST /v1/register` | tenant (route a) | Statement, segments or segment URLs with sizes and SHA-256s, and the tenant-signed manifest. The registry pins and re-verifies, then lists and anchors. Size caps: J ≤ 22 receipts of the registered size. |
| `DELETE /v1/items/{id}` | tenant | Withdraws the page, deletes the receipts the service holds, purges the CDN, deletes any salt or opening still held. The anchored leaves stay; without the salt and opening they cannot be linked (§5.6). |
| `GET /v1/items/{id}` and `/p/{id}` | public | The public record and page (§3.6). |
| `GET /v1/verifier` | public | The verifier bundle: binary, scripts, `SHA256SUMS`, instructions. |
| webhooks | service to tenant | Signed (HMAC with a per-tenant secret): `job.ready`, `job.failed` (generic), `item.anchored`. |

**Authentication.**
- API keys are 256-bit random values, shown once and stored only as hashes, as `auth.py` already does for authors.
- Keys carry scopes (plan, submit, publish, register, delete) and can be rotated and revoked.
- Keys never appear in URLs, logs or argv. mTLS is optional for larger tenants.
- Operator access is separate: hardware keys, no shared accounts.
- Each tenant registers an Ed25519 manifest key, so it is the manifest's issuer. The service countersigns:
  "verified by verifier `<hash>` at T, anchored in transaction X".
- The dev key Proven Media uses today must not carry over. The real service key lives in a KMS or HSM (DESIGN O7).

### 3.3 Job queue and the guarded worker

The worker reuses the app's pipeline unchanged: `jobs.py`, `shieldstral_prover.py`, `tools/classifier_pipeline.py`
and the pinned r16b binary.

**Rules carried over, and why.**
- **Every heavy leaf runs through the resource guard** (`scripts/zk60_resource_guard.py run --class cpu`). Measured
  peaks [MEASURED, first two posts]: prove 7.99–8.24 GiB, declared need 10.4 / cap 11.5 GiB; verify about 2.3 GiB.
  On a dedicated Linux host the guard's budget is resized to that host's RAM through a reviewed guard change. It is
  never bypassed.
- **One heavy slot until a multi-slot guard is reviewed.** Today all cpu, gpu and build jobs share one heavy lock.
  Several concurrent proofs on a bigger machine need a reviewed "N slots, shared memory budget" guard. That is a
  coordination item, not an app setting.
- **Lean memory:** one job of 3 GiB or more on the box at a time unless the budget says otherwise. Drop large files
  from the page cache after publication.
- **Disk admission (D46).** A job waits unless the free disk covers its receipts plus margin:
  J × 0.85 GB × copies, plus the guard's 40 GiB floor. The guard kills any job under 8 GiB free.
- **One receipt copy on disk.** Today each post is stored twice: the run directory and the content-addressed bundle
  store are separate files, 2,545,251,995 B and 2,545,266,296 B, link count 1 [MEASURED]. Publishing by hard link or
  move halves the disk per post, from 5.09 to 2.55 GB.
- **Detached and restart-safe.** A job reports only through files. A job with no done marker is never relaunched
  because its status looks old. There is no automatic retry after proof work has started (the D45 retry rule).
- **Batch proving (`prove-batch`, token round 18) only after R18-1.** Route every batch through the terminal
  collector, quarantine any unfinished batch at queue start-up before any retry, and never publish
  `.batch-quarantine/` (round-18 review, [READ]). A 22-job post is one guarded job of about 2.8 h writing about
  18.7 GB, with its own time cap and a D46 announcement [READ]. Until then: the per-category path and the r16b pin.
- **The content never reaches a command line** (already true: a 0600 file). It is never written to logs or crash
  dumps.
- **D23 in the registry.** No artifact may refer to an accepted receipt's endpoint roots, except the D45(3) anchoring
  beside the post. The registry accepts only the registered classifier profiles, which have one external endpoint
  and no chaining (D40).

### 3.4 Storage

**Sizes** [MEASURED]: 848,412,096 B per (category, chunk) receipt in 28 segments; 2,545,236,288 B (2.55 GB) for a
short post of 3 receipts. A post of J receipts needs J × 0.85 GB, up to 18.7 GB at J = 22.

| Class | Examples | Where | Retention | Owner |
|---|---|---|---|---|
| Public, large | receipt segments | Object store, content-addressed by SHA-256, immutable, CDN. Optional mirror; optional bring-your-own storage for route (a). | Victor's retention ruling (§7.6): 3 or 12 months renewable recommended [INFERRED options]. Deletable. | Public; deletion at tenant request. |
| Public, small | statements, manifests, batch files, anchor references, the verifier's SHA256SUMS | Registry DB and object store. Permanent storage (Arweave) only after the classifier privacy acceptance (chain report, point 7). | Permanent, unless withdrawn. | Public. |
| Private, short-lived | content (hosted routes), the per-item salt, the input-owner opening, the job's work directory | Per-tenant encrypted store on durable disk: never `/tmp` (`storage_policy.py`), never in the repository. | Content: deleted when the job reaches a final state. Opening and salt: until delivery is acknowledged, or 7 days [INFERRED]. Activations: deleted after proving (already the case). | **The tenant.** |
| Private, operational | the reservation fingerprint (keyed, per tenant), the job ledger, the audit log | Private DB. | Fingerprint: as long as the D45(2) promise must hold. Logs: 30 days [INFERRED]. | Service. |

**Never stored, or never beyond the stated window:**
- owner openings after delivery (D21, D45(3)): a decommitment is a transferable proof of which content was posted,
  and it belongs to the customer;
- content after the job (hosted), or in logs, backups or crash dumps;
- hidden activations, the margin or confidence score (D38(c));
- failure reasons in any tenant-facing or public response (C-7);
- per-step timings in public records (the app already omits them);
- quarantined or unfinished receipts (R18-1);
- customers' signing keys.

**Compression does not help.** zlib level 6 on the bulk 32.45 MB segment saved 0.24 %; on the two small end segments
it saved 13 % and 5 % (1.4 MB and 3.3 MB). Over a whole receipt that is about 0.3 % [MEASURED, 3 of 28 segments of
one receipt]. Hash-based proof bytes look random. Smaller receipts must come from the proof side (§4.5).

### 3.5 Anchoring

- **Today (testnet, [READ] TESTNET.md):** contract `0x8432eba8…` on Base Sepolia. One `anchor(root, count,
  batchFileHash)` transaction per batch of up to 1,000 leaves. The first post's 3 leaves went in one transaction
  (block 52,075,726). The contract records digests only; it does not verify proofs.
- **Mainnet cost per post** [derived from the MEASURED gas limit 30,883, the code's ×1.25 estimate margin, and the
  READ 2026-10-21 prices: Base gas 0.006 gwei, ETH $2,447]:
  - about 24,700 gas per batch transaction, about **$0.0004** per transaction;
  - about **$0.000001 per post** in a full batch of 333 three-leaf posts; still $0.0004 with one transaction per
    post;
  - even at 100× the gas price, about $0.04 per batch.
  - The contract only emits an event. Ethereum is expiring old logs, so a mainnet contract should also store the root
    in contract state (chain report §3.2): about 47,000 gas [INFERRED], still under $0.001.
  - An optional daily Ethereum L1 checkpoint costs $0.006 at today's 0.04 gwei, and $1.47 at 10 gwei [READ prices].
- **What mainnet really costs is not gas:**
  - a new contract (the current one refuses any chain but 84532) and its review;
  - a real publisher key in a KMS or HSM;
  - Victor authorising a small real-ETH purchase;
  - RPC provider dependence. The default public RPC returned HTTP 403 from this host [READ].
- **Batching** every 10 minutes or 1,000 leaves stays as designed.

### 3.6 The public verification page and the downloadable verifier

**The page for each item.**
- The labels per category; the chunk table with token ranges; the post length in tokens (D45(1)).
- The policy texts and their SHA-256s, the threshold rule (c = 0), the model and profile identities.
- The verifier binary's hash and the 96-bit floor.
- The anchor: chain, contract, transaction, block, Merkle path and batch file, with a **testnet badge** while on
  testnet.
- The service's verification record: who verified, when, with which binary and result. A TEE attestation report is
  added in Phase 2(b).
- "What is public, what stays hidden", in the plain words of the privacy statement: the verdict bits, the length,
  the chunk facts, the refusal channel (§5.5).
- The banners "privacy statement pending" and "research prototype, not audited" stay until each is resolved.
- No timings. No content unless the tenant chooses to show it. No opening unless the tenant publishes it for a public
  item; that option needs the security owner's reading first.

**In-browser checks (cheap).**
- The manifest signatures (Ed25519).
- Every segment's SHA-256 against the manifest, if the visitor downloads them.
- The salted content commitment, for visitors who have the text and the salt (the app's existing "check it in my
  browser").

**The full check (offline).**
- The bundle has the `zk60_classify` verifier (the newest frozen and reviewed round: 19b at the time of writing, Linux
  x86-64), `verify_manifest.py`, `verify_publication.py`, `SHA256SUMS` and the steps.
- The visitor fetches the Shieldstral checkpoint (7,698,241,104 bytes; a regular file, since symlinks are refused,
  REVIEW_R19 [READ]), sets `ZK60_MODELS` and obtains the integer export. The open release notes that a stranger still
  needs the verifier copy of the export (open release plan, 17:00 status [READ]). Whether the service may host that
  export is a licence question already open there.
- Cost for one short post: 3 × about 72 s of CPU and 2.3 GiB [MEASURED], plus a 2.55 GB download (about 3.4 minutes
  at 100 Mbit/s, 17 minutes at 20 Mbit/s [derived]), plus the one-time 7.7 GB checkpoint.

**No public "re-verify now" button.** Each run costs about 72 s of CPU and 2.3 GiB, so anonymous re-verification
would be a denial-of-service lever. Show the stored records and the offline steps instead; tenants may request a
re-check within quota.

### 3.7 How it grows out of `apps/proven-media`

Astra owns the app. This mapping is a proposal for her, not an edit plan.

| Today in `apps/proven-media` | In the service |
|---|---|
| `jobs.py`, `shieldstral_prover.py`, `shieldstral_runtime.py`, `shieldstral_text.py`, `prompting.py`, `tools/classifier_pipeline.py`, `hardware_profiles.py`, `deploy.json` | The worker and the planner, unchanged and pinned. |
| `publisher.py`, `testnet_publisher.py`, `base_sepolia.py`, `contracts/` | The anchoring service. A mainnet contract is new work (§3.5). |
| `manifest.py`, `records.py` | Manifests with the tenant as issuer and the service as countersigner. |
| `store.py` (posts with text, screenings, jobs) | Split into a private job store (content short-lived, per tenant) and the public registry. The keyed screening table becomes per-tenant reservations. |
| `auth.py` (hashed author keys, sessions, CSRF) | Tenant API keys and scopes. Browser sessions stay for the operator console. |
| `storage_policy.py` | Unchanged, plus disk admission and one receipt copy. |
| `static/` item page ("Check the proofs yourself") | The public verification page. |
| `tools/verify_manifest.py`, `tools/verify_publication.py` | The downloadable verifier bundle, beside the native binary. |
| The media feed itself | **The first tenant**, calling the service API: dogfooding. |

A sibling `apps/proving-service/` that imports these modules keeps the feed intact. Astra decides the structure.

---

## 4. Capacity and cost

### 4.1 Measured inputs (laptop, Core Ultra 9 185H, shared box, n = 1 each)

| Per (category, chunk) job | Value | Source |
|---|---|---|
| Prove, 8 threads | 452.0, 456.3, 457.0 s | [MEASURED] `real_app_demo_2/sexual.json`; `real_app_demo_1/violence.json`, `hate.json` |
| Prove, 2 threads | 1,031.2 s | [MEASURED] `real_app_demo_1/sexual.json` |
| Whole pipeline (prepare + prove + fresh verify + input-owner + label), 8 threads | 684.6, 687.5, 693.5 s; mean **688.5 s** | [MEASURED] same files |
| Fresh verify | 67.7–80.8 s; 2.1–2.3 GiB | [MEASURED] same files |
| Receipt | 848,412,096 B, 28 segments | [MEASURED] |
| One-load batch of 3 (round 18) | 1,418 s against 1,453 s for three singles (−2.4 %) | [READ] coordination file, 2026-10-30 09:22 UTC |

### 4.2 Proofs per post

J = the sum over the three categories of that category's chunk count. Content per chunk is 55 / 55 / 49 tokens with
an overlap of 8 [READ, deploy.json]; the last window is end-aligned.

| Post length (tokens) | 17 | 49 | 55 | 100 | 200 | 336 (maximum) |
|---|---|---|---|---|---|---|
| J (proofs) | 3 | 3 | 4 | 7 | 15 | 22 |
| Work on one slot | 0.57 h | 0.57 h | 0.77 h | 1.34 h | 2.87 h | 4.21 h |
| Receipts | 2.55 GB | 2.55 GB | 3.39 GB | 5.94 GB | 12.7 GB | 18.7 GB |

The J values are [COUNTED]; the times and sizes are derived from the measured per-job figures.

### 4.3 Posts per day on one RTX 5090 desktop with today's CPU path

**The GPU does not take part.** The classifier binary is CPU only [READ]. What counts is the desktop's CPU and RAM,
and neither is known: no Linux was installed and neither machine had been inspected as of 2026-10-17
([hardware setup](ZK60_HARDWARE_SETUP.md), [READ]). So the answer is given per concurrent 8-thread job slot.

The arithmetic for one slot, short posts (J = 3):
86,400 s / (3 × 688.5 s) = **41.8 posts a day**. Proving alone would bound it at 63.3. At J = 22 a slot does 5.7
posts a day.

| Concurrent slots on the desktop | Assumed efficiency [INFERRED] | Short posts / day | Longest posts (J = 22) / day |
|---|---|---|---|
| 1 (what the guard allows today) | 1.00 | **41.8** | 5.7 |
| 2 (needs about 23 GiB for proofs and 16 threads) | 0.85 | 71 | 9.7 |
| 4 (needs about 46 GiB and 32 threads) | 0.65 | 109 | 14.8 |

- The efficiency figures are assumptions. Going from 2 to 8 threads gave only 2.26× on the laptop, which suggests
  memory-bandwidth limits [MEASURED ratio, INFERRED cause].
- **One day of measurement on the desktop replaces this table.** Sol's lane runs it once Linux is in.
- **Cheap gains, not built:**
  - verify, input-owner and label each reload the model, about 67 s each. Folding them into one load (the L1
    "run hygiene" lever of the speed plan) might save about 100 s per job, taking a slot to about 49 posts a day
    [INFERRED];
  - the one-load batch saves 2.4 % [MEASURED].
- **The GPU port** is projected at about 17 s per text post on a 5090 [READ, multimodal design 2026-10-21, labelled
  MODEL there; not built]. Nothing in this spec assumes it.
- **A 5090 desktop that serves pilot proofs cannot also take quiet speed measurements.** Pilot proving and the
  measurement work need separate machines or scheduled windows.

### 4.4 Storage and bandwidth per post

For a short post, 2.55 GB = 2.37 GiB [MEASURED]. Prices are READ from the chain report (2026-10-21) and must be
re-checked before any spend.

| Store | Short post | Note |
|---|---|---|
| Cloudflare R2 | $0.038 a month, **$0.46 a year** | Free egress (READ, unverified there) |
| Filecoin Onchain Cloud, 2 copies | $0.14 a year | Renewable; launch pricing |
| Amazon S3 Standard | $0.70 a year, plus **$0.23 for each full download** | Egress at $0.09 per GB |
| Arweave, permanent | **$131 once** | Not for receipts; the chain report advises against permanence before the privacy acceptance |
| Disk on the prover host, today | 5.09 GB (two copies) | 2.55 GB after the one-copy fix |
| Third-party download | 3.4 min at 100 Mbit/s; 17 min at 20 Mbit/s | Plus 7.7 GB of checkpoint once |

A residential uplink cannot serve receipts. Receipts go to the object store or CDN, never out of a home machine
[INFERRED].

### 4.5 What smaller receipts or recursive wrapping would change

- **General-purpose compression:** about 0.3 % (§3.4). Not worth doing.
- **Proof-side levers (prover lane, each with its own privacy and soundness review):**
  - Public-prefix reuse (S5 / F6). The fixed template fills 73 of the 128 positions for sexual and violence and 79
    for hate [COUNTED from the content capacities in deploy.json]. For a 17-token post, 13 % of the positions are
    content. A design that does not re-prove the public prefix could cut time and size; its size is unknown until
    designed.
  - A verifier weight commitment (S6) roughly halves verification work [READ: the O(parameters) half] and is a
    precondition for a cheap wrapper.
- **A Groth16 wrap (the zkVM route, D4).**
  - **Size:** 785 bytes per receipt [MEASURED on the toy zkVM block, not the classifier], so 2,355 bytes for a short
    post instead of 2.55 GB, about a million times smaller.
  - **Storage:** permanent storage becomes nearly free.
  - **Verification:** milliseconds, with no 7.7 GB model download (the toy verified in 8 ms [MEASURED]). On-chain
    verification becomes possible at about 300k gas (about $0.004 on Base [READ estimate]).
  - **Privacy:** the 848 MB inner receipt would become a private witness, so less is published.
  - **Cost today:** wrapping a Shieldstral verification is estimated at 6–18 GPU-hours, $2–18 a post [READ estimate,
    chain report §4.2]. After the verifier redesign (S6 and recursion-friendly hashing) it falls to 0.5–2.4 GPU-hours
    [READ estimate].
  - **What it rests on:** D3 (about 97-bit conjectured soundness) and D4 (the trusted setup) were accepted for the
    zkVM intermediate. Reusing them for publication needs Victor's confirmation, and the composition needs its own
    privacy statement.
  - **Conclusion:** a later phase, worth it only after S6.

### 4.6 Rough monthly cost for a small pilot [INFERRED unless marked]

| Item | Phase 0 (no proving) | Phase 1 (hosted, 300 short posts a month) |
|---|---|---|
| Small server for the API, the page and registry verification (4 vCPU, 8 GB) | $20–60 | $20–60 |
| Prover host | none | Home 5090 desktop, electricity at 150–400 W: $38–101; **or** a rented dedicated CPU server: $100–250 |
| Receipt storage on R2 | under $1 for the demo posts | 3-month retention: 2.3 TB, about $34 a month at steady state. 12-month: 9.2 TB, about $137 a month [derived] |
| Anchoring (Base mainnet, if chosen) | under $0.10 | under $1 |
| Domain | about $1–2 | about $1–2 |
| **Total** | **about $25–65 a month** | **about $90–200** (desktop, 3 months' retention) **to $260–450** (rented server, 12 months) |
| One-off | — | Legal review: ask for a quote. The TEE route (Phase 2b) adds a confidential VM at about $350–900 a month if always on [INFERRED, unquoted]. |

The pilot uses about 24 % of one slot: 300 × 3 × 688.5 s = 172 slot-hours a month [derived].

---

## 5. Safety, legal and abuse

**None of this is legal advice.** These items are **blockers**: each needs a lawyer's confirmation before the stage
that triggers it.

### 5.1 Illegal content, including CSAM

- **The risk is certain, not hypothetical.** A service that receives content for moderation will receive illegal
  content, including child sexual abuse material. Moderation services are where it arrives.
- **US reporting duty: 18 U.S.C. §2258A** [INFERRED reading; counsel to confirm the current text].
  - It applies to "providers": electronic communication service and remote computing service providers (§2258E). A
    service offering storage or processing to the public is plausibly a remote computing service.
  - A provider that obtains **actual knowledge** of an apparent violation must report it to NCMEC's CyberTipline as
    soon as reasonably possible, and preserve the report's contents. The 2024 REPORT Act extended preservation to one
    year and widened the reportable offences (child sex trafficking and enticement).
  - §2258A(f) creates **no duty to scan or monitor**.
  - Knowing failure to report carries fines.
  - **Open questions for counsel:** whether an automated "sexual: flagged" verdict, or any staff contact, creates
    knowledge; whether duties attach to content the operator cannot read (route b); and whether a zero-knowledge
    receipt derived from illegal content is itself a problem (it does not contain the content in recoverable form;
    counsel to confirm).
- **What the service must do, by phase.**
  - **Phase 0 (route a): refuse all content.** The API has no content-upload route. Uploads are receipts,
    statements and manifests of registered sizes and formats, and anything else is refused. This is the main reason
    to start here.
  - **Phase 1 (route c): text only.** Images multiply the CSAM risk, and image proving is not ready anyway. Before
    any hosted content:
    1. counsel's sign-off on whether the service is a §2258A provider;
    2. registration with NCMEC for reporting, if counsel advises it;
    3. a written procedure: on apparent CSAM, do not view or redistribute it, do not publish or anchor the item,
       quarantine it, preserve it as the law requires, report, and record;
    4. a named responsible person;
    5. contract terms requiring tenants to run their own detection and reporting first. Platforms already carry
       these duties; the service is a second line.
    The text pilot still needs this: text can evidence enticement or trafficking.
  - **Images (any phase):** not accepted until a hash-matching programme exists. Industry tools such as PhotoDNA are
    licensed to qualified organisations [INFERRED]. Counsel must also approve the handling and staff-welfare
    procedure.
- **Other jurisdictions:** the EU Digital Services Act and the UK Online Safety Act put duties mainly on the platform
  (our tenant). Counsel to say whether the service is itself a hosting or intermediary service there [INFERRED].

### 5.2 Data protection

- **GDPR role:** for posts by people in the EU, the tenant is the controller and the service is a **processor**.
  - Article 28 requires a **data processing agreement**: subject matter, duration, categories of data, the list of
    sub-processors (the cloud host, R2, the RPC provider), Article 32 security, prompt breach notice to the controller
    (Art. 33), help with data-subject rights, and deletion or return at the end.
  - Transfers out of the EU need the EU-US Data Privacy Framework or standard contractual clauses. Records of
    processing are kept.
  - California's CCPA/CPRA needs a service-provider contract [INFERRED].
- **Are receipts personal data?** They are derived from a person's post. While the tenant holds the opening and the
  salt, the published receipt is linkable, so treat it as **pseudonymous personal data**. After the salt and the
  opening are destroyed, the anchored leaves are hashes of salted commitments that can no longer be opened, which the
  chain report offers as the erasure answer. **Counsel to confirm** this "crypto-shredding" reading for on-chain
  hashes (the EDPB has issued blockchain guidance [INFERRED; check the current text]).
- **Labels are statements about a person's speech.** A public "hate: flagged" on an identifiable post can hurt
  someone, and moderation restrictions carry statement-of-reasons duties for platforms under the DSA. The tenant
  needs a legal basis to publish labels. Counsel to review the defamation exposure of publishing them [INFERRED].

### 5.3 Terms of service (the tenant contract)

- **Warranties from the tenant:** it has the right and consent to submit the content. In Phase 1 the content is
  already public, text only and lawful. It runs its own illegal-content detection and reporting.
- **What the service promises:** a proof shows the integer classifier's verdict under the fixed policy. It is not a
  finding that content is safe, lawful or accurate, and there is no warranty of classifier accuracy.
- **Prototype status:** research prototype, not audited, 96-bit floor, privacy statement pending, testnet anchors.
  Labels say so in the UI.
- **Publication:** anchors cannot be undone; receipts are deletable under the retention ruling.
- **Service rights:** refusal, suspension, quotas and termination; deletion on exit; limited liability.
- **Other points:** export notice for open cryptographic source (EAR 742.15(b), already flagged in the open release
  plan), and a trademark check on the name.

### 5.4 Abuse and rate limits

- **Compute denial of service.** One short post costs about 35 minutes of a prover slot, so every submission is
  authenticated: no anonymous submission.
  - Per-key quotas: posts a day and concurrent jobs.
  - A maximum length (336 tokens) and a maximum J of 22.
  - Fair queuing across tenants.
  - The plan endpoint is cheap. Proving starts only on submit.
- **Hostile uploads (route a).**
  - Uploads must be receipts of the registered size and segment count, or they are refused.
  - The verifier is fail-closed but now faces untrusted multi-GB input. It runs sandboxed, under the guard's memory
    cap (verify cap 7 GiB [READ, deploy.json]) and a time cap.
  - Sol fuzzes the segment parser before Phase 0 opens.
- **Oracle use.** Submitting text to learn the verdict gains nothing, because the model is public. The per-tenant
  reservation answers 409 only inside the tenant, so it is no cross-tenant membership oracle. A global reservation
  would be one: never use one.
- **Laundering.** Content proved "not flagged" is not "approved by us". The wording on every page and in the terms
  must say so.
- **Edit-and-retry.** A tenant can edit a post until it passes. The proved text is then the posted text, which is
  honest about that text. D45(2) forbids re-proving an item under a different policy; edits are new items.
- **Public endpoints:** a CDN with rate limits. No public verification on demand (§3.6).

### 5.5 What the public verdict bits reveal (D40, D45)

Plain words for the page, taken from draft v3 §0 [READ]:
- Each published proof reveals the **verdict bit**, the **length in tokens**, and the chunk facts: which chunk, its
  range, the pad positions.
- The model is public, so anyone can compute the verdict for any guess.
- For very short posts the public facts say a lot: for a one-token post, the three verdict bits place the hidden
  token in one of at most 8 groups that anyone can compute from the public model.
- Per-chunk bits show **which part** of a post triggered a flag. The end-aligned last chunk can overlap its neighbour
  by up to 54 tokens, which can localise a decisive token.
- An accepted proof shows the post passed the integer model's ranges.
- **"Could not be verified" can depend on the content** (the refusal channel). It is shown only to the tenant, as one
  generic bit (C-7). The real-model refusal rate (C-8) is still unmeasured. Both are conditions before non-public
  content.
- The service publishes nothing beyond these facts. Tenants must tell their users that these facts become public.

### 5.6 Retention and deletion

- **Content (hosted routes):** deleted when the job reaches a final state, success or failure. On a reported illegal
  item, the legal preservation duty overrides deletion; counsel defines the procedure.
- **Openings and salts:** handed to the tenant, then deleted (§3.4). Losing them loses the post link: the first
  garden post's openings were lost with `/tmp` on 2026-10-30 [READ, recovery report]. The service's copy is
  short-lived on purpose; the tenant's copy is the durable one.
- **Receipts:** per the retention ruling. Deletion ends third-party re-verification. Only the anchored digest and the
  service's signed "verified at T" record remain, and that record is a statement to trust, not a proof.
- **Deletion request:** delete the receipts and any held salt or opening, purge the CDN, and mark the manifest
  withdrawn. The anchors remain and cannot be linked without the salt and opening.
- **Backups:** encrypted. Deletion reaches backups within a stated rotation window (30 days [INFERRED]).

### 5.7 Questions for counsel (one list)

1. Is the service a §2258A provider in each route? What creates "actual knowledge"? What preservation and reporting
   procedure applies? Is a receipt derived from illegal content a problem?
2. Do the controller / processor roles, the DPA, transfers and crypto-shredding of on-chain hashes satisfy GDPR? Do
   the DSA or the UK Online Safety Act apply to the service itself?
3. The terms of service, the privacy policy and the limits of liability.
4. Defamation exposure of public "flagged" labels.
5. The export notice for open cryptographic source, and a trademark check on the name.
6. **Victor's new employment:** whether running a service, or the D48 release, interacts with the new employer's
   invention-assignment and outside-activity terms (already flagged under D47 and D48).

---

## 6. Phased plan

Lane ownership follows the standing split: **Astra** (Codex) owns the app and service code; **Sol** (Codex) owns the
prover and verifier; **Claude** coordinates and reviews.

### Phase 0: verify-only site plus a self-host kit (no customer content touches the service)

**Scope.**
- The public registry: register self-proved bundles from allowlisted tenants. The first tenant is the Proven Media
  demo itself.
- The public verification pages and the verifier download.
- Anchoring on Base Sepolia, with a testnet badge.
- The self-host kit: the D48 release, plus a `prove-and-register` command around the app's pipeline, plus the D45
  reservation logic run locally.

**Builds.**

| Lane | Work |
|---|---|
| Astra | Registry API (`/v1/register`, `/v1/items`, `/p/{id}`); tenant API keys; the verify-before-list worker (guarded); the public page from the app's item page; one receipt copy on disk; disk admission; fetch from bring-your-own storage; the kit command. Her current items come first: the library demo post with durable openings, and R18-1. |
| Sol | A build recipe that yields a published, reproducible verifier hash, or the closest feasible (today the hash depends on the build path [READ]); fuzzing and caps for the verifier on hostile uploads; the D48 reference round. |
| Claude | A web security review of the registry (an independent agent); a D23 / D45 / D40 conformance review (security owner); a privacy review of the public page (no timings, no roots beyond D45(3)); the decisions register; MVP_STATUS. |

**Exit criteria.**
1. The D48 release is published on Victor's go, at the reviewed reference round. The kit depends on it.
2. A stranger, using only the public page, verifies the library demo post on a clean Linux machine. The fresh verify
   passes, and the input-owner check passes with the opening the tenant (Victor) hands over.
3. The registry refuses, each shown by a test: fake or dev receipts; an unregistered model, profile, policy or
   threshold; an oversize or misshapen upload; a duplicate under the tenant's fingerprint; any artifact that refers to
   another receipt's roots.
4. No public or tenant response contains content, an opening, a timing or a failure reason (tested).
5. It runs on a host that is not the laptop.
6. The security review is accepted.

### Phase 1: hosted pilot, public content only (route c)

**Scope.** At most 3 invited tenants. Free, with hard quotas. Text that is already public, which the tenant warrants.
The one registered policy list. Per-tenant reservation; fail closed; the opening delivered, then deleted. Testnet or
mainnet anchoring, as Victor rules.

**Preconditions.**
- Phase 0's exit criteria.
- Counsel's sign-off on §5.1–5.3, with the CSAM procedure written and rehearsed once.
- Victor's strict-or-moderate ruling.
- The integer-fidelity benchmark complete, so that verdict quality can be stated.
- Retention and chain rulings.

**Builds.**

| Lane | Work |
|---|---|
| Astra | The submit / status / publish / delete endpoints and webhooks; quotas and fair queuing; content deletion at the final state; the opening hand-off and its deletion; the incident path (quarantine, no publication, preservation per counsel); the completeness counts, if the security owner clears them; `prove-batch` only after R18-1 is reviewed. |
| Sol | One day of capacity measurement on the chosen host (slots, threads, peaks), then a reviewed multi-slot guard proposal if the host can take more than one slot; optionally the single-load checks lever. |
| Claude | A security review of the hosted path; a privacy review of the tenant-facing responses; the legal question list (§5.7) handed to counsel; a rehearsal of the incident procedure; MVP_STATUS. |

**Exit criteria.**
1. 30 days of pilot operation. An audit finds no content in any log, backup or crash dump outside policy.
2. Deletion is tested end to end.
3. Every published item verifies from public data alone, checked by an outsider.
4. The measured capacity and costs are written back into §4.
5. The incident drill is done, and counsel gives a go for Phase 2.

### Phase 2: sensitive content (self-host first; an enclave on demand)

**Route (a), the default.** The Phase 0 kit, used for non-public content.

Preconditions:
- the classifier privacy statement accepted by Victor (v3 or a successor) and recorded in the register;
- **C-7** (failures shown only to the authenticated author; implemented in the app on 10-30 as P-7 / P-8, to be
  carried into the service API) and **C-8** (the real-model refusal rate measured; Astra's benchmark) met;
- a privacy statement extended to any binary or batch path the kit ships. Today v3 covers r16b and r17 only, and v4
  for r19b and the batch waits on R18-1 [READ].

**Route (b), only for a named customer.** A hosted prover in CPU confidential VMs (SEV-SNP or TDX).
- The customer verifies the attestation report, then encrypts the content to the enclave's key.
- The enclave returns the receipts, and the opening encrypted to the customer.
- The attestation report is published beside each proof, saying what it means and what it does not (§1.3).

Exit criteria for (b):
- a reproducible worker image whose measurement anyone can recompute from the source;
- a TEE design review (Claude plus an external TEE specialist) and a penetration test;
- a DPA annex for the enclave;
- tenants verifying attestation themselves, with documented steps;
- images only after the hash-matching programme (§5.1).

**Lanes:** Astra builds the enclave application and the attestation client. Sol builds the reproducible prover
build and any GPU path. Claude reviews and commissions the external review.

### Effort and order [INFERRED]

| Phase | Agent work | Gate |
|---|---|---|
| 0 | About 1–2 weeks after the D48 release | Victor's release go, plus a small server |
| 1 | About 2–4 weeks | Counsel's lead time, which is likely longer than the work |
| 2a | Small, mostly docs | Privacy acceptance, C-7, C-8 |
| 2b | 1–3 months | A customer who asks |

---

## 7. Decisions for Victor

1. **Trust model and order.** Recommended: (a) now; (c) for a public-text pilot; (b) only on a named customer's
   request (§1.6). The alternative, starting with (c), is faster to demo but carries the full legal burden from day
   one.
2. **Hosting hardware.**
   - **Never the laptop.** It is a shared development box.
   - Phase 0 needs no prover: a small rented server ($20–60 a month [INFERRED]) plus R2.
   - For Phase 1 proving, choose:
     - a **rented dedicated CPU server** (recommended). It keeps the 5090 desktop free for the speed work and the
       pilot off a home connection. About $100–250 a month [INFERRED, get quotes];
     - or **the 5090 desktop**, once Linux is installed: no rent, but it is at home (power, uplink, physical
       security in the DPA), it would share the machine with quiet speed measurements, and its GPU sits idle on
       today's CPU path. Its CPU and RAM decide the slot count (§4.3).
3. **Domain and name.** Neither is registered. Counsel's trademark check comes before buying.
4. **Free pilot or pricing.** Funding is on hold until you have a partner (D47). Recommended: a **free, invited pilot
   with hard quotas** and a written "research prototype" disclaimer. Your running cost would be about $25–65 a month
   in Phase 0 and $90–450 in Phase 1 [INFERRED, §4.6]. Pricing waits for the partner.
5. **Legal review.** Engage a US internet and child-safety lawyer plus a privacy lawyer **before Phase 1**: the
   questions in §5.7, including your new employer's terms. Phase 0 can open without hosted content, but the terms of
   service and the registry's upload rules should still be read once.
6. **Retention and chain** (open since 2026-10-21). Recommended: **renewable, deletable receipt storage** (3 months
   for the pilot, or 12) and **Base**. Mainnet only when a real key in a KMS or HSM and a small real-ETH purchase are
   authorised. Gas is not the cost (§3.5).
7. **What to tell Astra to build first.** After her current items (the library demo post with durable openings, and
   the R18-1 app half): the **Phase 0 registry**, the **public verification page** and the **one-copy storage fix**
   (§6, Phase 0). The hosted submit API waits for counsel.

Smaller items, not Victor's (the security owner decides): whether per-tenant completeness counts are safe to publish
(§2.3), and whether a tenant may publish the opening of an already-public post (§3.6).

---

## 8. Blockers, in one list

1. **Legal:** no hosted content before counsel's sign-off on §2258A, the terms of service and the DPA (§5).
2. **Privacy:** the classifier statement v3 is not accepted, and C-7 / C-8 stand before any non-public content.
3. **Verdict quality:** the 4,872-item integer-fidelity benchmark is incomplete; the strict-or-moderate wording is
   open.
4. **No host:** the laptop must not host; the 5090 desktop has no Linux (as of 10-17); nothing is rented.
5. **The open release (D48)** is staged but unpublished, and the self-host kit depends on it.
6. **Rulings:** retention and chain are open since 10-21. Mainnet needs a real key and spend.
7. **Throughput:** about 42 short posts a day per slot, one heavy slot under the guard today. The GPU is unused by
   the classifier path.
8. **Size:** 2.55 GB of receipts per short post, 5.09 GB on disk today. Only proof-side levers (S5, S6, a wrap)
   change this.

---

## Sources read

- `apps/proven-media/`: `README.md`, `DESIGN.md`, `TESTNET.md`, `deploy.json`, `contracts/ProvenMediaAnchor.sol`,
  `proven_media/{auth,storage_policy,store,publisher,prompting,base_sepolia}.py` and the route list of `app.py`
  (read only).
- `results/zk60_astra_20261026/`:
  - `real_app_demo_1/` (`RECOVERY_REPORT.md`, `{sexual,violence,hate}.json`, `complete.json`, the batch file, the
    public store's sizes and link counts);
  - `real_app_demo_2/sexual.json`.
- `docs/zkmatrix-poc/`:
  - `ZK60_DECISIONS.md` (D1, D4, D5, D23, D37–D41, D45–D48, the round-18 review with R18-1, and the round-19 / 19b
    reviews);
  - `MVP_STATUS.md`;
  - `ZK60_OPEN_RELEASE_PLAN.md`;
  - `ZK60_PRIVACY_STATEMENT_CLASSIFIER_SHIELDSTRAL_T128_DRAFT_v3.md` §0;
  - `ZK60_SOL_ASTRA_TODOS_20261026.md` (Astra lines of 10-30);
  - `ZK60_RULINGS_FOR_VICTOR_20261017.md`;
  - `ZK60_RESOURCE_PROTOCOL.md`;
  - `ZK60_HARDWARE_SETUP.md`.
- `results/zk60_chain_publication_20261021/REPORT.md`: prices and the wrap estimates.
- The memory file `project-hardware.md`: the 5090 desktop plan.
- **Measured for this spec:** zlib and xz compression of three segments of the first post's sexual receipt (one
  light Python check, under 10 s, a few tens of MB).
