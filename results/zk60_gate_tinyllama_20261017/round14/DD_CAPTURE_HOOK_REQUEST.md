# DD capture: what native R9's capture path lacks, and the exact hook request

Written 2026-10-20 06:10 UTC by the PRIVACY GATE lane (gate round 14, step 1),
for the coordinator and the native lane. **Not a privacy result.**

**Object:** native R9, `results/zk60_1b_native_20261017/r9/frozen-tree/`, tree
af90c703…. Read, not run.

## Finding: R9 cannot capture a DD run [READ]

Against R8, R9 changed **one line** of the capture writer:
`run_capture.rs:1376`, so that `run.json`'s `slots` list takes `sh.n_slots()`
entries. Everything else on the capture path still assumes 23 slots and the
non-DD plane list.

1. **The stage close refuses a 24-slot stage.**
   - `run_capture.rs:999` checks `cur.arguments.len() != N_SLOTS`, with
     `N_SLOTS = 23` (`layout.rs:913`).
   - At a DD profile, the verifier records 24 arguments (`argument.rs:2121`
     loops `0..sh.n_slots()`).
   - So every DD stage fails with "replay: stage k closed with 24 slots …",
     and no bundle is written.
2. **The plane index does not build at a DD layout.**
   - `plane_index.rs` is unchanged since R8.
   - Its name table has the non-DD A and H plane lists. A DD layout adds the
     following (`layout.rs` R9 hunks at `Ids::new` / `HIds::new`):
     - A: `P_dict` and `M_dd`;
     - H: `stuple`, the `Dom::Dd` byte helpers, and `gdd`;
     - and it moves the `p` / `rho_s` / `sigma_s` limb groups from `Dom::S`
       to `Dom::Dd`.
   - `plane_index::build` therefore refuses ("the A plane name table has N
     names for N + 2 planes", `plane_index.rs:242`). The capture then fails
     at stage open (`run_capture.rs:625-637`).
   - Its per-slot reference lists loop `0..N_SLOTS` (`:296`), so slot 23 has
     none.
   - Its `SC_SZC` list (`range(A_S8, sg(ls − 1))` plus `sexp`, `:406-410`)
     is the non-DD one. The DD variant reads `A_S8..A_P`, `A_MX`, `A_SUM`,
     the S helpers, `sexp` and `stuple` (`argument.rs` R9, `SC_SZC if
     sh.dd_cap > 0`).
3. **`run.json` misstates the DD shape.**
   - `"n_slots"` prints the constant `N_SLOTS` (`:1334`), so a DD bundle
     would say 23.
   - No shape key carries `dd_cap`, `log Dom::Dd`, `helpers(Dom::Dd)`,
     `TAG_DD`, `m_rows` or `n_functionals`.
4. **There is no capture test for a DD profile.** `run_capture_tests.rs` has
   none, and neither has the gate's own capture additions.

`run_capture.rs` and `plane_index.rs` are both `#[cfg(test)]`
(`private_block.rs:220-230`). Every change below is **test-only**, and no
production byte moves.

## The request (H-1 .. H-6)

**H-1. Stage close (`run_capture.rs:999`).**
- Compare with the stage's own slot count, not `N_SLOTS`:
  - record `lay.n_slots()` in the open stage at `stage_start`;
  - refuse unless `cur.arguments.len() == that`.

**H-2. `run.json` shape keys (`:1334`, allow-list near `:1700-1735`).**
- `"n_slots": sh.n_slots()`.
- Add these keys, each on the allow-list:
  - `"dd_cap"`: `sh.dd_cap`, 0 off DD;
  - `"dd_log"`: `sh.log(Dom::Dd)`, 0 off DD;
  - `"dd_helpers"`: `sh.helpers(Dom::Dd)`, 0 off DD;
  - `"tag_dd"`: 141;
  - `"m_rows"`: `sh.m_rows()`;
  - `"n_functionals"`: `sh.n_functionals()`.
- A non-DD bundle may omit them, so that no earlier bundle's key set moves;
  the gate reads their absence as `dd_cap = 0`.

**H-3. The plane index at a DD layout (`plane_index.rs`).**
- **Name table.** In plane order, matching R9's `Ids::new` DD segment
  table:
  - A: … `A_G8`×11 (F), `P_dict` (Dd), `pl`×lp (Dd), `sr`×ls (Dd), `sg`×ls
    (Dd), `M_dd` (Dd), `A_MU8`×3 (Tab);
  - H: … S helpers, `sexp`, **`stuple` (S)**, F helpers, `fact`, **Dd
    helpers ×`helpers(Dom::Dd)`, `gdd` (Dd)**, `gu8`×3, `u`.
- **Slot loop.** `0..lay.n_slots()`.
- **Slot 23's reference list** (exactly `argument.rs`'s `SC_DD` reads, in
  push order):
  - the A range `P_dict..=M_dd` (its tab reads `P_dict`, `pl`, `sr`, `sg`,
    `M_dd`);
  - the `A_SUM` slice on the leading (h, t) variables;
  - the Dd helpers;
  - `gdd`.
- **`SC_SZC`'s DD list:**
  - the range `A_S8..=A_P`;
  - `A_MX`;
  - `A_SUM`;
  - the S helpers;
  - `sexp`;
  - `stuple`.
- **`HIds::is_table`.** The plane index's table-helper mark includes `gdd`.
  This is the single value-0 sum claim, D30 (3).
- **Unchanged.** The existing invariants (tiling, push order,
  `every_plane_a_slot_references_is_in_the_plane_index`) must hold at the DD
  layouts. Please add their DD instances to `run_capture_tests.rs`.

**H-4. Slot 23's public table.**
- When `HL_RUN_CAPTURE_PUBLIC_TABLES=1`, the public `e` column
  (`ctx.public.dd_e_column(cap)`, `argument.rs` `SC_DD`) is recorded with
  the slot's other public tables, as every `b.public(…)` is.
- At `=0` it is length plus digest.
- If the recorder's public hook does not see it, record it explicitly.

**H-5. A DD capture test** (`run_capture_tests.rs`, `#[ignore]`d, the
existing env conventions):
- **`capture_a_dd_rung_run`**:
  - `Shape::rung_dd(&cal)` and `RUN_PROFILE_RUNG_DD` (T32, d256);
  - `HL_PB_CAPTURE_BLOCKS` = 1 or 2;
  - `HL_PB_INPUT` = `dense`, a generic honest witness with dense weights and
    heads that differ, or `zero`;
  - `HL_PB_CAPTURE_DIR`, `HL_RUN_CAPTURE_PUBLIC_TABLES`,
    `HL_TEST_SOURCE_COMMIT`.
- **`capture_a_tinyllama_t128_dd_run`**:
  - `RUN_PROFILE_TINYLLAMA_T128_DD`, through the trained door, at the export
    `results/zk60_fidelity_parity_20261019/exports/tinyllama_dg_rot1_T128`
    (the one R9's DD stack run used);
  - `HL_PB_FIRST_LAYER`, `HL_PB_CAPTURE_BLOCKS` = 1, 2;
  - `HL_PB_SEQ=ho00` with `HL_PB_INPUT` = `dense` or `zero`;
  - the trained-calibration shape keys. The gate adds those itself, with its
    usual capture patch.
- Both write schema `hashline-native-capture/5-run` with the H-2 keys.

**H-6. Source pins.**
- `OWN_SOURCE_FILES` already pins every file R9 changed on the DD path
  (`argument.rs`, `layout.rs`, `shape.rs`, `witness.rs`, `protocol.rs`,
  `wire.rs`, `pad.rs`, `hash_domain.rs`, `run.rs`, `plane_index.rs`,
  `trained_block.rs`, `trained_statement.rs`, `private_block.rs`).
- No change is needed. The H-1..H-3 edits move the `run_capture.rs` and
  `plane_index.rs` digests, which the gate re-reads (v17).

## Who builds it

All of H-1..H-5 is test-only. The gate has carried its own capture additions
in its tree copies every round (the trained-calibration keys, the stage-47
module). It can carry H-1..H-5 the same way, in a gate copy of R9
(`ops/zkp-mvp/trained-1b-gate-r9/`), and hand the patch to the native lane to
adopt.

**The coordinator's choice:**
- (a) the native lane builds H-1..H-5;
- (b) the gate carries them now, and the native lane adopts the patch.

The gate's port of slot 23 and the DD planes (v17) proceeds either way.
