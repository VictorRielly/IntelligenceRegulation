# M3 Progress (FFN block end-to-end, lattice track)

Worktree branch: worktree-agent-a1589ff705687357c
Merged perf/zk-batch-optimizations (96dad77) into worktree branch: DONE.

## Plan (decided after required reading)

Demo: `lattice_matmul ffn-demo [T d f shift width]`, default T=16 d=32 f=64
shift=6 width=8 (signed quantized spec: X/W1/W2 entries 4-bit signed, b1
6-bit signed; U' = floor((XW1+b1)/2^6) in [-128,128) width-8 signed;
ReLU via sign bit b + Hadamard A = b o U' + unsigned ranges on A and
D = A - U' (com(D) derived homomorphically); Y = A W2 via transpose-linked
A_rows; residual Out = Y + X_cols (Class-0), X dual-orientation with a
second transpose link).

Code changes planned:
1. manifest.rs: new Operation::BiasBroadcast { bias, broadcast } (tag 10).
2. lattice_matmul.rs:
   - `rho_bound` param on prove/verify_recomposition (+ statement hash):
     value-side randomness may be a difference/sum of two ternaries
     (entries in [-2,2]) for derived commitments (D = A - U', U_b = U + B).
   - `x_rho_bound` param on prove/verify_rescale_link (+ hash): x side is
     the derived U_b = U + bias-broadcast commitment (rho entries [-2,2]).
   - New bias link gadget prove/verify (recomposition/scalar-link shape):
     per rep s in S_b^T, u in S_b^f, claim sum_j u_j <s, B_j> =
     sum(s) <u, b1> with derived keys g_s, g_w (wv_j = sum(s) u_j).
   - Helpers: signed encode, commitment-group add/sub, rho add/sub (i8).
   - ffn_demo(t, d, f, shift, width): full flow, per-component timing,
     Class-0 recompute checks, negative battery, manifest ops recorded.
   - Existing beta folding (center_link with max_cols and 2^12) covers all
     new gadget centers at these shapes - no params change needed (checked:
     bias center ~2^18*b0, rescale rho_bound=2 center ~2^24*b0, folded
     center_link ~2^30*b0 at max_cols=64).
3. tests/test_zkmatrix_native_backends.py: ffn-demo at tiny shape
   (4 8 8 4 6 or similar) so the suite stays fast; suite must stay green.
4. docs/zkmatrix-poc/M3_REPORT.md per scope.

Cost estimate from M2 measured numbers (~0.85 s prove / ~0.24 s verify per
Hadamard-family column at these params): default shape has 384 gadget
columns -> ~5.5-7.5 min end-to-end. Scope's ~5-min guideline conflicts with
the suggested shape; decision: honor the suggested shape, report honestly,
run negatives at 1-column scale, interleave prove/verify per family to cap
proof memory (~0.7 GB per family group).

ReLU soundness argument to document (scope-prescribed ranges):
b binary, A = b o U' (Hadamard), A in [0,2^W) unsigned range,
D = A - U' in [0,2^W) unsigned range on homomorphically derived com(D),
U' in [-2^{W-1},2^{W-1}) signed range (from rescale). b=1 => A=U', D=0,
A-range + U'-signed-range force U' >= 0. b=0 => A=0, D=-U' in [0,2^W)
forces U' <= 0. Both give A = ReLU(U'). Encodings disjoint since
2^W + 2^{W-1} << q.

## Status log

- [x] Merge 96dad77 into worktree branch.
- [x] Required reading done (plan S2-4, M2 report, M0/M1 report, manifest
      spec, lattice_matmul.rs full read).
- [ ] Baseline build + suite green check.
- [ ] Unit 1: manifest op + gadget param generalizations (rho bounds) +
      bias link gadget + self-test coverage for bias link/signed rec.
- [ ] Unit 2: ffn_demo + CLI + tiny-shape run green.
- [ ] Unit 3: Python test wiring; full suite green.
- [ ] Unit 4: headline measurement run at 16/32/64 + M3_REPORT.md.
