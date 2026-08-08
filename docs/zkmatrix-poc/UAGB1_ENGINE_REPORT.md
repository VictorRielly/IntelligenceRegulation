# U-AG-B1 Engine Report — Lane BB (critical path: exact-digit + the dense committed matmul statement)

Status: SKELETON at plan commit (2026-08-08); filled as deliverables
land. Ledger: PROGRESS_UAGB1.md "Agent BB status". Machine: Victor's
Mac (Apple M3 Ultra, 32 threads, 256 GB, Homebrew rust 1.96) — NOT
the contract reference box; every timing here is [MAC-BOX,
non-reference], plus [NOISY-SHARED] where sibling lanes were running.
Byte counts and battery verdicts are machine-independent.

## 0. Scope and honest labels

- Deliverable 1: the exact-digit plumbing (F-N2, triple-mandated),
  config-gated ALONGSIDE the balanced-digit path (no deletion).
- Deliverable 2: the dense committed matmul statement C = A*B at the
  125M layer shape 512x768x2048 (committed A weight-class, B
  activation-class, C accumulator-class; dense D-1 encoding;
  multi-wave C2 per RANGE_AGGREGATION_DESIGN Phase 5; Z1 masked
  share discipline). This closes the "largest full matmul claim
  proof = 128x256x64" gap.
- NOT in this statement (honest): the aggregate/eval-proof layer
  (BB items 4-6: IXF fold, masked eval path, wire format). The wire
  objects here are per-wave ct-round proofs + the matmul sumcheck +
  pins; the counted-byte totals therefore carry the pre-aggregation
  opening volume, reported against the Tier N gate as the round's
  designed-vs-built gap number.

## 1. Deliverable 1 — exact-digit plumbing

(to be filled: module layout, class table, derive gates, battery
legs + verdicts, freeze rows, differential table)

## 2. Deliverable 2 — the dense committed matmul statement

(to be filled: statement layout, wave plan at shape, transcript
order, battery legs + verdicts, measurement table, counted-byte
decomposition vs the Tier N 262,144 B/layer P0 gate)

## 3. Walls and findings

(to be filled)

## 4. Exports to BA / BC

(to be filled)
