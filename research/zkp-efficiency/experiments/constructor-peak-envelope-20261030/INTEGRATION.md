# Source-count handoff, not a production patch

`envelope.py::constructor(rows,n,q,rate,workers)` returns requested field and
digest payloads for the pinned CPU fallback PCS constructor. `proof_phases`
adds the A/M/H/SC_SZC owners of one block and two endpoints. It is incomplete
and cannot authorize admission. `workers` is a symbolic concurrency parameter;
only one-core small allocation skeletons ran. There is no CUDA capacity model.

Owner integration points are R13 `zkp-core/src/pcs.rs:766`
(`commit_zk_owned_with_tag`), `pcs/encode_buffer.rs::initialize_row`,
`hashline/src/zk.rs::mask_commit_tagged`, and
`hashline/src/private_block/protocol.rs::prove_core`. Native owner must repin
the active revision; this research does not port or review R14.

Before witness construction, a native observer should export a public-shape
manifest of requested and allocated capacity by owner, phase, memory location,
and backend. Include CPU fallback while a backend offer declines, simultaneous
constructors, idle pools, event-pending frees, errors and quarantine. Record
exclusive wall/device phases plus transfer/allocator waits. Keep commitment
owners through all downstream openings; a completed table fold is insufficient.

The public interface is conceptually
`reserve(shape, backend, concurrency, all_missing_reserves) -> bytes | unknown`.
All missing components must be explicit; `unknown` cannot mean zero. Required
components are listed in `phase-projections.json`. Public labels are observer
metadata, not authenticated completion or a soundness argument. Do not expose
private-data-dependent allocation/refusal details or alter refusal policies.

The small Rust `probe.rs` implements allocation patterns only: no native PCS,
NTT, hashing, transcript, RNG or security gate. Its global allocator measures
requested live layout bytes; it does not measure physical realloc overlap,
RSS, GPU pages or driver usage. Payload calculations exclude Vec headers and
capacity excess; observed small overhead is retained separately. Inputs are
synthetic dimensions and public source metadata only.

Result: frozen g79 T128, n=16384, A4577/H4390, q256, rate4. One H constructor
temporarily retains 2,621,440 B above its returned payload owner; two concurrent
constructors exceed a returned-owner-only budget by 5,242,880 B. This does not
make constructor serialization a compelling optimization: with witness and
other reserves omitted, the selected known phase maximum is SC_SZC
6,205,943,536 B (5.779735 GiB), while H construction is 5.563427 GiB.
Unknown witness capacity can change the phase ordering. No actual fit or speed
is established. Native complete-workload phase/capacity measurements take
priority over further toy admission schedules.

Validation commands: `run_bounded.py prepare`, then `compile`, then `audit`.
Run in a fresh copy to preserve finalized logs and hypotheses. Tests cover
216 metadata cases, 24 tiny constructor patterns / 240 observations,
4,600 checks and 249 accounting controls. The independent reference caught no
native defect. Self-review corrected an initial M-hash tree overcount;
the original result and code are retained in `initial-m-hash-overcount/`.

Only the main agent/Claude can decide whether to port the observer or change
scheduling. No integration, merge, mask reuse, spill of private state or
weakened privacy is authorized by this handoff.
