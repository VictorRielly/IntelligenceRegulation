# O6 review of the round-18 draft and implementation follow-up

**Follow-up:** the `/2` implementation now consolidates all eight slots into
one M and delays every opening until after both equalities. Targeted tests pass;
full validation is pending. The superseded draft's validation finished with exit
0, including 227 Rust tests, 31 IO/21 old process cases, two retained round-17
proofs and all four CPU frozen proofs. That evidence is retained under
`/tmp/zk60-round18`; new-code validation runs separately in
`/tmp/zk60-round18-final`. The U-2/full-block privacy obligations remain open.

The review below records the decision before that implementation change.

Victor requested a pause to check O6 before proceeding. O6 is delivered in
`d130de64e106ae83c1158ecda5ee50dff6316a30`, on `zk60-fable-review`. Its two
files are `ZK60_OPUS_SEAM_REVIEW.md` and
`results/zk60_opus_o6_seam_inventory.json` in that branch. The inventory's
SHA-256 is `fa9116639193c017cbcc6abe38aafdf25f84921bd905d9ee6184aaba9c368b17`.
Codex checked all 32 recorded source hashes against its actual read-time
revision `53982e7`; every one matches. O6 is a source inventory, with no cargo
run, new cryptographic attack, privacy verdict or closed blocker.

It reviews the round-17 source, not Codex's parallel round-18 implementation
`e8d4261`. Consequently its statements that no IO profile exists are historical.
Its construction obligations still apply to the new code. This review holds
round-18 acceptance and publishing; passing execution tests do not close them.

## The difference that changes the next implementation step

O6 sections 3.3, 4.3 and U-14 describe reserving **eight CFS slots in one FFN
mask commitment**, before the FFN challenges. That commitment would have 20
base rows. The equality arguments occur before its single opening and the
W/A/H openings.

The draft instead creates the base six-slot commitment (16 rows), completes
its opening and the W opening in `prepare`, and creates a separate two-slot
equality commitment (8 rows) in `finish`. The equality commitment does precede
its own challenges, and each owner opens only once, but this differs from the
planned schedule. The old per-commitment CFS analysis does not by itself
establish the privacy of the combined adaptive transcript. O6 U-14 raises the
same composition obligation for FFN/attention commitments; the draft adds it
even before attention exists.

**Next change:** reserve the two `(10,2)` equality slots alongside the six FFN
slots before the FFN M root. Retain M, its functionals and W/A/H in the private
pending owner; add both equality arguments before a single M opening and the
W/A/H openings. Change the new profile's bounded codec accordingly and rerun
the affected and frozen checks. Keep the new IO domain distinct from archived
profiles. This removes the extra CFS commitment; it does not complete the full
joint privacy argument.

## Disposition of O6's fifteen unresolved items

| O6 item | Draft status and remaining obligation |
|---|---|
| U-1 public attention peer | Still open for a block. The draft uses two separately hiding endpoint planes; it does not attach the FFN to public attention or prove that an endpoint came from attention. |
| U-2 joint seam privacy | Open. Five base A groups become seven, with shared X/z16 data rows and fresh mask pairs. No IO capture or joint analysis exists; old O2 captures exclude the new profile. |
| U-3 consumption | Implemented for this fixed two-endpoint API: private non-Clone owners, fixed slots/row offsets, both equalities required, consuming `finish`. No general block RoleSet/attention lifecycle exists yet. |
| U-4 shared ownership | Implemented only for the FFN plus two standalone endpoints. A future block owner must retain actual attention and FFN commitments together. |
| U-5 transcript order/header | New domain and expected roots/context are bound. Full approved-block contract/manifest/P3-slot fields are absent. Consolidate M and defer all openings as above; a label-by-label schedule test remains useful. |
| U-6 wire collision | Addressed with the distinct `HFFNIO` envelope, fixed seven A groups, extra rows, external expected policy and bounded decoder. The codec must change again with the consolidated M. Old profile remains unchanged. |
| U-7 seam slots | Draft pins two `(10,2)` slots, each L=22, in code and exact frame/round tests. Move them into the full FFN manifest. |
| U-8 scale/class semantics | Context/scales are transcript-bound and the CLI pins -3/0. The API proves field-word equality; an approved calibration/block contract must authenticate represented-value semantics. Still open for complete blocks. |
| U-9 copied-plane substitute | FFN-side addressed: left claims always use the real A's `lay.x[0]` and `lay.z[0]`. Fully recommitted wrong endpoint planes decode and fail their actual equality sumcheck. Endpoint policy alone does not prove attention computation. |
| U-10 generated-mask checks | Still a test-build assertion; production fills every reserved row through fresh OS randomness. Fresh-root checks alone cannot prove distinct mask values. Add direct allocation/use and cross-attempt mask-value controls; a runtime duplicate check is not a replacement for the randomness argument. |
| U-11 proximity pair | `check_masks` is the production guard: it replays the PCS prefix and requires the two reserved coefficients to span Fp2. Draft applies it to combined A, H/P3-W and both endpoints. Deterministic dependent-pair controls now exist. Per-group role exclusivity needs explicit review. |
| U-12 late table guard | Moved before repaired table terminal formation/use. Equality c/e degeneracies return errors without redrawing and consume pending owners. |
| U-13 seeded APIs | The new API accepts no seed, config or caller RNG and creates fresh OS streams. Legacy seeded entry points remain separate and cannot construct the opaque IO receipt. No global removal of seeded experimental APIs is claimed. |
| U-14 multiple M commitments | Open construction obligation; remove the draft's avoidable second M as described above. A future private-attention block still requires its own combined analysis. |
| U-15 reuse rho_d | Not selected. The draft draws independent equality challenges after expected endpoint and FFN roots, with separate precommitted pairs. Do not substitute existing masked terminals as clear values or optimize away groups without analysis. |

At review time all 227 storage-enabled Rust tests passed on `e8d4261`; the
detached CPU/process/frozen validation is still running under
`/tmp/zk60-round18/validate.py`, with progress in `summary.json` and completion
in `validation.done`. Those results concern the draft and must not be reused as
validation of the planned M change. No round-18 push or privacy acceptance has
been made. O5's four files are also visible, uncommitted, in Opus's worktree;
they have not been copied, altered or integrated by this review.
