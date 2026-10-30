# Open release plan (D48): making the whole stack public, safely

Prepared 2026-10-30 06:15 UTC. Nothing has been published, pushed or changed. This
is the readiness check D48 asked for. The inventories behind every number are in
`results/zk60_open_release_20261030/` (start with `index.json`).

Labels: **[MEASURED]** a scan or count was run; **[READ]** read in a local file;
**[INFERRED]** my reading, not checked.

## In one paragraph

The public tree can be about **1,300 files and 47 MB** of code, specs, docs and
small evidence. The scan found **no private keys, tokens or seed phrases** in it.
The real secrets (the testnet key, the app keys, owner openings) sit outside it
and were never committed. Every dependency licence is permissive or harmless; none
blocks the release. Model weights stay out: fetch-and-convert scripts go in instead.
Three things need work before your go. First, the tools that turn real models into
integer exports still live in lane result folders, with this laptop's paths written
into them. Second, eight documents carry personal notes (funding, the new job, the
laptop) and must be edited. Third, a stranger's clean build has not yet been run.
Publish from a **fresh repository**, not the private history.

## Decisions for you, up front

1. **Licence.** My recommendation: **"MIT OR Apache-2.0"** (dual), which is the
   norm in Rust and zero-knowledge work (arkworks, Plonky3, Halo2). Users who take
   Apache-2.0 get its explicit patent grant. Projects that cannot take Apache
   (GPLv2-only) can still use the code under MIT. That gives the widest use, which
   is D48's aim.
   - The fallback is **Apache-2.0 alone**, if you want the patent grant (and its
     patent-retaliation clause) to bind every user. RISC Zero does this.
   - **MIT alone** is not recommended: it gives no explicit patent grant.
   - One licence for the code and the docs keeps things simple.
2. **Timing.** I recommend releasing as soon as the five engineering items below
   are done (about 1 to 2 days of agent work [INFERRED]). Release before your new
   job starts, on the same day as the IACR ePrint preprint. Publishing first keeps a
   new employer's invention-assignment terms from reaching the work, and gives the
   construction a public date as prior art. That is a point for your attorney, not
   legal advice.
3. **Fresh repository or scrubbed history.** I recommend a **fresh public
   repository** built from the curated snapshot. Keep
   `github.com/VictorRielly/IntelligenceRegulation` private as the full record, and
   never flip it to public. The reasons are under "Git history".
4. **Smaller choices.**
   - The repository name: the current name, or a technical one such as
     `zk-private-inference`.
   - Whether the README keeps the governance manifesto and your email.
   - Whether to include your two PDFs: the lattice protocol report and "Zero
     Knowledge AI Governance Framework". Please confirm both are yours.
   - Whether to publish the 125M frugal-lm weights (yours) separately.

## What goes public [MEASURED: `candidate_summary.json`]

| Part | Source | Files | Size |
|---|---|---|---|
| Reference prover: `hashline/`, `zkp-core/`, `private-block-kernel/`, `private-block-kernel-shaped/` | the frozen token round 16b copy, plus main-tree READMEs and design notes it lacks | 294 | 8.5 MB |
| Test fixtures the prover tests read (`results/…`: 4 block receipts, statements) | the same frozen copy | 20 | 12.3 MB |
| Privacy gate tools (`privacy-gate/`) | `ops/zkp-mvp/gate-tinyllama/frozen_v23` | 122 | 3.7 MB |
| RISC Zero route: `zkvm-block/`, `zkvm-model/`, `zkvm-native-tools/`, `private-model-kernel/` | main tree | 59 | 0.4 MB |
| Earlier lattice / zkMatrix line: `zkmatrix-rs/`, `zk_matrix/`, `zk_matrix_fast/` (C source only), `zk_lattice/` | main tree | 62 | 5.4 MB |
| Python tools and tests: `scripts/`, `tests/` | main tree | 181 | 3.9 MB |
| Model export and calibration tools (`tools/model-export/`) | five lane result folders (top-level `.py` only) | 93 | 0.6 MB |
| App: `apps/proven-media/` without `.venv`, `.testnet-private`, caches | main tree | 77 | 0.7 MB |
| Docs: `docs/zkmatrix-poc/` minus 14 excluded files and the third-party PDFs; demo page | main tree | 353 | 11.2 MB |
| Curated evidence (`evidence/`): freeze note, manifest, binary build record, soundness reviews R13 / R14 / R16, privacy reviews, gate manifest, first-post publication manifest and fresh-process verifications, model pins | `results/…` | 33 | 0.5 MB |
| Root: `README.md` (rewrite), `ZKMATRIX_REVIEW_NOTES.md`, `.gitignore` | main tree | 3 | 0.03 MB |
| **Total publishable** | | **1,297** | **47.3 MB** |

Each file has a decision in `candidate_files.tsv`:
- **include:** 1,155 files.
- **redact:** 8 files; publish only after the named edit.
- **review:** 134 files, read once before publishing. These are 41 agent-lane
  review notes and the 93 lifted tools.
- **exclude:** 19 files.

**The reference implementation** [READ]:
- **Tree:** the token lane's **round 16b** frozen copy,
  `results/zk60_token_io_r1_20261017/frozen-r16b/`. It holds 301 files; its
  manifest list sha256 is `04d94bc0…`. It was frozen 2026-10-29 10:50 UTC.
- **Binary:** `cli/zk60_classify.r16b.release.bin`, sha256 `dfb8025e…`. It was built
  with rustc 1.97.1, CPU only, and proved the first real post.
- **Review status:** round 16 was accepted with fixes on soundness (REVIEW_R16).
  Round 16b's own check was still owed when it was frozen.
- **Later rounds:** round 17 (test-only changes, unreviewed) and round 18 (in
  progress) sit on top. At release time, take the newest round that is frozen and
  reviewed, and re-run the inventory with that path.
- **Privacy gate:** the reference version is **v23**.
- **The main tree is out of date:** its `hashline/` is older and lacks 137 files.
  Its `zkp-core/` differs in 6 source files. Do not publish the main-tree prover.

## What stays out

The full list, with reasons and sizes, is in `excluded_areas.json`:
- every `target/` directory;
- `.git` (14.6 GB);
- `results/` bulk (208 GB);
- `ops/` frozen and scratch trees, and the coordination files;
- `research/` (161 experiments; one of them vendors a third-party crate);
- `local-models/` and `~/models`;
- the root `PROGRESS*` ledgers, `CLAUDE.md` and `.claude/`;
- the `codex-audit-*` reports, early prototypes, and the music side project.

Personal and business material:
- `results/zk60_funding_20261028/`: every funding draft, plus
  `patent/PROVISIONAL_DISCLOSURE_DRAFT.md`;
- `docs/zkmatrix-poc/ZK60_FUNDING_PLAN.md`;
- the remote-access, hardware and unattended-work docs;
- the agent team, queue and coordination docs.

No resume and no Telegram inbox or spool exist inside the repository [MEASURED,
name search].

Third-party PDFs: `zkMatrix.pdf` is ePrint 2024/161, and `docs/zkmatrix-poc/references/`
holds the LatticeFold, LatticeFold+ and Neo ePrints. Link to these papers; do not
redistribute them.

`codex-audit-*` are audit reports Codex wrote for this project, so they are our own
work, not third-party code. They are historical, and they can go into `docs/history/`
later if wanted.

## Secrets and private material [MEASURED: `secret_scan_*`, `name_flags.json`]

**Scan coverage:** all 1,316 listed files. The rules looked for:
- PEM, PGP and SSH private keys;
- GitHub, Anthropic, OpenAI, AWS, Google, Slack, Hugging Face and Telegram tokens;
- RPC URLs that carry keys, JWTs, and secret assignments;
- 64-hex values next to key words, and unlabelled `0x`+64-hex values;
- runs of 12 or more BIP-39 words;
- emails, phone numbers, IP addresses, home paths and personal keywords.

No value is written anywhere: file and line only.

**Results:**
- **No private key, token, seed phrase or key-like hex value was found in any
  candidate file.**
- 53 hits in total, all of them harmless or in excluded files:
  - **1 "high":** faucet URLs, a false positive, in an excluded doc.
  - **20 info:** public testnet addresses (the contract, the deployer and the
    bridge), 15 of them in publishable files. These are public on-chain anyway.
  - **Low, real:** your email in the README manifesto (1). An SSH public key with
    `victor@MSI` (3) and Tailscale notes (5), all in the excluded remote-access doc.
  - **Low, false positives:** phone-like numbers that are matrix sizes (14),
    `user@1000.service` (5), and kernel version numbers (3).
- **Home paths:** `/home/victor` appears 545 times in 183 files, and a Windows-user
  path twice. This is low risk (it only leaks a username), but it breaks a
  stranger's build, so it gets parametrised (item E2).

**The real secrets, all outside the tree:**
- `apps/proven-media/.testnet-private/` holds 12 files: a throwaway Sepolia key,
  the publisher and app signing keys, the app and auth databases, and the recovery
  state. They are gitignored and were never committed [MEASURED].
- `~/zk60-owner-private` (4 entries) is outside the repository and was never
  opened.

## Git history [MEASURED: `history_scan.json`]

**Size:**
- 2,127 commits on 139 refs;
- 59,441 different paths ever committed: 31,409 under `results/`, 19,503 under
  `ops/`, 7,390 under `research/`;
- 27,289 blobs, 23.1 GB uncompressed (the largest is 525 MB);
- `.git` is 14.6 GB on disk.

**What the history holds:**
- **3 funding documents:** `results/zk60_funding_20261028/GOVERNMENT.md`,
  `GRANTS_PHILANTHROPY_ECOSYSTEM.md` and `INVESTORS_PUBLICATION.md`. They are on the
  snapshot branch, which is already pushed to the private origin.
- Agent ledgers.
- Commit messages that discuss private rulings.

**What the secret search found:**
- In source and docs, across all refs: one false positive (the prose "the table is
  a mnemonic").
- In text files under `results/`, `ops/` and `research/` (md, txt, py, sh, toml,
  yaml and similar): nothing.
- Never committed: `.testnet-private`, `.claude/`, keys, owner openings.
- Not searched: the json, log and binary blobs under those three folders.

**Why a fresh repository:**
- Scrubbing would mean filtering 139 refs and 23 GB of blobs.
- Even after that, the commit messages would remain.
- Publishing the old repository would publish the funding documents and every
  agent ledger.
- A fresh repository loses no code.
- For dating, cite the private commit and the manifest hash in the README's
  provenance note. The ePrint gives the public date.

## Third-party licences [MEASURED: `licence_summary.json`]

**Rust:** 371 distinct crates from 11 `Cargo.lock` files, read offline from the
cargo registry.
- 349 are permissive: MIT or Apache-2.0 (mostly dual), plus BSD, ISC, Zlib,
  Unlicense, CC0 and Unicode.
- 20 are this project's own path crates.
- **`option-ext` 0.2.0 is MPL-2.0.** It reaches the RISC Zero route through the
  `dirs` crate. MPL is file-level copyleft and is fine as an unmodified dependency.
- **`hermit-abi` 0.5.2** is not in the local registry. It only builds for the
  Hermit OS target, and its upstream licence is MIT OR Apache-2.0 [INFERRED].
- RISC Zero: all 13 `risc0-*` crates are Apache-2.0 [READ].
- `cudarc` (the GPU path) is MIT OR Apache-2.0. The CUDA toolkit is not
  redistributed.

**Python:** the app's virtual environment has 51 packages, all permissive except
two. `certifi` is MPL-2.0, and `pycountry` is LGPL-2.1, pulled in under
`mistral-common`. Both are installed by pip, not shipped. The system packages the
scripts use (numpy, scipy, torch, tokenizers, safetensors, transformers) are BSD
or Apache.

**Vendored code:** none was found. Every "ported from" or "copied from" comment
points to the project's own files [READ, spot-checked].

**Licence blockers: none.**

## Models [READ: `model_licences.json`]

| Model | Licence | Ship weights / exports? |
|---|---|---|
| Shieldstral-1.0-3B (classifier) | Apache-2.0 (model card) | No mirror: it would bypass Mistral's access form. Ship the pinned fetch (revision 003ec7e2 + sha256) and the export tools. |
| Meta-Llama-3-8B (8B proofs; NousResearch mirror @ 315b2009) | Meta Llama 3 Community License (custom) | No. Exports and tables are derivative works that would carry Meta's conditions. Ship the scripts and show "Built with Meta Llama 3" next to the 8B results. |
| TinyLlama-1.1B-Chat @ fe8a4ea1 | Apache-2.0 (card only; the tokenizer derives from Llama 2) | No. Use the existing pinned fetch script. |
| frugal-lm 125M | Yours (FineWeb-Edu data needs attribution [INFERRED]) | Optional, your call. Not needed by the tests. |

**One honest limit for the README:** a stranger who wants to check a published
classifier receipt must fetch the 7.7 GB Shieldstral weights and run the export,
because the verifier rebuilds its tables from the pinned weights (P1).

## Engineering work owed before the go

- **E1. Pin the reference round.** Use 16b, or the newest round that is frozen and
  reviewed. Then re-run `build_inventory.py`.
- **E2. Lift and parametrise.**
  - Move the 93 export and calibration scripts out of `results/zk60_shieldstral_*`,
    `zk60_8b_calibration_*` and `zk60_1b_*` into `tools/model-export/`.
  - Replace the hard-coded paths with environment variables (`ZK60_REPO`,
    `ZK60_MODELS`, `ZK60_ARTIFACTS`). Today the app's `config.py` and
    `shieldstral_runtime.py`, and some prover tests, name `/home/victor/…` and lane
    result folders.
- **E3. Edit and read.**
  - Redact the 8 files:
    - `ZK60_DECISIONS.md`: the personal parts of D43, D46 and D47;
    - `MVP_STATUS.md`: the crash and Windows notes;
    - `START_HERE.md`;
    - the three `RULINGS_FOR_VICTOR` files;
    - `ZK60_RESOURCE_PROTOCOL.md`;
    - `README.md`.
  - Read the 134 review files.
- **E4. New files.**
  - `README.md` (outline below);
  - `LICENSE-MIT` and `LICENSE-APACHE` (or `LICENSE`);
  - `NOTICE`, which credits Shieldstral, TinyLlama and Llama 3, if any of their
    material ships;
  - `SECURITY.md`: research prototype, not audited, how to report;
  - `CITATION.cff`.
- **E5. Clean-room check.**
  - Copy the snapshot into an empty directory.
  - Build hashline with `cargo build --release --locked`. This needs registry
    access the first time.
  - Run the native suite: 890 s and a peak of about 7.9 GiB on round 16b, so it
    goes through the guard as a `cpu` job.
  - Run `python3 -m unittest discover -s tests`.
  - Re-scan the snapshot.
  - This has **not been run** [MEASURED: not attempted; the box was busy].

## The README a stranger needs (outline)

1. **What it is.** Zero-knowledge proofs that a public-weight LLM computed a stated
   result. P1 hides the inputs, outputs and activations; the weights are public.
   The prover is a Rust hash-based prover over the Goldilocks field.
2. **What works, with numbers and scope.**
   - A real Shieldstral-3B classifier verdict: about 456 s to prove with 8 threads,
     an 848 MB receipt, 36 s to verify, a 96-bit floor.
   - TinyLlama next-token proofs.
   - 8B next-token proofs.
3. **What does not work yet.**
   - The classifier privacy statement is a draft.
   - Privacy acceptances D33 and D36 cover named binaries only.
   - The zkVM route's 97-bit level and Groth16 trusted setup (D3, D4).
   - No external audit.
4. **Quick start (CPU, no model).**
   - Build.
   - Run the tests.
   - Run the synthetic demo (`scripts/zk60_p1_demo.py`).
5. **Check a published receipt.** Fetch the model, export it, verify the receipt.
6. **Map of the tree, and the security documents** (soundness reference,
   decisions register, privacy statements).
7. **Licence, how to cite, contact.**

## Checklist to publication (Victor runs the publishing steps)

1. Rule on decisions 1 to 4 above.
2. Agents do E1 to E5. Each step is checked against `candidate_files.tsv`, and the
   private tree is not modified.
3. Build the snapshot from the reviewed list:

   ```sh
   python3 -c "import csv,os,shutil; R='/home/victor/IntelligenceRegulation/'; D=os.path.expanduser('~/ir-public'); [(os.makedirs(os.path.dirname(D+'/'+r['public_path']), exist_ok=True), shutil.copy2(R+r['source_path'], D+'/'+r['public_path'])) for r in csv.DictReader(open(R+'results/zk60_open_release_20261030/candidate_files.tsv'), delimiter='\t') if r['decision'] != 'exclude']"
   ```

   Then apply the E3 edits and the E4 files inside `~/ir-public`.
4. Re-scan it. Expect zero critical or high hits:

   ```sh
   python3 -I results/zk60_open_release_20261030/build_inventory.py --scan-tree ~/ir-public ~/ir-public-scan.tsv
   ```

5. Run the E5 clean-room build and test in `~/ir-public`.
6. Create the repository. This step publishes and cannot be undone:

   ```sh
   git -C ~/ir-public init -b main
   git -C ~/ir-public add -A
   git -C ~/ir-public commit -m "Initial public release"
   gh repo create VictorRielly/<name> --public --source ~/ir-public --push
   ```

7. Tag `v0.1.0` and attach the release assets with a `SHA256SUMS` file:
   - a binary built from the tag (its hash will differ from `dfb8025e…` because
     the build path is baked in);
   - the first post's three receipts and statements;
   - the 84 public segments (2.55 GB).

   Optional: a Zenodo DOI through the GitHub integration.
8. Submit the ePrint the same day. It cites the repository and the tag.

## Could not determine

- Whether the existing GitHub repository is private. There was no network access.
- Whether a fresh clone builds and passes. E5 was not run.
- The json, log and binary blobs under `results/`, `ops/` and `research/` in the
  history were not content-searched.
- People's names in coordination text: only a keyword scan was done. Reading the
  "review" and "redact" files covers this.
- Whether D33 and D36 extend to round 16b. The register records them up to
  frozen-r11.
- The authorship of the two root PDFs.
- The FineWeb-Edu licence (not stored locally) and the `hermit-abi` licence.
- **For your attorney:**
  - copyright in AI-written code (it does not block an open licence);
  - the new employer's terms;
  - whether US export rules for public cryptographic source code
    (EAR 742.15(b)) need a one-time notice.

## Status, 2026-10-30 08:30 UTC: prep done in staging (E1 to E6)

`/home/victor/ir-public` holds 1,428 files (about 64 MB); nothing is published. Logs and decisions are in
`results/zk60_open_release_20261030/prep/` (`PROGRESS.md`, `E2_NOTES.md`, `e6_decisions.tsv`,
`removed_tests.tsv`).
- **Clean-room build** (offline, from the local cargo cache): the prover builds. Its native suite passes, 936
  passed / 0 failed / 68 ignored, the same as round 16b. It peaked at 10.35 GiB, so it runs as cpu with need 11 /
  cap 12 [MEASURED].
- **Python suite in staging:** 1,223 tests, 0 failures, 0 errors, 151 skipped. 41 of the skips are new guards
  naming the development input each test needs. 59 test methods that only make sense inside the private repo
  were removed from the public copy, each recorded [MEASURED].
- **Scan:** 0 critical, 0 high. The P1 demo passes with 6 of 6 controls.
- **Owed before the go:**
  - Victor's choices: licence, name, contact, manifesto, PDFs, 125M weights, credit line.
  - **E7, the `derive.rs` checkpoint path:** an env-var default for `DEFAULT_CHECKPOINT`, so a stranger can
    verify a Shieldstral receipt with the model anywhere. It goes in the next reviewed token round, after round
    18, with the gate's re-pin and refreeze; exact change in `prep/E2_NOTES.md`. The release can ship before E7
    with the limit stated in the README.
  - **Re-copy:** if round 18 is frozen and reviewed before the release, switch the reference round (steps in
    `prep/E2_NOTES.md`).
- **Update 13:05 UTC.** E7 is in token round 19 (frozen, ACCEPTED WITH FIXES: `REVIEW_R19.md`). Round 19b now adds
  the required wrong-checkpoint test (R19-1) and the scans' fail-closed fixes. After 19b and the gate's re-pin, switch
  the staging reference from 16b to 19b (steps in `prep/E2_NOTES.md`). **README note for strangers:** the verifier
  accepts only a regular file equal to the pinned Shieldstral checkpoint, so a Hugging Face cache symlink is refused.
  Copy the file into `$ZK60_MODELS/shieldstral-1.0-3b/snapshot-003ec7e2/model.safetensors`.

## Status, 2026-10-30 17:00 UTC: staging switched to round 19b + gate v24; ready for Victor's decisions

`/home/victor/ir-public`: 1,437 files, 65 MB. Reference: token round 19b (`frozen-r19b`, reviewed, accepted with
low fixes) and privacy gate v24.
- **Clean-room results:**
  - offline build: passes;
  - native suite: 971 / 0 / 71 (713 s, peak 10.2 GiB);
  - Python suite: 1,223 tests, 0 failures, 151 skipped, every status unchanged;
  - P1 demo: passes, 6 / 6 rejection controls;
  - scan: 0 critical, 0 high.
- **README:**
  - anyone can verify a Shieldstral receipt by setting `ZK60_MODELS`, with the checkpoint copied as a regular file;
  - a stranger still needs the verifier copy of the integer export, since the export tools are not yet
    self-contained;
  - privacy statements cover named binaries only: D33 and D36 are accepted, and the Shieldstral v3 is a draft.
- **This plan file is excluded from the public tree** (personal notes). The old 16b staging is kept at
  `~/ir-public-r16b` and can go.
- **Still owed:**
  - Victor's choices: licence, name, contact, manifesto, root PDFs, 125M weights, credit;
  - he then runs checklist steps 6–8 (create the repo, tag, assets).

