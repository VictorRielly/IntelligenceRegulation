# ZK60 — independent adversarial review of stage 28 (the 125M prover, "faster without moving a byte")

**Reviewer:** an independent agent that did not write stage 28. **Lane under
review:** `zk60-private-block-125m`, stage 28, commits `d2c2733`, `a9f2211`,
`1952a1e`, `309d238` over the base `79f0726`. **Review worktree:**
`/home/victor/wt-zk60-block125m-review`, branch
`zk60-private-block-125m-review`. **Opened:** 2026-09-21 10:0x PDT.

Nothing in the stage's own ledger section is taken on trust; every figure and
every claim below is re-derived from the code, from the committed logs, or
from a test this review wrote.

## 0. Skeleton (this commit) — what will be filled in

* **1. The production diff, line by line** — what each changed computation
  computed before, what it computes now, on what domain the two agree, and
  who calls it. The verifier surface, listed separately.
* **2. Are the ten equality gates real?** — oracle independence, shape and
  edge-case coverage, what is missing.
* **3. The differential tests this review added** (`s28_review_tests.rs`) and
  what they found.
* **4. Thread-count independence.**
* **5. Randomness: draws and absorbs.**
* **6. Refusals, and the precise status of finding S28-F1.**
* **7. End to end across versions** — old-prover receipts under the
  stage-28 verifier.
* **8. Negative controls.**
* **9. The memory and timing claims against the stage's own logs.**
* **10. Findings S28-R1…** with severity and what would close each.
* **11. Verdict per claim.**
* **12. What this review did not do.**

*(sections filled in the commits that follow)*
