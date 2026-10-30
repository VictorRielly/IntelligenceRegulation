# Standing research agenda — Victor, 2026-09-26

Victor expects the researcher to continuously ask and investigate questions
like whether KV caching, larger proof windows, or reusable preprocessing can
make a complete private 8B forward-pass proof sustain >=50 proved tokens/s
on an RTX 5090 or another named high-end GPU. Do not wait for Victor to supply
optimization ideas. This is a standing direction for every scheduled cycle,
within the existing hourly schedule and 20-minute/resource limits.

The current [throughput target](../../docs/zkmatrix-poc/ZK60_THROUGHPUT_TARGET.md)
supersedes old fixed-512 acceptance language, including a launcher prompt
cached before this update. Larger workloads may amortize initialization and
prefill. Preserve full coverage, exact arithmetic, and the decided privacy
requirements; count completed proved positions rather than inference output.

## Every cycle

**Progress reporting, Victor, 2026-09-26 PDT:** give periodic progress updates
while pursuing the goal. At the end of each research cycle, refresh
`research/zkp-efficiency/PROGRESS.md` with a short plain-language report and
append a dated entry under `progress/` using the run ID as the filename.
Include what completed, what the evidence measures, what remains blocked or
unknown, the next action, and the implication for >=50 proved tokens/s on the
complete private 8B stack. Distinguish measured proving results, synthetic
experiments and projections. If no improvement was found, say so. These files
are durable reports; they are not chat notifications or evidence of delivery.
The main agent posts updates here during active work, at milestones and
blockers, and after reviewing new background reports when the session resumes.

1. Read this agenda, current measurements, previous experiments and new
   handoffs. Identify which recurring cost presently limits complete-proof
   throughput, and distinguish measured costs from unknown ones.
2. Maintain a ranked queue of at least three concrete hypotheses. Add or
   materially refine at least one question without waiting for user input.
   Ask what work is repeated, what can be reused safely, what is absent from
   the profile, and whether changing workload or scheduling removes the cost.
   Do not assume that a familiar inference optimization benefits proving.
3. For the leading hypothesis, state the baseline, eliminated work, new
   costs, expected end-to-end ceiling, prerequisites, and an observation that
   would disprove it. If phase measurements are absent, propose the required
   measurement rather than inventing a speed estimate.
4. Check primary literature and implementations, then perform one bounded
   differential experiment, cost-accounting study or decisive negative test.
   Preserve source pins, commands, controls and limits. A negative finding
   should redirect the queue, not be hidden or repeated unchanged.
5. Checkpoint the result, update rankings, and give the next concrete experiment.
   Explain the implication for the 50-token/s target, including when the
   effect is too small or remains unknown. Handoffs must identify an actual
   implementation seam and unresolved proof/privacy obligations.

## Initial questions to pursue

- **Incremental execution and KV state:** can append processing avoid prefix
  reexecution within one supported proof window while preserving every checked
  value and refusal? Start with the
  [KV handoff](handoffs/20260926-kv-proof-state.md). The frozen kernel checks
  masked future scores too: ordinary K/V-only validation misses part of the
  relation. The synthetic retained-Q experiment is not full-block equivalence.
  Then assess the cost and privacy of authenticating state across proof windows.
  Also investigate a separately versioned causal-only relation if the frozen
  profile's future-pair checks impose avoidable work. Document its changed
  refusal domain and required review explicitly; the old profile must remain
  reproducible. A legacy proof layout is not automatically an architectural
  requirement for every future profile.
- **Proof-window and resident-model amortization:** which setup is truly paid
  once, which work recurs, and which window size minimizes complete workload
  time under real memory limits? Compare fixed-context resident passes with
  long prefill and later decode separately; include pipeline drain and proof lag.
- **Reusable weights and public preprocessing:** which legacy public-weight
  cache work can transfer to the private-block path? Does load/reencoding or
  transfer outweigh the avoided work? P3 private weights need their own review;
  public cache reuse does not authorize reused private openings or blinding.
- **Memory traffic and GPU scheduling:** can folds, next-round accumulation,
  encoding, hashing or transfers be fused or overlapped at the measured hot
  phases without changing transcripts, lifetimes or memory bounds?
- **Proof architecture:** can amortized commitments, lookup techniques,
  accumulation or incremental verification reduce the dominant cost? Include
  state binding, fresh randomness, verifier work and integration cost. Sampling
  or an inference cache is not a complete private forward-pass proof.

These are a starting queue, not an exhaustive list or a mandate to rediscover
existing caches. Prioritize by evidence. Do not abandon a nearly complete
bounded experiment just because the rotation changes; checkpoint and rerank.
The native implementation owner reviews/promotes candidates. No production,
GPU, installation, external-message or spending authority is added here.
