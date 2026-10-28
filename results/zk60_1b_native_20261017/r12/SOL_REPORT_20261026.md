# R12 ready for independent review

R12 is frozen. All requested acceptance checks passed. Claude can route the
D24 review using `frozen-tree/`, `r12-vs-r9.patch` and `manifest_frozen.json`.
No soundness or privacy acceptance is claimed by this delivery.

Frozen source tree SHA-256:
`1e406781f734e9f35f066516a35bf6b9ef97dee164ece4f43bbe7b3e00735fc7`.
The prior R8 and R9 frozen trees were re-hashed and remain unchanged.

The resumed kernel failure was an obsolete test that still expected the
query-axis width to equal model width. Its replacement checks the decoupled
axis and plane lengths; the kernel suite passes all six tests. The retained
R9 recordings were installed for four seeded proof digests and five statement
identities, with missing recordings now failing the checks.

| Acceptance evidence | Result |
|---|---|
| Existing-profile seeded compatibility | Four proof digests and five statement identities match R9; DD and non-DD |
| Generic dense Shieldstral T128 | DD and non-DD prove and verify; outputs equal the independent kernel; heads differ; modified receipts rejected |
| Retained-byte verification | Both saved dense receipts verify in a new process; modified receipts rejected |
| CPU and GPU-enabled CLIs | Both release builds passed; binaries retained beside this report |
| R8/R9 retained full-stack receipts | TinyLlama 22 blocks and 8B 32 blocks verify under R12, both DD and non-DD, at the original expected statement identities |
| Standard full hashline suite | 29 targets, 733 passed, zero failed, 42 deliberately ignored |
| Required ignored checks | Five golden/identity tests, two dense-proof tests and two fresh-process verification tests were run separately and passed |
| Shape-driven reference kernel suite | Six passed, zero failed |
| Unsupported DD geometry | Refused by name, exit 1, with no output run directory |

The existing R12 F1 tests passed against the prep lane's YaRN table digests,
including T2048, and the unscaled generator stays frozen. F2 decoupled geometry,
T128/T256 DD/non-DD layouts and counts, and F3 tied-embedding loader/statement
binding tests passed in the focused and standard suites.

Measurements are **n=1, shared box**. The dense proof pair's guarded command
took 153.55 seconds, including witness generation, independent kernel runs,
proofs and checks; peak RSS 6.59 GiB and kernel peak 6.58 GiB. Saved receipt
sizes are 29,301,896 bytes (non-DD) and 29,536,904 bytes (DD). The separate
verification command took 8.47 seconds for both receipts and their tamper
controls. These witnesses use public synthetic dense weights at Shieldstral's
shape. Trained Shieldstral calibration and classifier integration belong to
the other lanes.

All 13 heavy acceptance stages ran through the common guard with kernel
memory caps. Commands, child timings, completion markers and logs are retained
under `results/zk60_sol_20261026/`. `R12_AUDIT.json` audits every gate, source
and freeze equality, compatibility identities and prior frozen-tree integrity;
`evidence.sha256.json` hashes the fixed R12 evidence. `R12_COMPLETE.done = 0`
is the terminal acceptance marker.

The original runner's final packaging step used a Python 3.11-only hashing
helper on Python 3.10 and exited after all acceptance gates and the frozen
copy were complete. Its failure is preserved in `acceptance.done` and
`acceptance.log`. `finalize_r12.py` independently checked all gates and used
streaming hashing to complete the package; no proof stage was bypassed or
repeated to conceal a failure.
