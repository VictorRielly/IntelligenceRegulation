# Proven Media (local demo)

Proven Media is a media feed in which every item carries **proved content labels**. At creation,
the item is classified once per category: **sexual / explicit**, **graphic violence** and **hate /
harassment**. Each category has one fixed policy and one threshold. Every label, yes or no, is
published with its proof and travels with the item in a **signed proof manifest**. The platform
uses the proved labels to decide **who receives the item**: minors never receive an item unless it
is proved "no" in all three categories. Long items are split into **chunks**, and each chunk is
proved separately per category. The chunk size depends on the hardware profile. (D37, D38, D39,
D41.)

**What runs today: a demo stub.**
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

# open http://localhost:8765/?as=victor            (from Windows too: WSL forwards localhost)
#      http://localhost:8765/?as=victor&audience=minor   to start as a minor viewer

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

Data lives outside the repository:
- `~/zk60-owner-private/proven-media/` is private (0700): the database, the salts, the signing dev
  key, the prompt files and the openings.
- `~/zk60-artifacts/proven-media/` is public: the proofs, the bundle store and the local chain.

Post text never appears on a command line: the prover reads it from a 0600 file.

## Demo script (3 minutes)

**Setup.** The server is running and the box is quiet. Three items are already labelled:
- the "sunrise run" post (all three labels no);
- the "movie night" post (violence yes);
- the two-chunk "weekend plan" post.

Open `http://localhost:8765/?as=victor`.

1. **(0:00) The feed.** "Every item here carries proved content labels: explicit, violence and
   hate. Each label, yes or no, comes with a zero-knowledge proof made once, when the item was
   posted. Anyone can check it, and the proof never reveals the item. The labels travel with the
   item in a signed manifest, like content credentials." Click the small **credentials** icon on
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
6. **(2:40) Honest numbers.** "Minutes per chunk on a laptop CPU today. The classifier proof is
   estimated at 3–5 minutes per category of a 64-token chunk. The product target is 50 proved
   tokens per second on a high-end GPU, and we are far from that. The fail-closed rule means an
   item whose proof fails is treated as yes in every category, so it never reaches restricted
   audiences."

**Do not claim:**
* that the labels are proved (in the stub they are not);
* that privacy is certified;
* that it is fast;
* that it is on a blockchain (the ledger and the signing key are local stubs);
* that images, video or audio are covered.

## Known limits

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
* **Accounts.** None: authors are matched by handle, and "minor" is a viewer toggle, not an
  age check.
