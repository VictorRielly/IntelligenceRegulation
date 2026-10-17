# Review handoff: exact row-tiled FFN-down and requantization

Run `20261004T050146Z-1f54a8f9`, cycle0023, 2026-10-04 UTC. **Arithmetic and
scheduling prerequisite only; no measured proving improvement.** Research-only
files; do not merge or describe this as a working device adapter.

The integration seam is read-only candidate
`hashline/src/private_block/witness.rs:685`: replace only
`quantize(&matmul_in_out(...), &sup_d, SH_Z, ... "FFN down")`
with an exact tiled helper returning the same full-domain `Vec<i64>` z16/RDL.
The raw down accumulator is temporary; it is not a proof plane. Keep h16,
all support/pad words, residual2 and limb generation, and every proof/mask step.
Column sums must bind the exact public immutable weights and consumed padded
K, not merely a model name. P3 requires sums/packing to stay private.

`experiments/tiled-down-requant-20261004/tile-review.rs` is an **uncompiled,
unapplied Rust interface sketch**, not a native patch. Full-K input tiles carry
two exact i32 byte-product outputs (or the equivalent stacked output), a
column-sum slice and public row/column metadata. Reconstruct in i64, correct
once, then round SH_Z6 nearest/ties toward +infinity and retain biased
remainder. Split-K uses i64 reductions before final rounding. Device work
would require new GEMM/reconstruction buffers beside
`hashline/src/gpu/cuda.rs` and `kernels.cu`; existing pooled u64 field buffers
and commitment upload/NTT are not automatically suitable integer GEMM buffers.

Validation retained at `experiments/tiled-down-requant-20261004/`:
260 differential schedules,3380 independent raw dots (including refused
cases),9508 accepted plane words,162 rounding edges,14 controls plus2 domain
controls. Exact checked direct-i64/floor-div reference, both weight
orientations, K/output ragged tiles, forward/reverse completion, dirty K and
ignored output/token padding, K up to262146 with bounded partials.
Final1.252728s/23096KiB RSS, one low-priority CoreUltra9 185H thread. Source
snapshots/hashes, seed2026100423, command/logs/exit0 and limitations retained.
The initial nondiscriminating overflow control failure is preserved; final
checks compare raw dots independently rather than relying on refusal parity.

The counterexample that matters for fusion: j0 can fail residual while j1
fails down. The original site order returns **down**, so checking residual
inside an early output tile changes behavior. Delay all residual work until
down succeeds globally. Public parallel completion also must not change
first-support status where a caller can observe it. Status/indices stay
private; no new diagnostic is published or absorbed/drawn.

Count-only unadmitted Llama3-8B metadata T512/Kpad16384/N4096 local ledger:
materialized split48MiB peak after releasing packed/partials at last reads.
Coarse64-row/full-N/full-K route36MiB with8 conceptual stacked GEMMs;
64×128/full-K34.0625MiB with256; 64×128/K1024 32.25MiB with4096 and512MiB
packing. Untiled streaming preallocation64MiB is **16MiB worse**. Final
z16/RDL32MiB never removed. Naive64-row weight reads512MiB versus64MiB once;
cache/DRAM costs unknown. Omits workspace, transfers, pools/mirrors, existing
other planes/preallocated destination placeholders; not whole-builder peak.
Prefer coarse row tiles for a first measured adapter, and demote small N/K
tiles until packing/launch overhead is resolved. Partial memory counts are
not a kernel/proof speed claim.

Before a device A/B, owner isolates initial/per-stage witness builds and
FFN-down clocks from boundary/A-fill/wire/sink. Current timers combine them.
Require complete native witness bytes, pad/support/refusal, RNG continuation,
masked transcript and receipt parity, fresh per-proof randomness, actual
peak/transfer/workspace evidence and independent full-stack verification.
Build/GPU/proof jobs require acknowledged ownership and the shared resource
guard/heavy/build locks; this researcher launches none. Keep unchanged CPU
fallback for unsupported accelerator shapes; no new legacy refusal/domain
restriction or clamp/float approximation.

End-to-end bound: P/(T-C_down_all_builds+C_pack+C_upload+C_byte_GEMM+
C_reconstruct+C_download+C_sync), all accepted8B terms unknown. Falsify on
any value/remainder/support/refusal/RNG/receipt mismatch or enclosing cost/
peak regression. The retained synthetic125M12-block408.609226s cold
diagnostic independently verifies false and counts no target tokens.
Deleting both entire73.36/86.691s parents still leaves248.558226s; loose
accounting bound only. No >=50/s claim follows.

Next local question: public grouped/strided tile schedule that reuses row
packing and limits outstanding partials while reducing the multiplication
of calls/repacking. Use independent address/ownership/completion oracle;
device scheduling/cost stays owner work. Native SC_SZC/witness recurrence
remains the top measured-impact owner lane. Preserve prior slower fusion
and all other negative findings.
