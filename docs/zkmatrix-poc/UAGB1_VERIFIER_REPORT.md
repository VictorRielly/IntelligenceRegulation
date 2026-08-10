# U-AG-B1 Verifier Performance Report — Lane BH (wave 3: the row-column split + the gkr_masked padding seam)

Status: SKELETON (plan commit, 2026-08-10). Ledger: PROGRESS_UAGB1.md
"Agent BH status". Machine: Victor's Mac (Apple silicon) — NOT the
contract reference box; every timing here is [MAC-BOX, non-reference],
[NOISY-SHARED] where sibling lanes (BG/BI) ran concurrently. Byte
counts and battery verdicts are machine-independent.

The 2 s contract line binds the AGGREGATE verifier on the REFERENCE
box (TARGET_CONTRACT R2). This lane reports complexity-fix ratios and
absolute [MAC-BOX] numbers — it does NOT claim the contract line.

## 1. Deliverable 1 — the claim-kernel row-column split

(To be written: the algebra, the exact-identity argument, the
before/after table at 512x768x2048 bare + Tier-Z, the kernel-phase
ratio, differential-battery evidence.)

## 2. Deliverable 2 — the gkr_masked capacity seam (BF-F3)

(To be written: the split fill vs the table_row_positions precedent,
capacity n-8, bit-identity below the cap, the dw=22 -> dw=21
measurement at the 2^20 pass shape, battery evidence, the m125-rig
export.)

## 3. Deliverable 3 — battery re-runs at this HEAD

(To be written: the full battery table + suite + freeze-check.)

## 4. Findings and exports

(To be written.)
