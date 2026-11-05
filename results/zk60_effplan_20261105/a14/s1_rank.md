# A14 ranking: /Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a9838ab349101784d/results/zk60_effplan_20261105/a14/raw/s1_sample_N6.txt
interval 2.0 ms, 3 proof-only fork calls in the window, N = 6

fork main lines: 21488 samples = 42.98 thread-s; gpu-wait 48.3%, host 39.5%, pool-work 8.4%, pool-wait 3.9%
main-line samples NOT waiting on the GPU: 11116 = 22.23 thread-s (1.235 s per fork per call)
rayon busy samples: 34585 = 69.17 thread-s (23.06 CPU-s per call)

| bucket | owner | main line, % of its non-GPU samples | main line, s per fork per call | pool busy, CPU-s per call |
|---|---|---:|---:|---:|
| A/H zero-fill, free (vec! / bzero / vm_deallocate) | protocol.rs (A13) | 14.2% | 0.176 | 0.05 |
| openings' store fold (A8) | metal.rs fold region | 11.7% | 0.144 | 4.34 |
| lookup values + histograms | protocol.rs (A13) | 10.2% | 0.126 | 3.17 |
| public weight folds and public tables (define) | argument.rs define; accuracy_fold.rs, mle.rs, pad.rs code | 9.7% | 0.120 | 1.87 |
| LogUp helper inverses | protocol.rs (A13) | 9.5% | 0.117 | 2.49 |
| randomness: ZkRng (fill_fp, next_u64, the XOF) | rng.rs (A14) | 7.8% | 0.097 | 2.41 |
| commit host parts (salts, Merkle, host NTT, uploads) | pcs.rs / metal.rs | 6.2% | 0.076 | 1.61 |
| private slots' tables (priv_table_fill / build_tables_at) | argument.rs (A14) | 5.1% | 0.063 | 1.41 |
| per-block public checks (check_for_shape, check_for_registry) | prove_core's call (protocol.rs, A13); private_block.rs / accuracy_public.rs code | 4.1% | 0.050 | 2.58 |
| witness planes into A (write_planes) | protocol.rs (A13) | 4.0% | 0.050 | 1.47 |
| other / unattributed | - | 4.0% | 0.049 | 0.31 |
| extension rounds (mask_eval_eq, eq_table_msb) | argument.rs / mle.rs | 3.9% | 0.048 | 0.36 |
| claimed sum (total_at) | argument.rs | 2.9% | 0.035 | 0.89 |
| transcript absorb | transcript.rs (A14) | 2.8% | 0.035 | 0.00 |
| device slots' table plan + public tables (A12 host part) | argument.rs / metal.rs tables (A14) | 2.0% | 0.024 | 0.10 |
| openings other (group_zclaims, columns, check_opening) | pcs.rs | 1.4% | 0.018 | 0.00 |
| sumcheck host rounds / host tail | sumcheck (zkp-core) | 0.6% | 0.007 | 0.00 |
