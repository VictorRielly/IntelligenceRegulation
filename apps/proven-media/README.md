# Proven Media (local demo)

Proven Media is a media feed in which every item carries **proved content labels**. At creation,
the item is classified once per category: **sexual / explicit**, **graphic violence** and **hate /
harassment**. Each category has one fixed policy and one threshold. Every label, yes or no, is
published with its proof and travels with the item in a **signed proof manifest**. The platform
uses the proved labels to decide **who receives the item**: minors never receive an item unless it
is proved "no" in all three categories. Long items are split into **chunks**, and each chunk is
proved separately per category. The chunk size depends on the hardware profile. (D37, D38, D39,
D41.)

**Default mode: a demo stub.**
- Each chunk gets a real zero-knowledge proof that the approved TinyLlama-1.1B integer model ran
  on the hidden text (today's next-token CLI).
- That proof is verified in a fresh process, published to a local content-addressed store,
  anchored in a local hash-chained ledger and listed in an Ed25519-signed manifest (local dev key).
- One stub run per chunk stands in for that chunk's three Shieldstral category proofs. **The
  labels come from a placeholder and are not bound by the proof.** The UI says this everywhere.
- Images are canonicalised to the 224-px canvas the classifier will see and stay "pending
  verification", visible to their author only, until the image proof path exists. Video and
  audio are deferred.

Design: `DESIGN.md`. Ledger: `PROGRESS.md`.

The optional [Base Sepolia publisher](TESTNET.md) is implemented, tested and
deployed with free test ETH. The first real app post completed all three
Shieldstral category proofs and was anchored on Base Sepolia on 2026-10-30.
All three labels are "no"; the app still displays **privacy statement pending**.
The [run and reboot recovery report](../../results/zk60_astra_20261026/real_app_demo_1/RECOVERY_REPORT.md)
records the proofs, testnet transaction, fresh public-store verification and
the explicitly replaced local development signing key. The original owner
openings and salt were lost with the temporary workspace: its proof-to-post link
cannot be rechecked from an opening. The public receipts and segments still
verify. No proof was repeated during recovery.
It refuses the demo stub's unbound labels. The image path now uses the versioned
integer-only `pm-img-area-v1` preprocessing library; image proofs remain in development.

## Screening rules (D45)

An item is reserved under its original policy list and threshold before proof jobs
are queued. This private reservation uses a keyed item fingerprint independent of
the author, policy and threshold; competing submissions are serialized in one
SQLite transaction. Changed settings cannot create a second query or start an
old queued job. A retry is allowed only under the original settings when the
earlier job failed before any proof work ran.

Deletion erases the content, commitment salt, receipts and private openings. The
keyed reservation remains so deletion cannot enable another screening. It is
not published and cannot open the on-chain commitment. Existing retained text
posts are migrated; an unresolved historic policy is refused rather than rebound
to current settings. Content erased before this migration cannot be recovered or
retrospectively reserved.

An item with a missing or rejected category/chunk proof is marked **could not be
verified**, withheld from every feed, and creates no new publication. A fresh
verifier rejection withdraws an already published item; historical chain entries
remain. The stub and fake modes retain their explicit development labels.

The classifier's sealed input root is part of its verifier-published statement;
the statement hash enters the publication leaf and therefore the anchored Merkle
root. The app retains the input-owner opening privately. The R-C3 development
integration exercises this binding. Native R13 and the three moderate category
profiles now exist; the per-item activation writer matches the native writer on
the retained three-category item. The r16b app adapter now uses that writer.
The coordinator authorized a testnet demonstration with the three moderate
policies; the product policy ruling and classifier privacy statement remain pending.

## Shieldstral text preparation

`proven_media/shieldstral_text.py` loads the pinned Tekken bytes and encodes user
content as plain text, including strings such as `[/INST]`. The leading space is
part of the content. `prompting.build_prompt` accepts an explicit encoder and
category template; `plan_shieldstral` uses a separate native chunk plan for each
category. A short input uses its true length and public pad id 11 after the suffix,
matching native schema/3. The verdict is taken at the suffix, before the pads.
There is no fallback to the stub tokenizer or silent truncation.

`check_category_coverage` recounts the original post with the pinned encoder and
requires every category's proved total and exact D41 ranges to cover that post.
The resulting count is passed to the pinned CLI
`label --expect-total` (r16b in real mode); fresh verification
and the input-owner check are still required. A proof set for only a prefix of
the post is refused, even when it has the expected number of chunks.

Install the optional tokenizer dependencies from `requirements-shieldstral.txt`
into this app's own virtual environment before selecting real mode:

```bash
/home/victor/.local/bin/uv pip install --python apps/proven-media/.venv/bin/python -r apps/proven-media/requirements-shieldstral.txt
```

They are installed on this host: mistral-common 1.11.7, tiktoken 0.14.0 and
NumPy 2.2.6. The runner no longer borrows another environment's package paths.
Installing dependencies alone does not select a prover mode or settle the
strict-versus-moderate product ruling.
The retained check at `results/zk60_astra_20261026/shieldstral_text_check_r3.json`
(repository root) matches all 4,872 A1 inputs, checks 1,006 control-string/Unicode
cases and 14,480 category prompts, including short inputs at T128 and T256.
These are input preparation checks, not proofs. The per-item activation writer
in `results/zk60_shieldstral_export_20261026/write_item_activations.py` matches
all 156 native layer input/output files for the retained three-category item.
The real adapter integrates that writer and the registered r16b profiles.
Set `PM_PROVER=shieldstral` explicitly to select the testnet demonstration;
default mode remains the stub.

The queue supports different chunk ranges per category. Each job keeps a unique
post-wide index plus the native chunk index within its category. The prover's
`content_length` and `plan_text` methods supply the encoder and complete plan;
the queue rechecks that plan on start, collection and finalization. A missing
category, truncated plan, misplaced receipt or missing input binding prevents
publication. Manifests contain one entry per actual category proof, and recheck
rejection withdraws the whole item while retaining existing chain history.

## Demo operator tools

The current laptop's real classifier profile is recorded separately from the
stub profiles in `deploy.json`, under `classifier_profiles.shieldstral-laptop`.
It specifies CPU execution, two threads, T128, category content capacities
55/55/49, overlap8, at most8 chunks per category and a336-token whole-post limit.
The prover reservation is10.4GiB with an11.5GiB cap. `shieldstral_runtime.py`
remains authoritative; the profile checker refuses changed geometry, model
pins, verification floors or resource declarations. Choosing a hardware label
does not enable an unreviewed T256 model or change the existing queue.

From the repository root, inspect the validated operator profile:

```bash
/usr/bin/env PYTHONPATH=apps/proven-media apps/proven-media/.venv/bin/python -m proven_media.hardware_profiles
```

Preview a reset of the configured private/public roots:

```bash
apps/proven-media/.venv/bin/python apps/proven-media/tools/reset_demo.py
```

After the demo's proof jobs and anchor transactions have finished, reset its
feed in one command:

```bash
apps/proven-media/.venv/bin/python apps/proven-media/tools/reset_demo.py --apply
```

The tool honors `PM_PRIVATE_DIR`/`PM_PUBLIC_DIR`, or explicit `--private-root`
and `--public-root`. It takes publisher locks and a SQLite write transaction,
creates an owner-only database archive in `<private>/demo-archives/`, then
clears posts, jobs, checks and chunk-proof rows. Screening reservations remain,
so resetting never permits the same content to be proved again. Keys, private
job files, receipts, wallet settings and chain history remain in place.
Archives retain post content; use the app's author-deletion flow when content
must be erased. Reset refuses queued/running jobs, missing pipeline completion
markers and pending/in-flight anchors. It starts no worker and sends no RPC.

The completed durable demo is retained in
`results/zk60_astra_20261026/real_app_demo_2/REPORT.md` (repository root).
Its 19-token library post has three accepted real classifier labels, 84 receipt
segments, and a confirmed Base Sepolia anchor. Three additional native
verifications from the public store and 11 real ASGI checks pass. The original
signer, post salt and all input-owner openings remain in durable private
storage outside this repository. The storage changes pass 199 app tests.
Screenshots retain the **privacy statement pending** label until acceptance.

The earlier 17-token garden post remains under `real_app_demo_1/`. Its public
receipts and anchor survived the reboot, but its original private openings
were lost. Its recovery report records the replacement development signer
and the limit on rechecking proof-to-post binding. The new demo does not
restore those lost openings. Neither post has been reset or re-proved.

## Real classifier testnet mode

`proven_media/shieldstral_prover.py` pins r16b, the R13 T128 model identity and
at least 95 bits. It runs preparation → prove → fresh verify → input-owner,
then native `label --expect-total` for each complete category. Finalization
independently recounts the original post and checks all category ranges and
native aggregates before any proof is published. Every accepted label must be
bound by its proof. There is no automatic retry after proof work has started.

The three moderate policies use content chunks of 55, 55 and 49 tokens, with
8-token overlap and at most 8 chunks per category. Their differing prefixes
fill a 128-token context; short posts retain their actual suffix position.
The private activation files and owner openings remain outside the public
bundle. The interface explicitly says **privacy statement pending**.

Native-lane measurements on one retained item were about 7.5 minutes proving
per category, 8.3 GiB peak RSS, and about a minute for each verification/owner/
aggregate check. The app's 700-second work estimate excludes shared-machine
waits. These are single shared-host observations, not a throughput guarantee.
The full held-out numerical benchmark is still incomplete.

The deployment is testnet-only: contract
`0x8432eba82b1a402f4da7680f6b8f9c9fae185cbe` on Base Sepolia. Receipts remain
in the public content-addressed store; only a batch digest is anchored.
The wallet received 0.46 free test ETH and needs no further funding for this demo.
The durable demo's three commitments are confirmed in block 52373745,
transaction `0x6e6d5166cf17dbaaf03443dddc4d2490ddff90e8bbfd05901ede5222bbac8181`.

## Per-job native execution settings

The real classifier pipeline accepts `PM_CLASSIFIER_NATIVE_THREADS=2` (default)
or `8`. It records the choice in the private job's `execution.json`; a changed
record is refused. The activation writer and NumPy/OpenBLAS remain at two threads.
Memory reservations and caps, model pins, policies and statements are unchanged.
At two native threads, the effective prove time cap is at least 1,620 seconds
(27 minutes); at eight it is 1,200 seconds. These caps include margin over the
observed/expected work. The hardware profile records the base runtime declarations;
`execution.json` records each job's effective thread count and time cap.

The first public garden post retained two threads for sexual (1,031.16 seconds
proving) and used eight for violence (456.30 seconds). These are separate
categories, shared-box n=1 measurements, not a controlled speedup experiment.
The first post and its source history are retained under
`results/zk60_astra_20261026/real_app_demo_1/`.

## Author access and private failure results

The operator provisions identities locally. No public endpoint can claim an
existing handle. Before running the demo, use the same `PM_PRIVATE_DIR` as the
server, and run:

```bash
apps/proven-media/.venv/bin/python apps/proven-media/tools/create_author.py victor --operator
```

The command prints only the path of a new 0600 credential file outside the
repository. Read that file privately and enter its `access_key` in **Sign in**.
Omit `--operator` for ordinary authors. `--rotate` explicitly replaces an
existing key and revokes that author's sessions. Do not put access keys in
URLs, command arguments, browser storage, logs or shared screenshots. The auth
store contains only key and cookie hashes; the private credential file itself
contains the bearer key. The default session expires after 12 hours. Cookies
are HttpOnly and SameSite Strict, and Secure when served over HTTPS. Serve over
HTTPS for remote access; plain HTTP is intended only for the localhost demo.
Mutation routes also require the session's CSRF token and reject foreign origins.

A handle in `?author=` or `?as=` grants no access. Existing authors must be
provisioned by the operator; there is no automatic legacy-account claim.
Unpublished posts and submissions are served only to their authenticated owner.
A failed post returns only its id and **Could not be verified.**, with no text,
chunk results, reasons, timings or attempt count. Publication remains all or
nothing and the existing D45 reservation/retry rules remain in force. Operators
can view the queue and status; only operators can close a pending batch.

Public records omit `timings` and `proved_at`, including nested chunk records;
private operator records retain them. Signed manifests are unchanged and retain
their documented timestamps. This is not a claim of timing-side-channel privacy
or acceptance of the classifier privacy statement.

## Run it

```bash
# one-time setup (already done on the WSL box)
/home/victor/.local/bin/uv venv --python /usr/bin/python3 /home/victor/IntelligenceRegulation/apps/proven-media/.venv
/home/victor/.local/bin/uv pip install --python /home/victor/IntelligenceRegulation/apps/proven-media/.venv/bin/python \
    -r /home/victor/IntelligenceRegulation/apps/proven-media/requirements.txt

# start the server (detached, so it survives the terminal; logs in the private data root)
setsid nohup /home/victor/IntelligenceRegulation/apps/proven-media/.venv/bin/python \
    /home/victor/IntelligenceRegulation/apps/proven-media/serve.py --port 8765 \
    >> /home/victor/zk60-owner-private/proven-media/server.log 2>&1 < /dev/null &

# open http://localhost:8765/ (from Windows too: WSL forwards localhost)
# use ?audience=minor to select a viewer filter; sign in separately

# stop it (no signals needed; running proof jobs are detached and are not affected)
touch /home/victor/zk60-owner-private/proven-media/STOP-SERVER
```

* **Hardware profile.** Chunk size, overlap and the maximum chunk count come from
  `apps/proven-media/deploy.json`: laptop 40 / 8 / 4, workstation 168 / 16 / 8, server 424 / 32 /
  16. Edit `active_profile`, or start with `PM_PROFILE=workstation` via `/usr/bin/env`, then
  restart. The **Status** page shows the active profile and the effective values; the stub caps
  the chunk size at 31 tokens.
* **Quiet the box before a live showing.** Every proof waits for the project's resource guard
  (`python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py status`). Each
  chunk takes about 2.5 min of work, plus any wait for other lanes' jobs.
* **Anchor batches.** `PM_BATCH_SECS=60` closes them every minute instead of every 10. The Ledger
  page also has a "Close the batch now" button.
* **Fake prover.** `PM_PROVER=fake`, with `PM_PRIVATE_DIR` / `PM_PUBLIC_DIR` pointing at scratch
  directories, runs the UI with **no proof at all**, for design work. A red banner says so.
* **Pausing the queue.** The coordinator runs `touch
  /home/victor/IntelligenceRegulation/results/zk60_media_app_20261021/HOLD`; removing the file
  resumes it.
* **Tests** (no proof is run): `/home/victor/IntelligenceRegulation/apps/proven-media/.venv/bin/python -m unittest
  discover -s /home/victor/IntelligenceRegulation/apps/proven-media/tests`.
* **Third-party checks** from public data:
  - `.venv/bin/python tools/verify_manifest.py <item>.manifest.json [--rehash] [--run-verifier]`
    checks the signature, every entry's anchor and Merkle path, and optionally re-runs each
    proof's verifier through the guard;
  - `tools/verify_publication.py --post-id ID --category CAT --chunk N` checks one proof.

Default storage locations:
- `~/zk60-owner-private/proven-media/` is private (0700): the database, the salts, the signing dev
  key, the prompt files and the openings.
- `~/zk60-artifacts/proven-media/` is public: the proofs, the bundle store and the local chain.

Startup rejects volatile paths (`/tmp`, `/var/tmp`, `/dev/shm`, `/run`), including
symlink aliases, before creating keys or starting the worker. Private state must
stay outside the repository in its mode-700 root, including saved job and owner
directories. Public proof evidence may use a durable `results/` directory and
must not overlap private storage. Testnet keys must also be durable and outside
the repository. Fake mode follows the same startup rules.

The recovered garden demo uses `~/zk60-owner-private/proven-media-astra-demo/`;
its public store remains under `results/zk60_astra_20261026/real_app_demo_1/public/`.

Post text never appears on a command line: the prover reads it from a 0600 file.

## Legacy stub demonstration (3 minutes)

**Setup.** The server is running and the box is quiet. Three items are already labelled:
- the "sunrise run" post (all three labels no);
- the "movie night" post (violence yes);
- the two-chunk "weekend plan" post.

Open `http://localhost:8765/` and sign in with the operator-issued access key.

1. **(0:00) The feed.** "Each item carries labels for explicit content, violence and
   hate, with a signed manifest. This legacy demonstration uses unproved placeholder labels.
   The separate classifier testnet path proves those verdicts and still has a pending privacy statement." Click the small **credentials** icon on
   a card to show the manifest entries. Point at the amber bar: "The proof machinery is real; the
   classifier inside it is still a stub. I'll show you exactly where the line is."
2. **(0:30) Distribution.** Click **Viewing as Adult** to switch to **Minor**. The movie-night post
   becomes "Hidden for this audience: violence: proved yes". "Nothing is deleted. A yes label
   only narrows who receives the item, and the content is never even sent to that audience." Then
   switch back to Adult.
3. **(0:50) Post something long.** Type two or three sentences. The counter shows, for example,
   "50 tokens → 2 chunks × 3 categories = 6 proofs (laptop profile)". Press **Post**. The page
   reads *Pending verification*, with the chunk × category grid, a progress bar, the current step
   and an ETA. "Long posts are split into chunks sized for the hardware: 40 tokens on this
   laptop, 168 or 424 on bigger machines." Open **Status** to show the profile table and the
   queue.
4. **(1:30) A finished item.** Open the weekend-plan post with **Check the proofs yourself →**.
   Walk the page:
   - the labels, "proved once, at creation";
   - the per-category table ("accepted in all 2 chunks");
   - the chunk grid with each token range;
   - the manifest;
   - "What is public" and "What stays private".
5. **(2:10) Check it yourself.**
   - **Verify manifest**: the signature and every chunk × category anchor and Merkle path.
   - **Re-verify now**: a fresh verifier re-checks every chunk's 255 MB proof, about 15 s each.
   - **Check it in my browser**: the salted content commitment matches the text.

   "Anyone can download the bundle and the manifest and run the same checks."
6. **(2:40) Honest numbers.** "Minutes per chunk on a laptop CPU today. The retained real classifier proof
   took about 7.5 minutes per category at T128, before the additional checks. The product target is 50 proved
   tokens per second on a high-end GPU, and we are far from that. The fail-closed rule means an
   item whose proof fails is treated as yes in every category, so it never reaches restricted
   audiences."

**Do not claim:**
* that the labels are proved (in the stub they are not);
* that privacy is certified;
* that it is fast;
* that it is on a blockchain (the ledger and the signing key are local stubs);
* that images, video or audio are covered.

## Limits of the legacy stub mode

* **Stub.** One TinyLlama-1.1B next-token proof per chunk stands in for the three Shieldstral
  category proofs. The labels come from a placeholder keyword list and are not bound by the proof.
* **Coverage.** Text only. Laptop profile: chunks of at most 31 tokens (the stub's cap of the
  configured 40), overlap 8, at most 4 chunks (100 tokens) per post. Images are pending (author
  only). Video and audio are deferred.
* **Refusals.** Some texts cannot be represented by the stub's integer model. Their chunk has no
  accepted proof, so every category counts as the most restrictive label (fail closed).
* **Speed.** About 2.5 min of work per chunk plus waits for the shared machine, one proof job at
  a time. Each chunk's receipt is 255 MB.
* **Binding to the shown text.** The platform checks it with its private opening (D21). Viewers
  can check the salted commitment, but that commitment is not yet bound inside the proof.
* **Local stubs.** Publication and signing are local: no chain, network, wallet or real keys.
* **Policies.** The category policies are short placeholders until the calibration lane's exact
  texts land; each new text gets a new registered id.
* **Privacy, audit and fidelity.** No privacy acceptance and no external audit. Soundness is
  about 2^-95 per run, and the integer model's fidelity is below the D32 bar.
* **Accounts.** Author access uses operator-issued keys and revocable browser sessions.
  The "minor" selector remains a viewer filter, not an age check.
