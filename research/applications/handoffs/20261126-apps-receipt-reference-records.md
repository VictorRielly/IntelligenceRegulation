# A27: hash and size records the project already keeps for one classifier receipt

2026-11-26. Done by the Claude co-coordinator as a local count (no research agent, no web search). Triage material, not
a work order.

## Question

Study A23 found that the Content Credentials specification (C2PA 2.5) lets a manifest point by hash to data kept outside
the file. Which of the values such a reference needs does the project already record for a classifier receipt, and what
would one reference to the whole receipt need, against one reference per file?

## What was read and how

- Record files of one qualification run of the installed app, written by the applications lane on 2026-11-25, in
  `results/zk60_astra_20261026/app_composed_native_20261122/qualification-20261125T070919.014403Z/`: `manifest.json`,
  `RESULT.json`, `downloaded_store.json` and the three `<category>.publication.json` inventories. **These files are on
  the project's machine only**: `git ls-files` shows 0 tracked files under `app_composed_native_20261122`.
- The receipt files themselves, in the app's public scratch store outside the repository: read as bytes and hashed with
  SHA-256 by the script (2,008,684,416 bytes read). Nothing was written there. No prover, verifier or app code was run.
- The field list of a hashed external reference and the allowed hash list, in my own copy of the C2PA 2.5 specification
  (the copy downloaded for the check of A23).
- Script: `20261126-apps-receipt-reference-records.py`; its output: `20261126-apps-receipt-reference-records.out.txt`
  (no clock in the output). On a machine without the records it says the directory is absent and exits with code 2.

Each inventory is a single line of JSON, so "file:line" is line 1 for every field in it; the field name is given instead.

## Findings

1. **One receipt is 28 files, and every one has a recorded SHA-256 and a recorded byte length.** [COUNTED,
   `sexual.publication.json`:1, field `segments`] 28 entries, each with exactly the keys `bytes`, `file`, `sha256`;
   28 of 28 hashes are 64 hex characters, 28 of 28 lengths are positive integers, and the 28 hashes are distinct. The
   lengths sum to 669,561,472 bytes [DERIVED by addition]; the smallest file is 1,415,192 bytes and the largest
   25,570,824. The inventories of the other two categories have the same counts and the same sum, so the item of this
   run has 84 files and 2,008,684,416 bytes.
2. **The files in the store match the records.** [COUNTED by re-hashing] 84 of 84 files are present, 84 have the
   recorded length and 84 have the recorded SHA-256.
3. **The app's signed manifest already holds one digest per receipt that fixes all 28 files.** [COUNTED,
   `manifest.json`:36, :73, :110, field `bundle.manifest_sha256`] For 3 of 3 categories that value equals the SHA-256 of
   the inventory file's bytes. The inventory is 4,298 bytes (4,300 and 4,296 for the other two) and lists the 28 hashes
   and lengths. So a 32-byte digest that the project already records fixes the 669,561,472 bytes of a receipt through
   two hash steps (manifest to inventory, inventory to files). The manifest carries an Ed25519 signature; its issuer
   name reads "Proven Media (local demo publisher, DEV KEY)".
4. **What the records lack is a web address, and for two of three routes a length or a digest.** The specification
   defines the reference as `"url": ext-url-type, ; http/https URL`, an `alg` ("Unlike alg fields in other types, this
   field is mandatory here."), a `hash`, and optional `dc:format` and `size` (section 9.4.2.2). SHA-256 is allowed:
   "The allowed list is: SHA2-256 ("sha256"); SHA2-384 ("sha384"); SHA2-512 ("sha512")."
   - Route A, one reference per file: 28 references; hash on record 28 of 28, length 28 of 28, http(s) URL 0 of 28.
   - Route B, one reference to one archive of the 28 files: no digest and no length of such an archive is on record
     (the inventory's field `segments_json_sha256` is null). The sum of the lengths is not an archive's length, because
     an archive format adds its own framing.
   - Route C, one reference to the inventory: the digest is on record in the signed manifest; a length is not (the
     manifest's `bundle` has the keys `manifest_sha256`, `manifest_uri`, `receipt_uris` only), but `size` is optional
     and the file is 4,298 bytes; http(s) URL 0.
   Every location in these records is a name of the form `local-cas://sha256/<digest>`; the string "http" occurs 0
   times in the three inventories.
5. **The inventory is small enough to travel inside a manifest.** [DERIVED] 4,298 / 669,561,472 is 1 part in 155,784.
   It is far below the two default limits of the open validator read in A23 (10 MiB for a fetched manifest, 32 MB
   decompressed). Not built.

## Limits of these records

- This run's own `RESULT.json` records `"passed": false` (line 2) with `"guard_exit": 75` (line 117). 75 is the resource
  guard's code for a job it stopped (memory floor, RSS cap, VRAM cap, lost GPU telemetry, time limit or SIGTERM,
  `docs/zkmatrix-poc/ZK60_RESOURCE_PROTOCOL.md:88-89`); which one applied, and at which step, was not examined here.
  The same file records `public_fixture_only: true`. `downloaded_store.json` records `accepted: true` and 3 of 3
  `publication_matches` checks true. The later guest check that names this run as its source
  (`guest-20261125T073308.630547Z/RESULT.json`, field `source_pilot`) records `passed: true`.
- `manifest.json`:172 carries the profile's note: "Public content only; privacy not claimed. W16R2 development
  candidate; not production."

## What a product would have to build

- A public host with http(s) addresses for the inventory and the 28 files, kept for as long as a label is shown.
- A choice of route. With route C a standard validator that did fetch the reference would check the 4,298 bytes of the
  inventory only; the step from the inventory to the files, and the proof check itself, belong to the project's own
  reader.
- An assertion of its own for the verdict (A23 found no standard one), and a production signing key in place of the
  development key in these records.

## Test (confirm or kill)

- Done here: the chain manifest, inventory, files holds on the retained records (3 of 3 digests, 84 of 84 files).
- Not done: with the open C2PA tool, build a manifest whose hashed external reference carries a URL, `sha256` and the
  inventory's digest; validate it with the URL reachable and unreachable; fetch the files by the inventory and run the
  app's publication check on them. Kill route C if the tool refuses a reference to a JSON object that is not a C2PA
  structure. This needs the tool installed, which is the owner's decision, and it is the same build as the test of A23.

## Not verified

- The manifest's signature was not checked by me, and which bytes it covers was not read. The records
  (`offline_signature.json`, `downloaded_store.json`) say it was accepted.
- No proof was verified in this count. It concerns hashes and lengths only.
- Whether the inventory's format (`zk60.publication-manifest/1`) is meant to stay fixed.
- How viewer applications treat a third-party assertion or an external reference (queued as A26).
