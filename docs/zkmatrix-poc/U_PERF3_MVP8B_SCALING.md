# U-PERF3 lane R — the 8B FFN shape: what it costs, what breaks, how MVP-1 runs

Status: SKELETON (2026-08-18, lane R of U-PERF3 round 1, worktree
/home/victor/wt-uperf3-r). Sections 0-5 are filled in order and each
lands in its own commit; every number carries [MEASURED] / [COUNTED] /
[MODEL] / [ASSUMED] and, for walls, its box label.

Scope: MVP-1 of PROGRESS_UPERF3.md — the TARGET_CONTRACT FFN statement
at the 8B shape (32 layers x 512 tokens x d 4096 x f 14336, SwiGLU,
real int8-calibrated weights from an open checkpoint), proved and
verified end to end on hardware we own.

## 0. One paragraph

(to be written last)

## 1. Counted sizes: 12x512 (measured) -> 32x512 at d 4096 / f 14336

(pending)

## 2. What breaks in the code as built (file:line, smallest fix)

(pending)

## 3. Memory and time per box

(pending)

## 4. The data: checkpoint, calibration, export, the m8b scripts

(pending)

## 5. The plan (lanes, files, gates) + the Grok RUN task text

(pending)
