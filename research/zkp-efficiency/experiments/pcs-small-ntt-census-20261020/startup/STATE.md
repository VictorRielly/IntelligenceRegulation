# ZKP efficiency explorer — durable state

Cycle 0101 COMPLETE: `20261020T091854Z-d57182bc`.
Checkpoint: 2026-10-20 09:34 UTC. Deadline: 09:38:54 UTC.
Next cycle no earlier than 2026-10-20 10:18:54 UTC.
Evidence: experiments/ntt-gather-sectors-20261020/.
AGENDA and current throughput direction read; larger workloads are allowed.

No proving speed improvement measured. Native k_ntt_p1 already fuses bit
reversal with DIT. Its 4,096-word tile reads
r = rev_lb(q) * 2^lt + rev_lt(blk), lb=min(logN,12), lt=logN-lb.
At logN >=14, source stride is at least four 8-byte words. Each active
scalar load in a tile has a distinct 32-byte sector, so a within-tile
permutation cannot reduce summed warp requests. This is a request-count
negative, not cache/DRAM/time evidence. N denotes transform length, not context.
At sampled dense aligned logN 8/10/11/12/13, one-bit rotation halves requests;
unique sectors stay unchanged. N=4096: 4096->2048 requests per tile, unique
1024. Fixed 16-lane shared-bank address demand rises 1->2 while whole-warp
peak stays 2; actual SASS/wavefronts are unknown. No large-size rotation win.

Final independent model: 6,239 checks, 21 geometries, 936 tile schedules,
3,326,208 logical words, 560 stride identities, nine rejected bad controls
and one expected null. Compact/full synthetic values and row/zero-tail
controls pass, including q>n. No producer/mask algebra or profile admission
is established. Audit: 188 checks, 15 mutations, 12 unchanged source pins.
One CPU thread/core 0/nice 19: 9.725 s, 22,752 KiB RSS; 59 s CPU/alarm,
60 s parent, 512 MiB caps. No native build, CUDA, transformer witness,
masked transcript, PCS, receipt or verifier ran. The first-load-only
p1_load_rotation.proposed.cuh fragment is uncompiled and conditional.

Source audit caught older main's branched pad producer versus additive
active GPU/frozen R9. Same P1 addresses do not certify main q>n producer
algebra. Initial failed assertion and whole-warp-only bank census retained.
Prior all-eleven FZC choice, pool/OUT/early-release/implicit-affine/carry
negatives remain intact. No mask/opening reuse or privacy weakening.

17 ranked hypotheses in hypotheses.json. Top three: owner complete high-end
GPU plus verified resident 1/2/4/8 passes; DD larger-context scaling after
T128 null; actual capacity/raw/BASE/exclusive/enclosing clocks. All-eleven
literal/GL-only/full-pair native compiler A/B precedes the small-NTT sketch.
New older GNTT negative: direct binary64 casting maps legal p-2 to p-1
before multiplication, so a direct unlimbed port is inexact. No upstream
code executed. New memory-placement paper informs measurement design only.

Next LOCAL: public shape-only census of private-block PCS log_cols, q_pad,
expanded logN and commitment roles in actual source profiles. Determine
which can use tested logN 8..13. Preserve Tab/log_cols P-3 and refusal classes;
use an independent integer layout reference and boundary/mislabel controls.
No build, private telemetry or GPU. Do not repeat unchanged large-N rotation.
Next OWNER: actual route incidence, SASS/shared/cache/exclusive and enclosing
GPU clocks; tiny locked A/B only if warranted, complete parity/refusals,
strict GPU gates, fresh independent verification and current privacy gates.
Existing FZC compiler A/B and verified resident workloads retain priority.
Handoff: handoffs/20261020-ntt-gather-sectors.md. No merge here.

Carried CPU non-DD baseline, not rerun/reverified: 8B T128/L32, one 16-thread
pass, GPU off; total 478.737 s = 0.267370 positions/s; prove_run 393.785 s
includes witness 98.348 s and load 17.595 s; seal 84.824 s overlaps accounting.
Receipt 922,711,264 B; fresh verify 42.709 + load 13.681 s; recheck 34.395 +
load 10.739 s. Startup, steady slope and isolated serialization are unknown.
New verified full proofs/passes/positions: 0/0/0; model context/device: none.
All new witness/proof/serialization/verification clocks, startup duration/
fraction and steady/total rates are UNMEASURED. No long prefill, resident pass
or decode. Private 8B >=50/s on RTX 5090 or another named high-end GPU remains
unachieved. Longer contexts may add quadratic attention. R9 DD N-r9-a/b still
bind; DD privacy is owed; D33 frozen-R7 TinyLlama T32 scope is not extended.

Six LIVE primary records appended, 585->591. SP1 6.9.0 October 10 release/full
version SHA inspected; NTT PR September 30 metadata, not inspected source.
New memory paper: October 14, 2026. New older GNTT: February 16, 2025; source
float cast inspected. Blackwell author issue: May 29, July 2 discussion,
not repository revision dates. NVIDIA 13.4/MMR exact update dates unknown.
License scopes and Internal Error/Cache miss/docs.rs limits retained; no
upstream performance reproduced. Rotate next to lookup/softmax, batching/
resident workloads, quantization, private KV/composition, GKR.
Only research excluding runtime written. No production, Git, builds, GPU,
installs, external writes/messages, purchases or escalation. Reports are not
evidence of external message delivery.
