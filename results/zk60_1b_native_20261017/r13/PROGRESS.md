# Native R13 progress

Owner: Codex Sol. Primary cross-lane log:
`docs/zkmatrix-poc/ZK60_SOL_ASTRA_TODOS_20261026.md`, Sol log.
Primary run ledger: `results/zk60_sol_20261026/PROGRESS.md`.

2026-10-26T18:10 UTC state:

- Spec received: fidelity lane `S2_BUILD_SPEC.json`, SHA-256
  `06f6173b604ea70fc1d6470ca0749ebaefb001bc8b6640e3ae628927f8e5ad1a`.
- `working-tree/` is an isolated source copy; `BASE.json` names its R12
  acceptance baseline. The native working tree is unchanged while R12 runs.
- `accuracy.rs` contains failing-first scalar tests and deliberate stubs.
  Independent expected vectors: 324 requantization cases and 216 grouped
  product cases from the rational Python reference, copied into the source.
- Red-run driver: `results/zk60_sol_20261026/r13_red.py`, live tool session
  53110, polling admission before any build. `red.done` will be 0 only when
  compilation succeeded and the stub tests failed with native exit 101 as
  expected. Inspect that evidence before replacing stubs.
- `DESIGN.md` records the implementation sequence and the requirement to
  apply group output scale before h-product rounding. The incoming cost
  replica's one-byte product remainder may need recounting for exact group
  scaling; keep the measured arithmetic.
- `EXPORT_CONTRACT_DRAFT.md` proposes the new native c2/group array format.
  It is not an implemented loader interface yet.

No R13 proof, freeze, measured fidelity, or security acceptance is claimed.

## Update

- 2026-10-26T18:38:28Z: R13 arithmetic now implemented in isolated working-tree: accuracy.rs, accuracy_tables.rs, accuracy_groups.rs. Captured expected failing-first runs, then 12 combined Rust tests passed (groups_green.done=0), covering 540 rational vectors, all 36,864 int12 SiLU values, negative ties, overflow/class refusals, canonical group IDs, and exact common-denominator folds. block_reference.py independently matches fp_lib.rx_block at 15 trace sites with no violations (public synthetic geometry, not a trained proof). Exact group scaling can require product shift 10 / two remainder limbs; counted cost must be updated. Next is profile-derived precision and integration into shape/layout/witness/argument/loader. Guard/pins still unchanged; zero live guarded jobs now, but S3 cross-lane readiness record absent.

- 2026-10-26T18:50:32Z: R13 full native crate compiled with arithmetic/precision helpers and all 15 selected tests passed (primitives.done=0, build 147.4 s / RSS 1.86 GiB, watchdog-only sandbox). Public accuracy object then passed 19 combined standalone tests after its captured red run: exact c2 dimensions/ranges, canonical encoding, table and derived-cache tamper rechecks. New BlockPublic binding/legacy-profile rejection tests are compiling in red phase (session 18943); attachment remains a deliberate stub until red evidence lands. All work stays in r13/working-tree; R12 frozen/main source unchanged. S3 marker absent, guard/pins old.

- 2026-10-26T19:21:49Z: Acknowledged coordinator 19:11 exact-construction go-ahead. Required no-wrap update is in r13/nowrap_counted.json: derived table abs <=1073709056 (<2^30, signed31); LOW and H24 product clauses <2^47, largest local bound remains51 bits under pinned Goldilocks. Public tables will be recomputed from registered int16 members then exactly scaled (no second SiLU rounding), not accepted as derived arrays from prover. Required cost figure: 8B T512 vs R9 DD becomes +26.530% committed (+1.610 points from +24.920%); T128 DD +25.618%, T128 non-DD +24.628%. COUNTED anchored replica, native count still to confirm. Binding green passed; Low export preset and byte-aligned candidates/tests prepared while session54198 polls behind token suite. No new layout built.
