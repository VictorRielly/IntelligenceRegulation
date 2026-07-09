# U-L (modulus link, F3 resolution) — progress

Branch: worktree-agent-a7a6dfd57b97e3d6e (reset to 9786145, the brief's base).
Task: implement GADGET_MODULUS_DECISION.md option (a) link — ring/link.rs,
link-demo, freeze rows, docs. Lanes: do NOT touch ct_engine.rs, sigma.rs,
commit.rs, params.rs (beyond mod.rs line), pi2/U5/gate-spike/chain-demo.

## Done
- Worktree was mis-based at 7a3e7a0; reset --hard to 9786145 (clean).
- Read: GADGET_MODULUS_DECISION.md (3, 3.5, 8), gadget_link_spike.rs,
  ring/mod.rs, commit.rs, ct_engine.rs, U6b + freeze_check in
  ring_matmul.rs, Q4.4, F3/F5, gadget_modulus_study.py.
- Verified study numbers reproduce (script runs, assertions pass).

## Key decisions
- Demo shape: value tensor n = 128 values (W = 4 bit planes, 512 bit
  coefficients) — the exact F3-pinned ARP shape. REASON (measured, real
  gap): the ARP-grounded binary side condition at q46 under the coded
  conservative constants closes only for binary-claim units <= ~896
  coefficients (n=512 -> 2^44.16, n=896 -> 2^44.96, n=1024 -> 2^45.15
  FAILS, W=12 x 128 = 1536 -> 2^45.74 FAILS). The study prices shapes at
  msg_r=32 columns but its budget table is n=512 only; document as gap.
- Link params FROZEN at the study's operating point: w = 11, l = 24
  (2^-264); demo asserts w <= w_max(demo n, demo W) (holds with margin).
- q46 bit CRS: derive_gadget_layer(Q8_46, 32, 16) == (kappa 6, N_r 62)
  asserted vs study table; q31 value CRS: (Q8, 32, 16) == (9, 56).
- h0_link binds both CRS hashes + both sides' commitments (incl. g's);
  xi rows from h0_link; each side's ct-round h0 = ct_h0(crs, h0_link,...).
- Range gate: |y_l| < q46/2 ONLY (grounding side; Section 3.4 note).
- q31 claim scalar = centered(y_l mod q31), verifier-computed from the
  revealed integer y_l.

## Next
- [x] U-L1a: link.rs skeleton + derive_gadget_layer + mod.rs line; build.
- [x] U-L1b: LinkParams, xi/y/gate/claims (folded into the U-L1 commit).
- [x] U-L2: self_test_link + link-demo arm + self-test call; run.
      MEASURED (link-demo): prove 13 ms, verify 9 ms, link overhead
      ~155 KB (24 claims/side + g columns + 24 revealed y); honest
      max|y| = 2^16.7 vs model 2^16.3, gate 2^45; w_max(demo) = 35;
      all 5 batteries green (honest, bit, value, gate, stale-xi).
- [x] U-L3: freeze_check_link + call; freeze-check green. 7 F3 rows:
      q31 CRS 9/56 (headroom 2.0 bits), q46 CRS 6/62 (16.8 bits),
      w_max(128,4,q46) == 35, w=11 -> l=24 (264 bits), ARP unit 512
      closes / 1536 does NOT (both directions pinned), honest |y|
      model 2^16.3 < 2^45.
- [ ] Python test append; full suite.
- [ ] U-L4: doc status header + measured numbers; PROGRESS final.

## Build/test commands
- PATH="$HOME/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin:$PATH" cargo build --release   (from zkmatrix-rs/)
- PATH="$HOME/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin:$PATH" python3 -m unittest discover -s tests   (repo root, ~100 s)
