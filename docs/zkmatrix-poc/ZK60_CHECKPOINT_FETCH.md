# Exact checkpoint selection and source evidence

`scripts/zk60_checkpoint_fetch.py` fetches a public, ungated Llama checkpoint
at an immutable provider revision and verifies its source bytes. It then runs
the strict, bounded safetensors importer in `scripts/zk60_1b_checkpoint.py`.
This is raw-checkpoint preparation; it does not calibrate a model or produce
a cryptographic proof.

## Usage

Supply the provider's complete 40-character lowercase revision SHA, not a
branch name. Use fresh output/evidence directories for a different model or
revision. Repeating the same invocation verifies and reuses cached LFS shards.

```sh
python3 scripts/zk60_checkpoint_fetch.py ORGANIZATION/MODEL REVISION_SHA \
  --output /path/to/checkpoint --evidence /path/to/evidence --metadata-only
```

`--metadata-only` downloads and verifies the configuration and index, selects
the required shards, and records their provider pins. It does not download
weight payloads or mark those weights as locally verified. Git-stored shards
have a Git blob pin at this stage; their SHA-256 is filled only after their
bytes have been fetched and verified. Remove `--metadata-only` to fetch the
weights and run the actual importer. Large downloads and inventory passes
remain subject to the [resource protocol](ZK60_RESOURCE_PROTOCOL.md).

## Selection contract

| Checkpoint layout | Selected weight files |
|---|---|
| `model.safetensors.index.json` exists | Exactly the distinct root shard names in its verified `weight_map` |
| No index | Only `model.safetensors` |

Other safetensors files are ignored. Shard names must satisfy the importer's
root-file naming rule. Missing referenced files, duplicate JSON keys,
duplicate provider filenames, malformed provider pins and invalid indexes
raise before any weight payload is requested. An indexed layout always takes
precedence over a consolidated file; there is no fallback after an index
fails validation.

The downloader verifies the provider's Git blob SHA-1 for ordinary files and
the provider's LFS SHA-256 for LFS files. It returns a SHA-256 for every
successfully verified payload. The importer receives that exact selected
shard-to-SHA-256 map, including shards stored directly in Git.

## Evidence contract

`source.json` retains schema `zk60-checkpoint-source/1`. Its `files` map contains
the configuration, optional index and selected shards. A file receives
`local_verified: true` only after its download/source-pin check succeeds.
`state` advances from `metadata-pinned` to `raw-checkpoint-verified` only after
the complete importer and bounded first-layer read succeed. Both
`proof_ready` and `proof_produced` remain false.

Configuration/index evidence, provider metadata, inventory, source and CLI
failure records are written to temporary siblings, flushed, and atomically
replaced. A failed replacement keeps the previous complete file. This is a
per-file update, not a transaction spanning the checkpoint and evidence
directories; concurrent writers to those directories are unsupported.

## Reproduction and validation

Base commit: `eee3eb5717dea88d0fc48dc00f6aef389d52af3a`.

At that base, a complete tiny indexed Llama checkpoint plus an unreferenced
root `unreferenced.safetensors` is downloaded in full, then rejected with:

```text
ValueError: checkpoint shard SHA-256 differs from expected source pin
```

The same failure occurs for otherwise valid Git-stored shards because the
fetcher leaves their manifest SHA-256 values as null. A canonical unindexed
checkpoint with an auxiliary weight file also fails. The regression fixtures
use complete synthetic BF16 files, mocked provider HTTP responses and the
actual importer; they need no network, model downloads, GPU or Rust build.

```sh
python3 -m unittest discover -s tests -p 'test_zk60*checkpoint*.py' -v
git diff --check
```

The checkpoint suites contain 31 tests. The four initial selection/provenance
regressions fail on the base and pass with the fix. Coverage also includes
metadata-only behavior, cached reruns, pin mismatches, malformed indexes,
missing shards, unsafe paths, importer refusal and interrupted evidence
replacement. Existing resume and corrupted-download controls remain covered.

These checks do not establish prover soundness, zero knowledge, real-model
calibration, GPU correctness or throughput. This change touches no Rust/Lean
protocol code, and native freeze checks and full-model runs were not performed.
