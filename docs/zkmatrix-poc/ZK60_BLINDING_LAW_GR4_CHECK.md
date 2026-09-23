# Check of the G-R4 blinding-law draft — skeleton

> **SKELETON.** Independent adversarial check of
> `docs/zkmatrix-poc/ZK60_BLINDING_LAW_GR4.md` (main tree, `0ae7d61`) and
> `results/zk60_blinding_law_gr4/`, against lane tip `2ea7221` merged into
> this review branch. Started 2026-09-23 16:15 PDT. No findings yet.
> **Not a privacy acceptance.**

Planned sections:

1. m1/m2 against the Rust assertion-6 test (`s36_tests.rs`).
2. A strengthened value-level check (test-only), and its evidence on m1/m2 and on the honest code.
3. Refusal exits after the first draw: does any read a hiding draw?
4. Order: any draw inside a loop whose trip count depends on hidden data?
5. The three residuals, recomputed exactly; the D9 reading.
6. Independence across proofs: the precise assumption.
7. Findings, ranked; verdict per claim; what was not checked.
