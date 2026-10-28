# R13 export extension, draft for the native loader

This is a proposed interface for implementation/testing, not a supported
loader yet. Existing R12 exports stay v1. The received S2 build spec defines
the arithmetic but does not provide native c2/group arrays.

Implementation checkpoint: the isolated `trained_accuracy.rs` helper reads
the ten arrays below through the existing bounded, race-resistant array
reader, checks SHA-256, and builds the typed public object. Its native tests
are pending. The existing profile/layer loader does not call it yet; this
document is still a draft, not an advertised A2 export interface.

Use a new v2 profile/layer schema for LOW-family exports, with an explicit
`accuracy_stack` (`low-v1` or `low-h24-v1`). A v1/legacy profile must reject
R13 fields rather than silently ignore multipliers or group tables. The
native profile and run identifiers must also be different. Retain all model,
RoPE, tied-embedding and token/head pins from the R12 interface.

Use the chosen stack per model: TinyLlama LOW h16, 8B LOW+h24, Shieldstral
initially LOW+h24. A later Shieldstral LOW selection needs its fidelity gate.
Do not introduce a process-global flag. Proposed block/run profile strings
change the final `/1` to `/2`, keeping their existing byte lengths for the
hash-input census. Actual registry/constructor/statement wiring and the
updated census remain to implement and validate.

Public arrays use the existing manifest structure (`file`, `dtype`, `shape`,
`sha256`) and little-endian binary payloads. No private values enter them.
Use int64 for small multiplier/group arrays so the current bounded-array
reader can validate them without introducing another numeric parser.

| Array | dtype | True shape / order |
|---|---|---|
| `m_q` | int64 | `[q_heads * head_dim]`, true query-head order |
| `m_k`, `m_v` | int64 | `[kv_heads * head_dim]`, true KV-head order |
| `m_o`, `m_d` | int64 | `[width]`, output model-channel order |
| `m_g`, `m_u` | int64 | `[hidden]`, output FFN-channel order |
| `silu_group_ids` | int64 | `[hidden]`, group index per FFN channel |
| `silu_groups` | int64 | `[ngroups, 2]`, each row `[e_in, e_out]` from the registry |
| `act` | int16 | `[ngroups, 4096]`, group-major, signed gate index plus 2048 |

Multipliers are the narrow c2 values before common-denominator group folding:
1 <= m <= 2^b, with q5/k5/v6/o8/g6/u4/d6. The loader derives all powers of
two for group input/output scale conversion; it does not accept caller-chosen
folded coefficients. Group IDs must be in range, every listed group must be
used, and duplicate group members should be refused/canonicalized once before
export hashing. At T128, 1 <= ngroups <= 4. The native table generator checks
every table word against its member, step and signed gate index.

The manifest `act` values are the raw quantized int16 words. The verifier
derives the scaled int64 table by multiplying each already-quantized word
by `2^(24-base_sh_h+e_out_group-e_out_layer)`. The product then has the common
shift 24 for LOW or 16 for LOW+h24. Both presets derive the same table
coefficients, bounded by 2^15 in the current class. Reject caller-supplied
scaled tables or folded multiplier arrays. Never regenerate a finer SiLU
table or move the group scale after product rounding.

The widened norm/attention words use [-32768,32767], per the coordinator's
19:50 rule and 20:00 approval after the endpoint audit. Preserve symmetric
int8 scores/weights and raw SiLU table bounds. See ENDPOINT_DOMAIN_AUDIT.md.

Keep the base per-layer constants separately from derived LOW shifts so a
consumer cannot apply the +8/-6/+b changes twice. Derive and bind effective
norm precision, F_P=12, site shifts and common group denominators in one
profile-aware constructor, then use that same public result for kernel,
witness, argument and statement construction. Score/exp calibration fixes
are already reflected in the base layer constants.

The loader must re-hash these arrays, bind their digests and typed values in
the model/calibration statement, and apply the existing support permutation
when padding query output multipliers. Multipliers for padded channels must
be fixed canonically (zero matrix outputs plus unit multiplier), not read as
additional caller data. Export fixtures and malformed-array tests must pass
before this draft is advertised as the actual A2 interface.
