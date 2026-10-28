# Astra implementation progress

Scope: A1, A2 and A3 in `docs/zkmatrix-poc/ZK60_SOL_ASTRA_TODOS_20261026.md`.
Exclusive writes: Shieldstral prep/export, media app/results, this directory, and
the explicitly requested Astra log in the shared todo file. No git writes.

## 2026-10-26T17:38:04Z — resumed and inspected current evidence

Read and acknowledge CLAUDE.md, START_HERE, current MVP status, decisions
D30/D32/D33/D36–D41, lane rules including all addenda, recovery coordination and
resource protocol. Guard required for benchmark/calibration work; no GPU planned.

- A1: strict ToxicChat has 200 rows per category; OpenAI sexual has 612,
  violence 538/612, hate absent; moderate runs absent. The old queue was stopped
  per the prep ledger. Current HOLD files are absent; guard status shows no
  Shieldstral job. Resume into new logs, retaining all existing evidence.
- A2: selected accuracy stack still awaits final fidelity report (8B refusal
  fixcheck active). Plain dg is authorized as the starting export. R12 loader
  and YaRN/tied-embedding contract must be checked before export generation.
- A3: classifier R-C1 has tests but no frozen release yet. Image resampling is
  currently provisional Pillow BOX with float size arithmetic; replace with a
  versioned integer reference and independent vectors. Base Sepolia adapter is
  independent work; deployment evidence and real classifier demo remain owed.

Baseline copies for source diffs are in `baseline/`. No privacy/soundness claim.

## 2026-10-26T17:48:34Z — integer image reference tested; benchmark host recovery

- A3b implemented: `apps/proven-media/proven_media/image_preprocess.py`,
  `items.py`, `tests/test_image_preprocess.py`, portable vectors at
  `tests/fixtures/image_area_v1.json`, updated app DESIGN. Spec `pm-img-area-v1`:
  exact integer area overlap, one final half-up rounding, 224px longest edge,
  centred mean-colour letterbox, patch/channel-major RGB8. The commitment domain
  binds the spec version. Independent rational-area oracle and full patch-offset
  reconstruction pass. Image proof remains in development; no image fidelity claim.
- MEASURED: 42/42 app tests pass in 2.100 s (shared host). The sandbox run hung
  in AnyIO's TestClient startup; interrupted only our test, diagnosed the startup
  stack, and the authorized host rerun passed. Six image tests also pass in sandbox.
- A1: initial sandbox queue lost its exec handle mid-prefix/first batch, no done
  marker or additional rows. Preserved `logs/astra_20261026/` and
  `bench_queue.out`. Queue lock free; host `manage_bench.py start` checked actual
  process argv and found no surviving benchmark processes, then launched PID
  868177 detached. New evidence: prep `logs/astra_host_20261026/`, this directory's
  `bench_host_queue.out` and `bench_host_launch.json`. Resume is row-id based.
  One guarded light job at a time, need 1.1 GiB (prior RSS <=0.84 +25%), cap 1.8.
  No GPU. Monitor with `python3 results/zk60_astra_20261026/manage_bench.py status`
  on the host; NEVER restart from age alone.
- Next: Base Sepolia publisher implementation; A2 exporter adaptation.

## 2026-10-26T17:55:22Z — A1 strict violence completed; coordinator hold honored

Host benchmark finished strict OpenAI violence: all 612 rows now present, exit 0, 221 s, RSS 0.75 GiB (MEASURED, n=1 shared host). Evidence: prep logs/astra_host_20261026/openai_mod_cat_violence_le168_strat300.c1.*. Coordinator created prep HOLD at 17:50:50Z for Sol native R12 golden/dense window. Host queue PID 868177 is live waiting on that hold; no further benchmark launched. Do not remove the coordinator hold. A3a transport/batcher and app configuration are implemented, tests and deployment tooling in progress. Testnet publisher refuses fake/unbound labels; no transaction broadcast.

## 2026-10-26T18:13:10Z — A3 publisher tests and A2 spec intake

A3a: Base Sepolia transport/batcher, pinned-chain/code checks, durable signed-envelope recovery and independent read verification implemented. MEASURED: 13 focused tests and 55 total app tests passed on host (3.089 s, n=1 shared box); later deployment-tool/fsync edits still await final checks. Throwaway wallet created in owned 0600 file; no transaction sent. RPC status failed both in sandbox and on host; connectivity diagnosis pending. Compiler installed in /tmp, contract compilation/deployment remain pending. No real-classifier or live-chain acceptance claim.

A2: pinned final S2_BUILD_SPEC.json (06f6173b...). Preparing isolated calibration port: query width4096 vs residual3072, three1024-block public Hadamard rotation, YaRN exact prep tables, native mscale fields. Three small geometry checks passed before mscale schema addition; broader port checks pending. Measured arithmetic will preserve group output scaling BEFORE h rounding. No export/fidelity result yet.

Scheduling: no new guarded jobs until coordinator release. Host queue PID868177 confirmed live at18:11:45Z. Correction to coordinator note: manage_bench.py starts astra_host_queue_20261026.sh, which DOES check prep/HOLD before each leaf; it remains paused at that check.

## 2026-10-26T18:23:16Z — pinned checkpoint cross-check passed

A2 actual pinned layer-0 cross-check PASS: prep float max error 3.58e-7, rotated basis 9.54e-7; 35 s / peak RSS1.13 GiB (n=1 shared box), six focused geometry/port tests also pass. Input calibration set192 prompts/32 documents is disjoint from ToxicChat-200. Layer-resumable full-pair statistics collection started, initial layer0 memory rung need3.2/cap4.5GiB. A1 hate resumed automatically at18:13:15Z. A3 alternate RPC verified chain84532 and balance0; free faucet funding needed, no transaction sent. Compile worker session71195 waits outside heavy lock. See results/zk60_shieldstral_export_20261026/checkpoint_smoke.json and Astra PROGRESS.

Sandbox detached starts did not enter the worker (empty launcher logs). Re-entered through foreground resumable tool sessions; each worker must acquire the same nonblocking file lock, preventing overlap. Smoke session49450 finished exit0; compile session71195 is live. No host survivor was assumed dead from PID visibility. RPC https://sepolia.base.org returned HTTP403 on host; https://base-sepolia.api.onfinality.io/public responded successfully. Throwaway public address0x775E8A2D741446d74E3f5a02244D1241eceB187d.

## 2026-10-26T18:33:34Z — S3 drain; statistics rung and app suite passed

S3 drain acknowledged: withdrew waiting compile worker session71195 (exit130, no compile leaf launched); checkpoint smoke and stats-layer0 are terminal exit0. No new guarded launch until S3 WINDOW CLOSED. Initial stats layer0 passed: 232s, peak RSS1.70GiB (watchdog-only sandbox, n=1 shared box), full192x256 rows and full-vocabulary0 maxima retained. A1 hate still running; ASTRA VIEW CLEAR not yet asserted. Final app suite58/58 passed4.029s; deployment tests cover lost-response recovery, chain/funding/runtime refusals. Faucet exact login requirements being checked for Claude.

The stats leaf started27s after the coordinator HOLD was placed (race between last check-in and direct launch); no layer1+ started. All future Astra launchers must check both prep/HOLD and export/HOLD immediately before admission and after precheck. Preserve the completed layer0 checkpoint; do not restart it.

## 2026-10-26T18:34:34Z — faucet dependency and review artifacts

A3 faucet follow-up for Claude: generated address 0x775E8A2D741446d74E3f5a02244D1241eceB187d has0 test ETH. Preferred route: Coinbase Developer Platform portal https://portal.cdp.coinbase.com/products/faucet (redirected to unauthenticated portal here); official quickstart https://docs.cdp.coinbase.com/wallet-api/v2/introduction/quickstart requires CDP sign-in/API-key setup for its SDK faucet. Please route a manual free Base Sepolia ETH claim to this address through Victor's logged-in portal; do not send credentials/private keys to this lane. The exact post-login browser form is not visible here. Alchemy https://www.alchemy.com/faucets/base-sepolia now says no account, but requires0.001ETH and transaction history on Ethereum mainnet, so unsuitable for this new throwaway address; no real funds will be added. Thirdweb shows Connect Wallet; not used. App source hashes and baseline/new-file diffs saved at results/zk60_astra_20261026/review/.

## 2026-10-26T18:38:33Z — S3 process view clear; all strict float categories complete

ASTRA VIEW CLEAR 2026-10-26T18:38:33Z: host /proc check at2026-10-26T18:38:12.751198+00:00 found only benchmark queue PID868177 sleeping at coordinator HOLD, no guard/benchmark leaf/calibration/compiler worker; separate sandbox process view empty. Smoke/stats tool sessions terminal exit0; compile waiter withdrawn exit130. No demo/prover consumer launched by Astra. Evidence results/zk60_astra_20261026/s3_host_drain.json. Start no guarded job until S3 WINDOW CLOSED. A1 strict hate finished612/612 at18:34:31Z (1276s,RSS0.79GiB,n=1 shared host); all strict category sets complete, moderate queued behind HOLD. R-C1 CLI freeze received; next code-only task is dev-rung integration with production min-bits>=95.

## 2026-10-26T18:49:52Z — strict report and R-C1 adapter

A1 strict interim report written at results/zk60_shieldstral_prep_20261021/REPORT_STRICT_INTERIM.md with weighted OpenAI category metrics, margins and token-length shares; ToxicChat category comparisons explicitly proxies, moderate still queued under HOLD. A2 base-export builder and S2 arithmetic adapter prepared (not executed); nine focused geometry/calibration/arithmetic checks passed. R-C1 command/result adapter now matches native artifact layout (no segments.json) and unordered chunk labels, with five synthetic transport tests passing; these are not proof tests. Continuing concrete ClassifierProver dev-rung pipeline. Claude/token lane: please retain a runnable R-C1 synthetic fixture (prover/public export, tables, model identity and sequence directories) or point to an existing one; frozen CLI tests currently delete Cc fixtures on Drop. Native R12/S2 Shieldstral deployment still pending. S3 hold continues; no guarded jobs launched.

2026-10-26T18:50:15Z: Correction to 18:49:52 test timing: five adapter checks initially had one failure because sandbox /tmp/.git is an empty stub. Matched the native git-tree rule (HEAD or gitdir: file); rerun now passes all five. The log line was written before inspecting that failed result; no real proof run claimed.

## 2026-10-26T19:00:55Z — concrete R-C1 interface and tied table generator

A3 RungClassifierProver implemented in apps/proven-media/proven_media/classifier_prover.py with guarded detached worker tools/classifier_pipeline.py: one synthetic policy per chunk, fresh verify/input-owner, changed-artifact checks, independent native label aggregation, recheck API. Not exposed as text classifier or web mode. Full app suite66/66 passed2.338s on host (n=1 shared box), including eight synthetic adapter/orchestration tests; no real classifier proof yet. Testnet rejects development-only labels. A2 streaming tied embedding/head/direct-int16-margin builder prepared in build_token_io.py; three independent quantization/final-norm checks pass, but generator is not run. Classifier uses tn10/refusal-free Cn pending fidelity; full-head compatibility table retains separate calibrated constants. S3 HOLD honored. Retained R-C1 fixture still requested for actual CLI integration after the window.

A2 evaluation planning note: original ToxicChat200 prompts reach T533 (hate) /527 (sexual/violence);19–20 exceed256 and2 exceed512 per category. Full-set model fidelity must retain these cases and report native-profile coverage separately; do not truncate/drop them to claim agreement. Native R12 currently registers only T128/T256. No calibration source file bound by the completed layer0 signature was changed.

## 2026-10-26T19:10:30Z — S3 released; model work resumed

S3 release acknowledged; reread updated resource/recovery contracts. New guard87138bda, FIFO off. Existing host queue PID868177 resumed itself (no restart), moderate ToxicChat hate200/200 completed19:05:41Z,279s/RSS0.83GiB (MEASURED,n=1 shared host); moderate sexual active. Hash-resuming A2 full statistics from layer1 under stats-continue-1, tool session64440, light need2.2GiB (measured1.70+29%), cap4.5,25min resumable timebox; layer0 preserved. Compile worker session8036 waiting outside heavy lock; checkpoints and own workers use both coordinator HOLD paths. Tokenizer-only full A1 evaluation-input preparation still running (no model). Native R13 intake note for Sol: own dg base has free shifts; accuracy_precision currently narrows accepted base shifts (notably product>=13, ao/down>=3, score>=5). Will report actual layer shifts once solved; any smaller denominator can need exact public numerator scaling to preserve the evaluator without excluding a valid calibration.

## 2026-10-26T19:27:08Z — integer evaluation plumbing; retained classifier fixture

A1 all moderate ToxicChat categories now200/200; OpenAI moderate sexual active. A2 complete numerical input set pinned (evaluation_inputs:4872 policy/item combinations,702006 tokens), no truncation; exact-length checkpoint runner and S2 evaluator-artifact generator prepared, with three resume/refusal plumbing tests passing. Statistics through layer8 (full score max202.16 vs causal191.73 there); remaining layers continue. A3 fixture dependency resolved locally: retained native tiny_export/round-trip/tiny-v1 copied read-only into own classifier_fixture, matching synthetic tables generated and hashes recorded. A guarded bootstrap is waiting for CPU admission to record the native model identity; the app will then re-prove/fresh-verify independently. Claude/token lane need not generate a duplicate fixture. No classifier proof/acceptance claimed yet; bootstrap leaves its own receipt unverified.

2026-10-26T19:37:56Z

A2 statistics checkpoint complete through layer13; continuation1 ended normally at its25min timebox (1599s, peakRSS1.86GiB, MEASURED n=1 shared host). Continuation2 resumes layer14 with need2.4/cap4.5GiB, session43291. A3 anchor compiled successfully at19:33:21Z (2.57s, RSS0.25GiB); contract artifact retained in astra/testnet/anchor_contract.json. Read-only Base Sepolia check still balance0, no deployment. Classifier bootstrap first refused legacy fixture missing variant before proving; own copy adapted with named variant and existing layer-manifest digest, originals and failed log retained. Attempt2 waiting heavy-slot admission (session41854). App now has bounded prepare APIs for proof/recheck/label; both-verdict integration harness prepared, actual proof evidence still pending.

2026-10-26T19:48:29Z

A1 moderate OpenAI sexual612/612 completed19:45:23Z; violence now active. Sexual weighted precision/F1 improve strict0.597/0.740 -> moderate0.612/0.752, recall unchanged0.974 (MEASURED,n=1; category-only, no policy recommendation). ToxicChat200 strict/moderate sexual and violence verdicts identical; moderate hate adds one flag; union toxicity-proxy F1 0.733->0.721. Paired artifacts under astra/*policy_comparison.json. A2 statistics through layer18; all17 focused export checks pass. Base15-second between-layer probe queued behind full statistics (session97911), need3.2/cap5GiB from closest fp-diag2.42GiB plus32%, twoBLASthreads; full continuation declaration will use measured peak. A3 independent Python integer kernel matches retained native rung output bitwise; two-chunk end-aligned candidate activations prepared with zero local refusals. Integration harness covers both verdicts, recheck, owner checks, reverse-order two-chunk aggregate. Native bootstrap remains queued behind shared CPU work; no actual classifier proof claimed.

2026-10-26T19:54:19Z

Resource check: heavy/build locks are currently free, but classifier bootstrap admission now refuses because swap is1.04GiB (>1GiB guard threshold), despite12.46GiB available RAM; native run has still not started. Keeping the existing waiter and respecting the guard, no duplicate or bypass. Calibration/float benchmark continue. Prepared mixed two-chunk synthetic margin yields expected local bits[1,0] at integer margins16432/-16335; integration will require fresh native proof and reverse-order OR aggregation before any proof claim.

2026-10-26T20:03:46Z

A2 full192x256 calibration COMPLETE (26layers,49152rows/layer, zero excluded). stats SHAacc021c6de4e58b5f1fd02a00a4a003f1da95fb8a366fb06fff4d71aa69f5f51; continuation2 ended20:00:21Z,1427s/RSS1.85GiB. Admission reopened; base probe built layer0 in33.96s, no clipped weights (whole44s,RSS1.12GiB); full hash-resume continuation2 started with need1.5/cap5GiB. IMPORTANT Sol/Claude intake: full-float layer25 gate negative magnitude74.934, two channels2181/8853 at70.150/74.934 exceed the largest current group member input range near64; positive max39.838. This is a calibration warning, not a measured integer refusal. Before claiming zero refusals I will check the actual integer path and affected positions; a coarser registered member may be needed, no silent negative saturation or spec change. calibration_range_audit.json records all layers. Signed16 domain amendment applied only via separate S2RecPos evaluator recorder; calibration/vendor source pins unchanged. Twenty focused checks pass, including exact -32768 norm endpoint; original S2 spec bytes preserved.


## 2026-10-28T21:09:25.422557+00:00 — resumed Astra, A1 delivered; S2 conversion complete

A1 recovered terminal host benchmark queue (done=0, no live worker). All 12 sets are complete and aligned (612 OpenAI + 200 ToxicChat per category/policy, 4,872 decisions). Regenerated metrics and final prep/REPORT.md with strict/moderate precision, recall, F1, margin distributions and content-length shares; source hashes in benchmark_report_sources.json. Product wording remains Victors choice.

A2 base export had finished all 26 layers after the old ledger stopped (base-2 exit0,647s,RSS1.16GiB). S2 numerical export is now complete: initial probe exit3 (18s,RSS1.40GiB); attempt2 lost its handle at layer18 with no terminal marker, so checked missing handle AND free worker lock before attempt3 resumed and completed layers19–25 (exit0,79s,RSS1.48GiB, watchdog-only sandbox). Original partial evidence preserved. All20 export tests pass. Preparing actual layer25 integer replay at the two float-extreme coordinates; no native or head tables generated pending Sols shared quantizer.

A3 all72 app tests pass on host (2.598s,n=1); sandbox TestClient startup hung, interrupted through original handle (exit130), bounded host rerun succeeded. Retained classifier_integration/complete.json contains both native synthetic verdicts and reverse-order mixed two-chunk OR; it is development evidence only, not Shieldstral. Read-only host Base Sepolia check: chain84532, balance0, no config; no transaction sent. Victor requested non-Coinbase funding instructions; provided LearnWeb3 Base Sepolia faucet/GitHub steps.

Coordinator restart note read: maintain exclusive Astra writes, head-table hold, and paper-ready evidence. New guarded layer25-locate is live; no other Astra job pending.


## 2026-10-28T21:13:48.721013+00:00 — layer25 integer refusal reproduced

MEASURED: float replay across all192 calibration sequences reproduced both extrema at sequence97/position109: channel2181=-70.1500168, channel8853=-74.9340363 (layer25_probe/float-extrema.json;101s,RSS1.11GiB). All192 have some float warning in the two channels; this is not an integer count. Full26-layer S2 integer replay of sequence97 has ZERO refusals through layers0–24, then layer25 FFN up refuses2 words (min-56729) and FFN gate refuses395 words (min-2821; allowed[-2048,2047]). At position109, channels2181/8853 are-2263/-2410, e_in=-1. Gate depends on norm_m, so its result is unaffected by the independent up clamp. Complete pre-clamp diagnostics and source/data hashes in layer25_probe/integer/complete.json.17s+33s,peakRSS0.93GiB,n=1 shared sandbox.

Sol/Claude: the coarser Shieldstral member is REQUIRED; please enable profile-specific e_in=0/e_out=-8 with your proposed no-wrap/derived-class update while retaining<=4groups. Also testing a free per-layer sh_u+1 / sh_h-1 recalibration to address up overflow; no accepted-spec/prover changes claimed. Canonical tables will follow the now-posted R12b quantizer, with full independent reference comparison before manifests and a separate profile copy so completed numerical evidence stays pinned.

A3: all4 retained synthetic classifier receipts reverified in fresh guarded processes (bits0,1,1,0), original bytes unchanged; classifier_reverify_20261028_retry1/complete.json. Initial audit harness expected verdict_bit in the event instead of verdict and stopped after a successful first verify; original log retained and harness corrected. No owner reopening repeated because old private artifacts were under/tmp.
