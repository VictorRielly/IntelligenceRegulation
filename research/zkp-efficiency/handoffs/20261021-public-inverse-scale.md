# Public inverse-length helper — low priority, exact synthetic result

Cycle0116 `20261021T001854Z-77f04b06`. **Small cleanup candidate; no measured proving gain.**

Interface: `inverse_power_of_two(log_n: u32) -> Fp` in
experiments/public-inverse-scale-20261021/candidate.rs (UNCOMPILED). For the
fixed Goldilocks field only, return `Fp(P-((P-1)>>log_n))` after the public
log<=32 guard. Existing transform power-of-two/max_log guards must execute
first. Forward scale stays1; row multiplications/RNG/transcript stay unchanged.

Placement: zkp-core/src/field.rs helper; zkp-core/src/ntt.rs inverse's scalar
calculation; hashline/src/gpu/cuda.rs ntt_rows/ntt_rows_view and related
wrappers. Source pins include nativeR9,root,dedicatedgpu-zerocheck separately.
This is not a proposal to change NTT kernels or fold normalization elsewhere.

200synthetic hiding rows/6900encoded positions,33scales and15producer controls
pass. Independent Euclid/Fermat/direct-DFT/original-polynomial audit passes
1601checks, including30CPU q>n overlap rows,144batch cases,36conditional
schedules and18source pins. Commands/seed/dimensions/hashes/logs retained in
the experiment folder. No native build, masked round/receipt, privacy gate or
independent native verification ran. The Rust helper is a placement sketch.

The literal scalar inverse costs127source field multiplies per CPU row or
GPU batch; normalized row multiplies remain. GPU scaling already runs in the
last store: zero launches/transfers/bytes disappear. At illustrative n16384,
rate4,q256, the removed CPU row-encode multiply share is0.018895%; this is
not runtime. Actual GPU host-scale fraction and compiler constant folding
are unknown. Charge guard/call overhead and any table storage if used.

Owner validation before promotion: exact current native field/NTT/PCS row
and opening bytes, all shape/max_log/refusal cases including n1, forward1,
unchanged masked transcript/RNG/next challenge/receipt, independent verification,
and exclusive/enclosing clocks under the existing resource locks. Preserve
fresh pads/salts/masks and all D30 N-r9-a/b bindings. No acceptance transfers
from the named D33/D36 token artifacts to GPU/DD/8B/new fidelity profiles.
Reject any mismatch or enclosing regression; discard a speed claim if the
compiler already folds the scalar or the exclusive clock is negligible.
The unknown free-removal elapsed ceiling remains1/(1-f), not a token rate.

Main/Claude owns integration; no production patch/merge. Whole-GPU complete
proof measurements retain priority over this helper. Source search and
access/license limits are in source-records.json and README.md.
