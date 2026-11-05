# A14 ranking: /Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a712d6f342b57b528/results/zk60_effplan_20261105/a17/raw/s6_sample_N6.txt
interval 2.0 ms, 3 proof-only fork calls in the window, N = 6

fork main lines: 21986 samples = 43.97 thread-s; gpu-wait 53.3%, host 37.0%, pool-work 7.8%, pool-wait 1.9%
main-line samples NOT waiting on the GPU: 10272 = 20.54 thread-s (1.141 s per fork per call)
rayon busy samples: 32751 = 65.50 thread-s (21.83 CPU-s per call)

| bucket | owner | main line, % of its non-GPU samples | main line, s per fork per call | pool busy, CPU-s per call |
|---|---|---:|---:|---:|
| A/H zero-fill, free (vec! / bzero / vm_deallocate) | protocol.rs (A13) | 14.3% | 0.163 | 0.08 |
| openings' store fold (A8) | metal.rs fold region | 14.3% | 0.163 | 4.88 |
| LogUp helper inverses | protocol.rs (A13) | 11.1% | 0.127 | 2.73 |
| public weight folds and public tables (define) | argument.rs define; accuracy_fold.rs, mle.rs, pad.rs code | 11.0% | 0.126 | 2.04 |
| randomness: ZkRng (fill_fp, next_u64, the XOF) | rng.rs (A14) | 9.5% | 0.108 | 2.64 |
| commit host parts (salts, Merkle, host NTT, uploads) | pcs.rs / metal.rs | 7.0% | 0.080 | 1.75 |
| lookup values + histograms | protocol.rs (A13) | 6.4% | 0.073 | 1.93 |
| witness planes into A (write_planes) | protocol.rs (A13) | 4.4% | 0.051 | 1.49 |
| other / unattributed | - | 4.0% | 0.046 | 0.43 |
| transcript absorb | transcript.rs (A14) | 3.4% | 0.039 | 0.00 |
| claimed sum (total_at) | argument.rs | 3.0% | 0.035 | 0.93 |
| extension rounds (mask_eval_eq, eq_table_msb) | argument.rs / mle.rs | 2.9% | 0.033 | 0.14 |
| private slots' tables (priv_table_fill / build_tables_at) | argument.rs (A14) | 2.6% | 0.030 | 0.60 |
| device slots' table plan + public tables (A12 host part) | argument.rs / metal.rs tables (A14) | 2.0% | 0.023 | 0.10 |
| openings other (group_zclaims, columns, check_opening) | pcs.rs | 1.8% | 0.021 | 0.00 |
| per-block public checks (check_for_shape, check_for_registry) | prove_core's call (protocol.rs, A13); private_block.rs / accuracy_public.rs code | 1.6% | 0.019 | 2.08 |
| sumcheck host rounds / host tail | sumcheck (zkp-core) | 0.6% | 0.006 | 0.00 |
