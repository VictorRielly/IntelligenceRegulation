# Conditional handoff: count small inverse NTTs separately

Cycle 0102, run `20261020T101854Z-5d2a545a`, 2026-10-20 UTC.
No native performance improvement measured; do not merge from this census.

The prior guarded lane-rotation sketch has a narrower, source-backed place to
try: hiding commitment inverse transforms at log_cols 12/13. Each hiding row
also has an expanded forward at log_cols+2. That forward is outside the guard
at trained shapes. M is log12 but CPU-only, so does not exercise the sketch.

Frozen R9: TinyLlama T32/T64/T128 uses log_cols12/13/14; 8B uses13/13/14.
Active GPU lane only carries 8B T32; do not assign R9 T64/T128 to that lane.
R9 DD T128 has the same log14 and no gain by this mechanism. Endpoint and
boundary geometry follows its own parameters; no profile/row-width changes.

Per committed row, inverse sector requests at log13:8192->4096; full-width
expanded forward stays32768; compact forward stays8448. Thus the pair's
summed requests fall10%/24.6154% for full/compact input. This is not traffic,
cache-miss or elapsed evidence. At log14 both phases are unchanged. Actual
phase time and route incidence are missing; zero logical bytes/transforms/
mask draws/commitments/capacity are removed. Added index arithmetic and
shared-store cost may erase the request reduction. Prior fixed16-lane bank
address model worsens1->2; actual SASS wavefronts unknown.

Interface/patch: same k_ntt_p1 signature, shared indices, barriers,
butterflies and stores. Only the first load loop is sketched in
`experiments/ntt-gather-sectors-20261020/p1_load_rotation.proposed.cuh`.
Caller seam is GPU cuda.rs ntt_rows/ntt_rows_view, called by private resident
and chunked/open reencoding. Neither non-hiding DIF/DIT nor CPU M is covered.
Census/prototype/reference and pinned source copies are in
`experiments/pcs-small-ntt-census-20261020/`; no new native patch was made.

Validation:619 integer/address/request checks;16 lane/profile entries,
160 role/phase rows,13 distinct transform geometries,444 boundaries,9 wrong
controls. Independent bit-string and byte-sector oracle enumerates every
tile of tested rows; no native NTT or tensor value evaluation. Source audit:
933 assertions,64 fragments,48 rejected fragment deletions,16 unchanged pins.
Probe3.850s/20,620KiB; one thread,59s CPU/alarm,60s parent,512MiB AS.
Commands,seed270536706,hardware and limits retained. No GPU/build/install.

Owner acceptance, only if worth a locked small A/B after the higher-ranked
all-eleven FZC compiler experiment: actual role/context/inverse/forward
incidence, exclusive and enclosing clocks, ptxas/SASS registers and shared/
cache metrics. Native forward/inverse/compact/chunked/coset checks; seeded
masked-round/next-challenge/PCS/receipt and refusal parity; strict GPU gates;
fresh independent full-stack verification and current privacy/fidelity/
soundness gates. Preserve S-1/P-3 Tab/log_cols, fresh randomness and original
one-opening owners. Reject on mismatch or enclosing regression. No numeric
whole-model GPU ceiling follows; deleting all affected-load time f gives
at most1/(1-f), actual sketch narrower; T128 request mechanism offers no gain.

Next local rotates to recurring H helper words and lookup multiplicities,
DD/nonDD separately, before any LogUp-GKR architecture prototype. The tiny
public table's cached setup is not recurring private helper commitment work.
