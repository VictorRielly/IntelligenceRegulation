# Public reload prefetch: review boundary

This is an unapplied research design. `candidate.py` is a tiny filesystem
projection, not a Rust loader or a production patch. Main/Claude owns review
and integration. There is no proposed change to a proof relation or transcript.

The inspected active source is `ops/zkp-mvp/trained-1b/`, pinned in
`native-pins.json`. Do not substitute the root compatibility adapter: its
backend API differs from the active keyed API. Current native code is not
claimed frozen or security-accepted by this experiment.

1. `trained_block.rs::seal_and_record` already joins next-layer full load
   with the current witness build. Adding the same prefetch there removes
   zero new work. Preserve its H-1 refusal checks before the header.
2. `BlockCache::get` drops the previous cache owner, reloads actual files,
   then compares the rebuilt block digest with the bound digest. The cache is
   `Rc<RefCell<...>>`, not a background-thread interface. `Arc<BlockPublic>`
   references may outlive a cache replacement; clearing `cur` is not proof
   that all old owners are dead.
3. A candidate advisory interface is
   `hint_public_files(public_validated_descriptors, requested_byte_budget)`.
   It returns no bytes, block, digest, identity authority or private result.
   Use only public, shape-bounded paths, and a best-effort no-follow regular
   file open. Treat hint failure as no hint; the original demand load must
   still decide acceptance and emit the original refusal. Never pass zero
   size to mean zero work: WILLNEED size zero means the rest of the file.
4. Place hints at a source-reviewed public stage boundary, initially compare
   after `prove_core` with earlier issue times. Reopen through the ORIGINAL
   demand loader; do not hand it an earlier file handle, hydrated snapshot,
   unchecked manifest hash or cached successful validation. Early parsing
   must neither introduce an observable refusal nor bypass later checks.
5. Requested advice bytes are only a request bound. They are not a measured
   I/O amount, page-cache reservation or RSS/cgroup limit. Include kernel file
   pages, other file eviction, host memory bandwidth, actual disk reads,
   loader temporaries, witness/PCS capacities, driver/pools and the run tail.
   The experiment did not measure page residency or concurrent filesystem races.
6. `pcs::commit_zk_owned_with_tag` draws fresh pads/salts before the keyed
   offer. Accepted CUDA input upload is host-synchronous under a GPU mutex;
   resident failure can retry chunked after discarding work, or decline to
   the CPU oracle. GPU-required declines abort. File hints save none of this
   field/mask/upload/NTT/hash/opening work. Do not change these policies.

Owner validation before promotion: native byte/refusal and RNG/transcript
comparisons, mutable-file and no-follow controls, backend failure/required
behavior, actual host/file/VRAM capacities and GPU oracle/frozen/privacy
gates. Run only with the current resource protocol and shared heavy/build
locks. No heavy or GPU job is requested or launched by this lane.

Measure instrumentation-off/on and hint-off/on complete independently verified
resident 1/2/4/8 workloads at an admitted context. Report exclusive file reads,
rebuild/support/authentication, witness, offer/decline/discard, host API and
device activity, proof, serialization/sink, startup, drain and verification.
Charge startup and unsuccessful hints. If exclusive saved wait is S and added
cost is A, total rate is N/(T-S+A); even free removal is at most N/(T-S).
No numerical S or A is available. Falsify on changed bytes/refusals, no exposed
I/O, already warm page cache, unbounded memory pressure, or A >= S.

Only P1 public model files qualify. P3 private weights, private activations,
prompts/tokens, masks, pads, salts, openings and challenges are excluded.
