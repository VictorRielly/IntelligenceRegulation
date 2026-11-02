"""Gate round 26, run-level reader: build READINGS_R26_RUN.json and the diffs.

Read-only on source.  Writes only under results/zk60_gate_tinyllama_20261017/round26/.
Usage: python3 build_r26_run.py  (no arguments; absolute paths inside)
"""
import hashlib, json, os, re, subprocess, sys, tempfile

REPO = "/Users/victorrielly/IntelligenceRegulation"
HL = "ops/zkp-mvp/gpu-metal/hashline"
R19B_ROOT = os.path.join(REPO, "results/zk60_token_io_r1_20261017/frozen-r19b")
R19B_MAN = os.path.join(REPO, "results/zk60_token_io_r1_20261017/manifest_final_r19b.sha256")
OUT = os.path.join(REPO, "results/zk60_gate_tinyllama_20261017/round26")
RD = os.path.join(OUT, "readings")
RD_REL = "results/zk60_gate_tinyllama_20261017/round26/readings/"
D60_MAN = os.path.join(REPO, "results/zk60_d60_20261102/privacy_gate/bundle_manifests/d55-r13_rung_h24-s0/manifest.json")
D60_COMMIT = "dd81ab4f"


def sha(b):
    return hashlib.sha256(b).hexdigest()


def git_show(rev, rel):
    r = subprocess.run(["git", "-C", REPO, "show", f"{rev}:{rel}"], capture_output=True)
    return r.stdout if r.returncode == 0 else None


def head_commit():
    return subprocess.run(["git", "-C", REPO, "rev-parse", "HEAD"], capture_output=True, text=True, check=True).stdout.strip()


def udiff(old, new, la, lb):
    with tempfile.TemporaryDirectory() as td:
        a, b = os.path.join(td, "a"), os.path.join(td, "b")
        open(a, "wb").write(old or b"")
        open(b, "wb").write(new)
        r = subprocess.run(["diff", "-u", "--label", la, "--label", lb, a if old is not None else "/dev/null", b], capture_output=True)
        return r.stdout


def parse_hunks(d):
    out, cur = [], None
    for line in d.decode(errors="replace").splitlines():
        m = re.match(r"@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@", line)
        if m:
            nn = int(m.group(4) if m.group(4) is not None else 1)
            cur = {"r19b_at": int(m.group(1)), "head_lines": [int(m.group(3)), int(m.group(3)) + nn - 1], "plus": 0, "minus": 0}
            out.append(cur)
            continue
        if cur is None:
            continue
        if line.startswith("+"):
            cur["plus"] += 1
        elif line.startswith("-"):
            cur["minus"] += 1
    return out


def stat(d):
    lines = d.decode(errors="replace").splitlines()
    plus = sum(1 for l in lines if l.startswith("+") and not l.startswith("+++"))
    minus = sum(1 for l in lines if l.startswith("-") and not l.startswith("---"))
    return plus, minus, sum(1 for l in lines if l.startswith("@@"))


# ------------------------------------------------------------------ the trees
def check_r19b():
    listed, moved, seen = 0, [], set()
    for line in open(R19B_MAN):
        p = line.split()
        if len(p) != 2:
            continue
        listed += 1
        path = os.path.join(R19B_ROOT, p[1])
        seen.add(p[1])
        if not os.path.isfile(path) or sha(open(path, "rb").read()) != p[0]:
            moved.append(p[1])
    unlisted = []
    for top in ("hashline", "zkp-core", "private-block-kernel", "private-block-kernel-shaped"):
        for dp, _, fns in os.walk(os.path.join(R19B_ROOT, top)):
            for fn in fns:
                rel = os.path.relpath(os.path.join(dp, fn), R19B_ROOT)
                if rel not in seen:
                    unlisted.append(rel)
    excl_text = open(os.path.join(REPO, "SNAPSHOT_20261017_EXCLUDED_LARGE_FILES.json")).read()
    missing = [m for m in moved if not os.path.exists(os.path.join(R19B_ROOT, m))]
    differing = [m for m in moved if m not in missing]
    excluded = [m for m in missing if ("frozen-r19b/" + m) in excl_text]
    source_bad = [m for m in moved if m.startswith(("hashline/", "zkp-core/"))]
    return {"tree": "results/zk60_token_io_r1_20261017/frozen-r19b", "manifest": "results/zk60_token_io_r1_20261017/manifest_final_r19b.sha256",
            "manifest_list_sha256": sha(open(R19B_MAN, "rb").read()), "listed": listed, "rehash_equal": listed - len(moved),
            "moved_or_missing": moved, "differing": differing, "missing": missing,
            "missing_listed_in_SNAPSHOT_20261017_EXCLUDED_LARGE_FILES": excluded,
            "note": "the missing files are binary receipts under frozen-r19b/results/ (> 1 MiB) left on the laptop at the Mac move (CLAUDE.md, machine change 2026-10-31); no hashline/ or zkp-core/ source file is missing or differs",
            "unlisted_on_disk_under_listed_roots": sorted(unlisted)[:40], "unlisted_count": len(unlisted),
            "ok_for_every_source_file": not source_bad and not differing, "ok": not moved}


def r19b_digests():
    d = {}
    for line in open(R19B_MAN):
        p = line.split()
        if len(p) == 2:
            d[p[1]] = p[0]
    return d


def pin_lists():
    rc = git_show("HEAD", HL + "/src/private_block/run_capture.rs").decode()

    def arr(name):
        m = re.search(r"const %s: \[&str; (\d+)\] = \[(.*?)\];" % name, rc, re.S)
        items = re.findall(r"\"([^\"]+)\"", re.sub(r"//[^\n]*", "", m.group(2)))
        assert len(items) == int(m.group(1)), name
        return items
    return arr("OWN_SOURCE_FILES"), arr("SHARED_SOURCE_FILES"), arr("CLASSIFY_SOURCE_FILES")


# ------------------------------------------------------------------ ownership
MINE = ["src/private_block/run.rs", "src/private_block/run_fork.rs", "src/private_block/run_fork_wire.rs",
        "src/private_block/run_capture.rs", "src/private_block/wire.rs", "src/private_block/hash_domain.rs",
        "src/private_block.rs", "src/private_block/trained_block.rs", "src/private_block/plane_index.rs",
        "src/private_block/tied_tables.rs", "src/private_block/token_io/load.rs",
        "src/private_block/token_io/classify_run.rs"]
UNPINNED_READ = ["src/private_block/token_io/classify_batch.rs", "src/private_block/token_io/classify_cli.rs"]
# W16_READINGS (staging_v25 zk60_native_rg_w16.py) digests, already read there
W16_READ = {"../zkp-core/src/transcript.rs": "e766e9e14304", "../zkp-core/src/pcs.rs": "856929b34333",
            "../zkp-core/src/merkle.rs": "6b66c0bcf200", "../zkp-core/src/rng.rs": "f6728bd2d520",
            "../zkp-core/src/pcs/backend.rs": "4f03047ac467", "../zkp-core/src/mle.rs": "ed7f8849f48d",
            "src/gpu/mod.rs": "d7812f7d9404", "src/private_block/run.rs": "b9b40cadef4a",
            "src/private_block/run_capture.rs": "d10d33e3e04f"}

# ------------------------------------------------------------------ the readings
T, N, R, C = "test-only", "production-privacy-neutral", "privacy-relevant-safe", "capture-content-safe (test-only module; privacy-relevant: it changes what a capture writes)"

HUNKS = {
    "src/private_block/run_capture.rs": [
        (C, "OWN_SOURCE_FILES [38] -> [44]: the manifest's `source_pins` list (public file names and their SHA-256). Capture metadata only"),
        (C, "the six pins added: range16.rs, slot_ir.rs, slot_ir_accuracy.rs, metal_slot.rs (M26), run_fork.rs, run_fork_wire.rs (D60). Pure addition; no field renamed or removed"),
        (T, "`#[derive(Clone)]` on `RunHeader` (per-fork recorders each hold a copy). No byte written"),
        (C, "`ArrayStore::absorb_store` (:792-836): merges a per-fork recorder's array store into the run's. It copies only arrays a per-fork recorder already stored through the ordinary writer (verifier-view values), content-addressed (an array both hold is kept once; a length disagreement or an out-of-store offset is refused), and rewrites only the `offset` of each `{\"array\":...}` reference. Nothing is added that a recorder did not already write"),
        (T, "`Rec.fork` and `ForkRec` (:931-969): recorder state between phases (the head's roots, the recorder's own S0 / S1, each fork's end position in its per-fork recorder's own replay, the tail's records). In memory; written only through H13 / H7's tail file"),
        (T, "`rebuild_header` (:1026-1050) factored out of `begin_run_with`: the same seven / nine absorbs in the same order (moved text, compared line by line); `Rec` gains `fork: None`. A block, token or classifier capture replays byte for byte as before"),
        (C, "THE FORK-RUN RECORDER (:1076-1432): `begin_fork_run_with` (refuses a token / classifier header), `replay_fork_commit`, `fork_commit` (the recorder's OWN S0, compared with the verifier's), `ForkSeed` (:1157: header, binding, roots, options -- public words only), `fork_seed`, `fork_stage_attach` (a FRESH recorder per verifier worker, its own transcript rebuilt from the public header and roots, then `pb-run-fork` k / `pb-run-fork-block`), `fork_stage_begin`, `ForkStageCapture`, `fork_stage_take`, `fork_stage_merge` (block order; plane index must equal the run's), `join_claim_words`, `fork_join` (own S0, each per-fork recorder's own END state and counter, and the verifier's claim lists -- public words the verifier computed), `fork_tail_end` (writes the tail file: schema, kind, blocks, end_tag, opening_order, header = S1 state and next challenge, roles = the ordinary `write_pcs` records of the B_k and endpoint openings, transcript_sites), `fork_stage_view` (in memory), `SCHEMA_D55`. Every key is on the unchanged `ALLOWED_KEYS` (:4035-4360). The recorder is attached ONLY on the verifier side (run_fork.rs capture call sites :1279-1476 are all in `verify_one_fork` / `verify_run_with_forks`); no prover value or randomness is reachable"),
        (T, "`stage_begin` -> `stage_open(.., d12a_prefix = true)`: identical for a D12a stage"),
        (T, "the D12a locality absorbs (`pb-run-stage`, `pb-run-block`, B / rows / log-cols) behind `d12a_prefix`: identical replay for D12a; a fork's start absorbs were replayed at attach"),
        (T, "a closing brace"),
        (C, "the call site takes `statement_table_at(&def.sh, ..)`: which `Tab::Pub` tables are labelled statement tables (and so carry values only after the export replay)"),
        (C, "the `pcs` hook also records with no stage open when a fork run's tail is open (:2316-2325); a D12a / token / classifier recorder (fork = None) returns exactly as before"),
        (C, "the tail's openings go to `tail_roles` / `tail_sites` / `tail_role_names` (:2345-2363): the ordinary `write_pcs` record (claims, masked vectors, Q opened columns with their published salts and paths) and the before / after transcript states"),
        (T, "`Bundle.fork_tail` field"),
        (C, "`take()`: a fork run's bundle exists only once its tail closed (a refusal); every other Bundle gains `fork_tail: None`, byte for byte as before"),
        (C, "`statement_table_at` (:2548-2556): at a W16 shape SC_TAB's ACT support (index 4 + #sub, of 5 + #sub + #narrow) is the one statement table; R13 / legacy stages return `r13_statement_table` unchanged. Public tables only"),
        (T, "the export replay accepts W16's `act_support` as R13's fifth table (a check of recorded values, no write)"),
        (C, "`write_stage`: a fork stage file declares SCHEMA_D55 (a string)"),
        (C, "`write_run`: SCHEMA_D55 and `(in_at, out_at) = (L, L)` for a fork run; `(0, L-1)` otherwise (unchanged)"),
        (C, "`external_endpoints.opened_at_stage` first value from `in_at` (0 for every non-fork run, as before)"),
        (C, "second value `out_at` (L-1 for every non-fork run, as before)"),
        (C, "each boundary's `committed_at_stage` / `opened_at_stage` / `opening_in_stage_file`: 0 / L / L for a fork run (head, tail), i / i+1 / i+1 otherwise (as before). Public layout facts"),
        (C, "`stage_files` lists `d55_tail.json` after the L fork files (fork run only)"),
        (C, "`transcript_labels` / `transcript_program` from the D55 tables for a fork run, with the registered wording at line 0 and at `parameters` (text only; no transcript byte); `mask_domain.columns` = `zk::MASK_Q` (256) instead of `sh.opened_cols`: equal (256) at every shape but W16R2, where 256 is M's real opened-column count"),
        (C, "`D55_TAIL_FILE`, `D55_TRANSCRIPT_LABELS` [26], `D55_REGISTERED_PROGRAM_HEAD`, `D55_REGISTERED_PARAMETERS_TEXT`, `D55_TRANSCRIPT_PROGRAM` [10] (:3331-3387): descriptive text written into run.json"),
        (C, "token-run `mask_domain.columns` = `zk::MASK_Q` (value-identical: no token profile opens other than 256; W16R2 token runs are refused by the D27 counters)"),
        (C, "classifier-run `mask_domain.columns` = `zk::MASK_Q` (value-identical, as H26)"),
        (C, "`write_fork_bundle` (:4408-4466) and `write_bundle`'s dispatch (:4468-4480): a fork bundle is written only under a REGISTERED D55 profile (a test-only identity is refused) and only after the export replay if it carries statement-table values; files `run.json`, `stage-NN.json`, `d55_tail.json`, `arrays.bin`, the receipt's own frames under `receipt/` (head, forks, tail: exactly the bytes the verifier read -- a published receipt), `README.md` (caller's note and command), `manifest.json` LAST; every file `create_new` (never over an existing one)"),
    ],
    "src/private_block/plane_index.rs": [
        (C, "`build` -> `build_with(lay, true)`; the W16 additions apply only where `AccuracyIds::w16` is set (`w16_low`, :253): at every R13 and legacy layout the table is byte for byte r19b's"),
        (C, "W16: one TABLE helper name `H_GR{w}_{s}` per range sub-plane spliced after `H_GACT` (:278-286): public plane names"),
        (T, "W16: a refusal unless every range sub-plane is the pair (A_R, H_GR) on Dom::Tab (:322-335): a check"),
        (C, "`slot_planes(lay, slot, w16)` signature and doc (:373-382): which push order a slot records"),
        (C, "W16 push orders for SC_SZC (the whole Dom::S range, A_MX, A_SUM, helpers, H_SEXP) and SC_TAB (three pairs, then one (histogram, table helper) pair per range sub-plane) (:464-484); never taken at R13. Public layout (ids, names, rows)"),
    ],
    "src/private_block/run.rs": [
        (R, "D60's registry (:234-288): `D55_REGISTERED_MARKER` (50 bytes), the twelve `RUN_PROFILE_D55_R13_*` strings, `D55_RUN_PROFILES`, `d55_run_profile`. Each string becomes a fork run's transcript-constructor domain (what is absorbed / keyed). SAFE: public constants; checked here: every string = `hashline-zk-mr1/` + marker + its base's tail (12 / 12), constructor inputs 107 / 125 / 129 bytes (`ForkRun::census` holds them clear of every absorb length). No witness word; `registered_block_shape` (CS-7) names none, so no D12a run can hash under one"),
        (T, "`#[cfg(test)]` arm in `registered_block_shape` admitting the W16 TEST-ONLY run identities (:324-330); absent from every production build"),
        (R, "`NOFOLLOW_NONBLOCK` per target and `open_nofollow_nonblock` (:1625-1680), the one read-only open of every bounded reader (receipt segments and frames, statement files, token tables). SAFE: read-only, stricter (adds O_NOFOLLOW | O_NONBLOCK on macOS 0x0100 | 0x0004 and aarch64 Linux 0o100000 | 0o4000, checked against the platform ABI; x86-64 Linux unchanged 0o400000 | 0o4000); callers keep the lstat / fstat re-checks; the before-open hook is `#[cfg(test)]`"),
        (N, "doc comment of `read_segment_bounded` (:1695-1700)"),
        (R, "`read_segment_bounded` opens through `open_nofollow_nonblock` (:1715); the error text is unchanged (segment index, path, OS error, lengths: no witness word, the verifier holds none)"),
        (N, "doc comment line (:1735)"),
        (R, "`read_regular_file_bounded` opens through `open_nofollow_nonblock` (:1752); error text unchanged (path, OS error)"),
        (N, "`#[path = \"run_fork.rs\"] pub(crate) mod fork;` (:1764-1771): the declaration; the module is read in full under run_fork.rs"),
    ],
    "src/private_block/wire.rs": [
        (R, "M's frame geometry from zk.rs's own constants (:16-31): MASK_VEC = 2 << MASK_LOG_MSG = 1024, MASK_DOM = 1 << MASK_LOG_DOM = 4096, MASK_PATH = 12 (value-identical to the literals), and MASK_CHECKS = zk::MASK_Q = 256 replacing the block's `bd.checks`. SAFE and protective: M's frame now carries exactly MASK_Q opened columns, which is the number of pads per M a-row (zk.rs:375, :445 / :496); at every pre-W16R2 profile bd.checks was 256 (no byte moves); at W16R2 (A / H / B / endpoints at Q = 260) M is never framed with more columns than it has pads"),
        (R, "D12a block-receipt counted length: M term uses MASK_CHECKS (:137)"),
        (R, "block validation: M columns must be MASK_CHECKS (:157)"),
        (R, "block decode reads MASK_CHECKS M columns (:265)"),
        (R, "segment counted length: M term uses MASK_CHECKS (:357)"),
        (R, "segment validation (:392)"),
        (R, "segment decode (:481)"),
        (N, "`#[path = \"run_fork_wire.rs\"] pub(crate) mod fork;` (:496-500): the declaration; read in full under run_fork_wire.rs"),
    ],
    "src/private_block/hash_domain.rs": [
        (N, "`path_labels` is no longer `#[cfg(test)]` (:449-456): a pure function of the shape and the run parameter line returning label names and data LENGTHS; its one production caller is `ForkRun::census` (run_fork.rs:646), a refusal guard. Absorbs nothing, writes nothing"),
    ],
    "src/private_block.rs": [
        (N, "`mod range16;` (W16, production declaration; reached only at the unregistered W16 profiles; the module is a block-level file, read by the other reader) and two `#[cfg(test)]` modules (range16_tests, w16r2_tests) (:68-75)"),
        (T, "`#[cfg(test)] mod w16_privacy_gate_tests;` (:277-281)"),
        (N, "`slot_ir` compiled under `any(test, feature = \"gpu-metal\")` and `metal_slot` under `gpu-metal` (:394-400): declarations; their content (the Metal round sums) is the block reader's. `ExpectedIo`, `IoSpec`, `calibration_identity` and `BlockPublic::digest` are outside the hunks; `#[cfg(test)] mod run_capture;` (:266-267) and `#[cfg(test)] mod plane_index;` (:275-276) unchanged"),
    ],
    "src/private_block/token_io/load.rs": [
        (N, "`TABLE_OPEN_FLAGS` removed (:33-35)"),
        (N, "the token-table open goes through `run::open_nofollow_nonblock` (:130): public token tables, re-checked by fstat and then digest-checked as before; error text unchanged (path, OS error)"),
    ],
    "src/private_block/tied_tables.rs": [
        (N, "`use std::fs::File` (OpenOptions no longer used)"),
        (N, "`regular()` opens through `run::open_nofollow_nonblock` (:30): the public checkpoint / table reader; size, regular-file and (dev, ino) identity re-checks unchanged; the bytes are then authenticated by the size / whole-file SHA-256 / tensor pins (derive.rs, unchanged at 1d615010). macOS now refuses a symlinked model FILE at open, as Linux x86-64 did (REVIEW_R19B N-6)"),
    ],
    "src/private_block/trained_block.rs": [
        (R, "`render_fork_frames_json` (the published segments.json of a D55 run: frame names, lengths, SHA-256), `D55_TEST_RECEIPT_FLAG`, `d55_prove_admission` (F3: (workers, no ack, gate false) -> Err; ack without workers -> Err; never affects D12a), `d55_workers_of` (1..=64), `load_fork_blocks` (public blocks, each digest-checked against the statement) (:2668-2735). SAFE: public words; fail-closed"),
        (R, "`D55_RUN_CONSTRUCTION` and `render_stack_statement_for(.., fork)` (:2882-2896): a D55 statement adds `base_run_profile` and `run_construction` (public strings); with `fork = None` the fragment is `\"run_profile\": <js>`, so a D12a statement renders byte for byte as before (trained digests unchanged in the close gates)"),
        (R, "statement format string takes the fragment (:2910)"),
        (R, "the fragment argument (:2918)"),
        (N, "doc and the flag lists (`--d55-workers`, `--d55-test-receipt-not-for-publication`) (:2996-3015)"),
        (R, "`--d55-workers` parse, `--lie-at-boundary` refusal, F3 admission BEFORE anything is read or created (:3045-3053)"),
        (R, "the D55 proving pass (:3109-3184): `ForkRun::new(.., registered_profile())` before the directory exists; `prove_run_with_forks` over the same `StackSource` and endpoint owners as D12a; `write_fork_receipt`; the marker after the frames when acknowledged; stdout events `d55` and `d55-proved` (workers, frame count, receipt bytes, phase seconds, per-fork prove_core seconds, generator count, joined-claim byte total) -- prover stdout, prover-private by P-6 like D12a's per-segment `elapsed_seconds`. A failure removes the run directory (`fail_run`, errors to stderr only)"),
        (R, "in-process verification of a fork run reads the frames back through the D55 directory reader (:3193-3201)"),
        (R, "`segments.json` names the frames for a fork run (:3222-3223)"),
        (R, "the statement and segments.json rendered for the fork run, in-process and unverified (:3232-3240)"),
        (N, "`receipt_bytes` in the `proved` event = the sum of the frames written (:3248)"),
        (N, "doc and the verify flag list (:3284-3296)"),
        (N, "`--d55-workers` at verify; refuses `--controls` with it (:3317-3321)"),
        (R, "the D55 verifier from the artifact directory (:3379-3401): the registered door, fresh blocks, `verify_run_with_forks_from_dir`"),
        (R, "F3: the `d55-publication` event on every D55 verification (:3409-3427): marker present / ABSENT, gate state, `not_for_publication = marked || !gate` -- true for every D55 receipt while the constant is false"),
        (R, "the verifier's segments.json for a fork run (:3441)"),
        (R, "the found statement must be, byte for byte, this verifier's fork-aware rendering (:3449)"),
        (R, "the VERIFIER-written statement for the fork run (:3464)"),
    ],
    "src/private_block/token_io/classify_run.rs": [
        (N, "`t_seal` (:129): a clock"),
        (N, "sealing-pass duration printed only when `timing::enabled()` (HL_PB_TIMING) (:147-150)"),
        (N, "`ph.mark` after the block load (:187): write-only, returns on its first line unless enabled (timing.rs:239-243)"),
        (N, "phase marks (B_k commitment words, witness, B_(k-1) opening claim count, frame encode / sink bytes, drop) and `ph.report` (:195-221): public sizes and durations, env-gated, write-only"),
        (N, "pre-header check duration (:265-276)"),
        (N, "`t_stage` (:284)"),
        (N, "stage IN-C duration; the verifier's phase recorder now starts before the block load (:301-307)"),
        (N, "verifier phase mark for the B_(k-1) opening (:363)"),
        (N, "`ph.report(\"verify\")` and `t_stage` (:371, :376)"),
        (N, "stage OUT-C duration (:386-389)"),
    ],
    "src/private_block/token_io/classify_batch.rs": [
        (R, "the batch request's open flags come from `run::NOFOLLOW_NONBLOCK` (:46-48): x86-64 Linux unchanged; macOS and aarch64 Linux now open the OWNER's private request file with O_NOFOLLOW | O_NONBLOCK instead of refusing every request at run time; a target without values still refuses (:119). SAFE: open-only change, the owner-only / regular / <= 64 KiB checks unchanged (:123-125), the request content is never echoed in an error (`batch request: {e}` is the OS error)"),
    ],
    "src/private_block/token_io/classify_cli.rs": [
        (N, "`cli_phase` (:563-569): one wall-clock line per CLI phase under HL_PB_TIMING; durations only")] + [
        (N, "a `cli_phase` / `tp` line (diagnostic)")] * 4 + [
        (N, "GPU device statistics (seconds, byte counts, declines, VRAM peak) printed under HL_PB_TIMING (:663-668)")] + [
        (N, "a `cli_phase` line (diagnostic)")] + [
        (N, "verify duration under HL_PB_TIMING (:735-737)")] + [
        (N, "INSIDE `door` (:743-798): `let mut tp` and `cli_phase(\"verify\", ..)` lines (:749-750, :767, :795) -- diagnostic only")] * 3,
}

SECTIONS = {
    "src/private_block/run_fork.rs": [
        ((1, 73), N, "module doc"),
        ((77, 101), R, "`D55_REAL_CONTENT_PRIVACY_GATE_PASSED = false` (:101): F3's precondition in code; only a coordinator commit flips it; flipping moves no receipt byte"),
        ((102, 147), R, "transcript identities: `D12A_LINE_TAIL`, `D55_LINE_TAIL` (36 B), `D55_SCHEDULE_LITERAL` (registered); the prototype's prefix, clause and literal and `d55_profile_of` / `fork_profile_for` are `#[cfg(test)]`. Public constants absorbed into the header"),
        ((149, 182), N, "`D55_LABELS` and `io_claim_list_len`: census lengths"),
        ((184, 187), R, "the two generator domains (commit phase; one stream per fork)"),
        ((189, 296), T, "`DROP_FORK_INDEX`, `PANIC_IN_FORK`, `PanicInEveryFork`, `DropForkIndex`, `ForkHooks` and its guard: all `#[cfg(test)]`"),
        ((298, 345), N, "`D55OptIn` (production: `registered_profile()` only; `unreviewed_prototype()` is test-only), `no_registered_profile` (production arm refuses by name)"),
        ((347, 369), R, "`ForkRun` and THE RANDOMNESS NOTE (:361-369): L + 1 generators, each `ZkRng::from_os` under its own domain, built on the thread that uses it, none cloned or derived, no seeded arm"),
        ((371, 384), R, "`commit_seed_domain` / `fork_seed_domain`: SEED_USE ‖ ROLE_RUN_PROVER ‖ (k as u64 le) ‖ profile -- domain separation on top of independent OS entropy"),
        ((386, 430), N, "`ForkReceipt` (head, forks, tail) and `ForkStats` (prover-local timings, generator count, joined-claim byte lengths)"),
        ((432, 530), N, "`ForkTamper` is `#[cfg(test)]`; `Cheat` in a production build is the honest prover's constants (`on` / `forge` false, `fork_index(k) = k`, `skipped_root` None, `claim_not_joined` / `claim_not_opened` false)"),
        ((532, 612), N, "`ForkRun::new` (refuses token / classifier bases, a drifted registry entry, a string CS-7 admits; runs `parameter_line` and `census`), `new_test_identity` (test), `is_registered`, `line_tail`, `schedule_literal`"),
        ((614, 681), N, "`census`: the W-2 length rule (constructor vs every absorb length; seed-derivation inputs not 64 / 40 / 47). Lengths only; a refusal"),
        ((683, 740), R, "`parameter_line` (D12a line with its last clause replaced), `schedule_digest` (BLAKE3 over the literal and u64-framed lines), `schedule_lines` (parameter line, `Layout::describe`, counts, each fork's D12a stage line, the phase-3 order): functions of the statement only"),
        ((742, 764), R, "`transcript`: the constructor domain = the D55 profile string under the block shape's key, then D12a's six header absorbs (run-shape = L + six public axes, expected-IO bytes, public-statement digest, the fork parameter line, calibration identity, the fork schedule digest). No witness word"),
        ((766, 787), T, "`binding` and `capture_header`: `#[cfg(test)]`"),
        ((789, 839), R, "`s0`, `fork`, `absorb_commit` (per boundary: `pb-fork-commit-root` k, B root, rows, log-cols; then `pb-fork-s0` L), `absorb_one_root`, `absorb_fork_start` (`pb-run-fork` k -- always in production -- and block k's public digest). Roots are commitments the head publishes"),
        ((841, 875), R, "THE JOIN'S WORDS: `claim_bytes` (count; per claim value, part count; per part slice offset, log size, coefficient, point) and `absorb_join` (k, the fork transcript's 32-byte state ‖ squeeze counter, slot-21 claims, slot-22 claims), `close_join`"),
        ((877, 955), N, "`ForkBlocks` (public blocks by reference) and `RepeatBlock` (`#[cfg(test)]`)"),
        ((957, 974), N, "`preflight`: CS-1 / CS-4 / CS-6 before anything is absorbed"),
        ((976, 1005), N, "`ForkOut` / `ForkCtx`: carriers (the fork's frame bytes, end state, IO claims; shared read-only inputs with NO generator)"),
        ((1007, 1049), R, "`prove_one`: the fork transcript from public words; THE FORK'S OWN GENERATOR `ZkRng::from_os(fork_seed_domain(profile, k))` created inside the worker (:1022); `prove_core` with that generator and the boundary data planes (as D12a); the frame carries the roots, slots, M / A / H openings and tags but NOT the IO claims (:1035)"),
        ((1051, 1065), N, "`prove_run_with_forks` (honest) and the tampered entry (`#[cfg(test)]`)"),
        ((1067, 1252), R, "`prove_forks_inner`: preflight, endpoint checks, header; PHASE 1 the commit generator (:1095) commits every B_k (`boundary::prepare`, unchanged since r19b) and is DROPPED before any fork (:1107); the head = binding, L, roots, S0 tag; PHASE 2 workers on a rendezvous channel, `catch_unwind` makes a test-build panic that fork's error (release: panic = abort, Cargo.toml:63), any error fails the whole run (:1186-1189); PHASE 3 joins each fork's END state and its own claims in block order, then opens each B_k ONCE with (k's slot 22, k+1's slot 21), the input endpoint with fork 0's slot 21, the output endpoint with fork L-1's slot 22, all after S1; the tail frame"),
        ((1254, 1291), R, "`verify_one_fork`: the verifier's own fork transcript; path-depth checks; `verify_core` returns the verifier's OWN [ic, oc] and end state; capture hooks `#[cfg(test)]`"),
        ((1300, 1478), R, "`verify_run_with_forks`: head and S0 compared; forks on workers; THE JOIN from the verifier's own `Seen` (end state, counter, claims) (:1391-1394); each B_k checked (`boundary::check_opening`) and verified with the claims the verifier derived (:1425-1453); endpoints (:1454-1469); end tag. Capture hooks `#[cfg(test)]`"),
        ((1480, 1496), N, "frame file names (none is a D12a segment name)"),
        ((1498, 1555), R, "F3 MARKER: fixed text, written `create_new` to a `.partial` name, flushed, renamed, never over an existing entry; read back only as a regular file of exactly that text; absorbed nowhere, in no frame, not in segments.json or statement.json"),
        ((1557, 1583), R, "`write_fork_receipt`: the L + 2 frames into an EXISTING, EMPTY directory, each atomically (as `run_sink::DirSink`); writes receipt bytes only"),
        ((1585, 1694), R, "`read_frame_bounded` (lstat, counted length, `open_nofollow_nonblock`, fstat, capped read) and `read_fork_receipt` (directory must be exactly the L + 2 frames, the statement DIRECTORY and the marker; F7 header-first), `verify_run_with_forks_from_dir`. Error text: paths, entry names, lengths, k -- verifier-side, no witness word"),
        ((1696, 1698), T, "`#[cfg(test)] mod tests;`"),
    ],
    "src/private_block/run_fork_wire.rs": [
        ((1, 30), N, "module doc"),
        ((32, 43), N, "imports and the three magics (HLPFKHD1 / HLPFORK1 / HLPFKTL1)"),
        ((45, 66), R, "`ForkFrame` (a D12a segment without its boundary root and IO openings: NO IO claims) and `TailFrame` (B_0 .. B_{L-2} with two claim sites each, the two endpoints)"),
        ((68, 79), R, "`endpoint_dim` (= wire.rs `Dim::endpoint`: endpoint log_n, rate, `opened_cols`), `slots_len`, `mask_len` (M at MASK_CHECKS = zk::MASK_Q)"),
        ((81, 99), R, "counted lengths of head / fork / tail: functions of the statement only"),
        ((101, 139), R, "head encode / decode: binding, L, the L-1 roots, the S0 tag; trailing bytes refused"),
        ((141, 164), R, "`validate_fork`: slot shapes; M has MASK_VEC q / prox and exactly MASK_CHECKS columns of m_rows; A and H are hiding openings at the block's Q (`hiding_ok`)"),
        ((166, 196), R, "`encode_fork`: writes exactly the slot proofs (scalar, masked rounds, masked terms), the M opening, the A and H openings and the tags; length must equal the count"),
        ((198, 221), N, "`fork_header` / `check_fork_header` (F7): comparisons and refusals"),
        ((223, 257), R, "`decode_fork`: counted length, header, body, re-validation; nothing read from the frame sizes an allocation"),
        ((259, 288), R, "`encode_tail`: every boundary opening a hiding opening with `sites` groups at the endpoint Q, each endpoint with one group; counted length"),
        ((290, 309), N, "`tail_header` / `check_tail_header` (F7)"),
        ((311, 332), R, "`decode_tail`: S1 tag compared, openings read at counted sizes, trailing bytes refused"),
    ],
}

# per-file reading text and metadata
FILES = {
    "src/private_block/run_capture.rs": dict(
        compiled="TEST-ONLY module (`#[cfg(test)] mod run_capture;`, private_block.rs:266-267); its content IS what a capture contains",
        cls="test-only",
        reading="Capture writer of the D55 fork run (D55 review F5) and of a REGISTERED D55 run's bundle (D60), the W16 statement-table label, M's column count in `mask_domain`, six more source pins. Against `not_in_a_capture` (witness values, pad values, mask coefficients, unopened columns, unpublished salts, unmasked sumcheck rounds, hidden inputs / outputs / boundary planes, prover randomness; run_capture.rs:3288): a fork bundle's run.json is `write_run`'s (header words, layout, D55 label / program text, plane index, the same not_in_a_capture list); each fork's stage file is an ordinary stage record of that fork (roots, the 23 masked slot transcripts, M opening, A and H openings) less the boundary and IO openings; the tail file holds S1 and the B_k / endpoint openings as `write_pcs` writes a D12a IO opening (claims the verifier computed, masked vectors, Q opened columns with their published salts and paths); arrays.bin is the merged per-fork stores; `receipt/` is the receipt itself. Every key is on the UNCHANGED allow-list (ALLOWED_KEYS :4035-4360, no hunk). The recorder sees only the verifier: every capture call in run_fork.rs is in the verifier (:1279-1476); per-fork recorders are seeded from public words (`ForkSeed` :1157) on verifier workers. Block / token / classifier bundles are byte for byte r19b's except `mask_domain.columns`, which is value-identical (256) at every shape but W16R2. No finding"),
    "src/private_block/plane_index.rs": dict(
        compiled="TEST-ONLY module (`#[cfg(test)] mod plane_index;`, private_block.rs:275-276); its table is written into every run.json",
        cls="test-only",
        reading="W16 (D54) additions to the capture's plane index: range-table helper names and the SC_SZC / SC_TAB W16 push orders, switched on only where `AccuracyIds::w16` is set. At every R13 (the D55 registered bases) and legacy layout the table is r19b's byte for byte. Public layout only (ids, names, domains, rows, push order); allow-listed keys unchanged. No finding"),
    "src/private_block/run.rs": dict(
        compiled="production",
        cls="gated-on-new-profiles",
        reading="D60's registry of twelve D55 run profiles (public constructor domains, each = marker + base, checked) and the `mod fork` declaration; a `#[cfg(test)]` W16 run identity; D60 F4: one per-target O_NOFOLLOW | O_NONBLOCK table and `open_nofollow_nonblock` used by the segment and regular-file readers (error text unchanged). Header, stage order, boundary absorbs, position tags, opening order, `capture_header`, `prove_run_with` and the D12a verifier are outside the hunks: no byte of any existing receipt moves. No finding"),
    "src/private_block/run_fork.rs": dict(
        compiled="production (since D60), `#[path = \"run_fork.rs\"] pub(crate) mod fork;` in run.rs:1770-1771; tests and cheats `#[cfg(test)]`",
        cls="new-file",
        reading="NEW (read in full, 1,698 lines): the D55 commit / fork / join prover and verifier, the frames on disk, the F3 marker. (1) What is absorbed: the D12a header's six words under the D55 constructor; every B_k root (public, in the head) before any fork; per fork k and block k's public digest; at the join each fork's transcript END state + squeeze counter and its slot-21 / slot-22 claim lists -- on the verifier side its OWN values (verify_core's [ic, oc] and its own fork transcript, :1284-1290, :1391-1394), so the prover can absorb only words the verifier recomputes from the receipt, and the claims are not written into any fork frame (ForkFrame has none). (2) What is opened: each B_k ONCE (k's slot 22 + k+1's slot 21: two sites, D12a's), each endpoint once, A / H / M once per fork -- the same commitments opened the same number of times as D12a, at the shape's Q. (3) Randomness: L + 1 generators, `ZkRng::from_os` each (commit phase :1095, dropped :1107 before any fork; one per fork inside its worker :1022); each draws 32 fresh bytes of /dev/urandom and keys BLAKE3 with them (zkp-core rng.rs:44-65, at the W16-read digest f6728bd2); ZkRng is not Clone (rng.rs:9-14); no `ZkRng::new` in the file. (4) Errors: prover-side errors go to the prover's stderr (`fail_run` writes no file); a test-build worker panic becomes that fork's error and fails the run, release builds abort (Cargo.toml:63) as D12a does; reader errors carry paths, lengths, entry names, k. (5) F3: the constant is false (:101); the marker is a fixed text written create_new + rename, absorbed nowhere. No finding"),
    "src/private_block/run_fork_wire.rs": dict(
        compiled="production (since D60), `#[path = \"run_fork_wire.rs\"] pub(crate) mod fork;` in wire.rs:499-500",
        cls="new-file",
        reading="NEW (read in full, 332 lines): the head (binding, L, roots, S0 tag), fork (D12a segment less boundary root and IO openings) and tail (every IO opening after S1) frames. Every field is a commitment root, a masked slot proof, a hiding opening at the shape's Q (A / H / B / endpoints) or MASK_Q (M), or a transcript position; every count is the verifier's. No new field kind relative to a D12a segment. No finding"),
    "src/private_block/wire.rs": dict(
        compiled="production",
        cls="identity-at-captured-profiles",
        reading="W16R2 review F5 (d) / D59: M's frame constants from zk.rs (value-identical) and M's opened-column count = zk::MASK_Q (256), no longer the block's Q; plus the `mod fork` declaration. Every pre-W16R2 profile's frames are byte for byte r19b's; M is never framed with more columns than its pads. No finding"),
    "src/private_block/hash_domain.rs": dict(
        compiled="production",
        cls="identity-at-captured-profiles",
        reading="`path_labels` compiled in production for `ForkRun::census` (label names and lengths; a refusal guard). No absorb, no byte. No finding"),
    "src/private_block.rs": dict(
        compiled="production (module root)",
        cls="identity-at-captured-profiles",
        reading="Module declarations only: `mod range16` (W16), `slot_ir` / `metal_slot` under gpu-metal, and three `#[cfg(test)]` modules. Their contents are the block reader's. No item, absorbed word, `ExpectedIo` / `IoSpec` / `calibration_identity` byte or digest moves. No finding"),
    "src/private_block/token_io/load.rs": dict(
        compiled="production",
        cls="identity-at-captured-profiles",
        reading="D60 F4: the token-table reader opens through `run::open_nofollow_nonblock` (macOS / aarch64 now no-follow, non-blocking). Public tables, authenticated after the read as before. No finding"),
    "src/private_block/tied_tables.rs": dict(
        compiled="production",
        cls="identity-at-captured-profiles",
        reading="D60 F4: `regular()` opens through `run::open_nofollow_nonblock`. Public checkpoint and tables, authenticated by derive.rs's pins (unchanged). No finding"),
    "src/private_block/trained_block.rs": dict(
        compiled="production (the CLI bridge)",
        cls="gated-on-new-profiles",
        reading="D60: `stack-prove / stack-verify --d55-workers N` over the registered D55 profile (door before the run directory; same witness source and endpoint owners as D12a; frames written atomically; fresh-process verifier writes the statement); D60 review F3: fail-closed admission, the marker, the `d55-publication` event. A D12a statement renders byte for byte as before. Prover stdout events are prover-private (P-6). No finding"),
    "src/private_block/token_io/classify_run.rs": dict(
        compiled="production (classifier run)",
        cls="identity-at-captured-profiles",
        reading="GPU-classifier lane diagnostics only: HL_PB_TIMING-gated duration prints and write-only phase marks (sizes and durations). No absorb, draw, opening or byte moves; no branch on secret data. No finding"),
    "src/private_block/token_io/classify_batch.rs": dict(
        compiled="production; NOT a capture pin",
        cls="identity-at-captured-profiles",
        reading="D60 F4: the batch request's open flags from the crate's one table; prove-batch's request reader now runs on macOS / aarch64 Linux instead of refusing. No finding"),
    "src/private_block/token_io/classify_cli.rs": dict(
        compiled="production; NOT a capture pin (read for context: it holds `door`)",
        cls="identity-at-captured-profiles",
        reading="GPU-classifier lane diagnostics only (HL_PB_TIMING), including three lines inside `door` (:743-798). Not pinned; round 24's `classify_cli_door_r17_equals_r19b` would now see the door text differ (diagnostic lines only). No finding"),
}

NOTES = [
    {"id": "N-R26-R1", "severity": "Info", "what": "The D60 privacy-gate records' bundles pin the dd81ab4f digests of five of these files (run.rs 604b65b1, run_capture.rs 5d5fdfcc, trained_block.rs 4d1e24bd, run_fork.rs e7b58ff7, run_fork_wire.rs a2dbc6f1); load.rs and tied_tables.rs are at r19b there, classify_batch.rs is unpinned. This file reads both the HEAD digests and (chained, dd81ab4f -> HEAD = commit ed519548's F3 / F4 / F7 / F8 and description-text hunks only) the dd81ab4f digests, so the coordinator can wire either. A bundle written at HEAD carries the HEAD digests."},
    {"id": "N-R26-R2", "severity": "Info", "what": "The capture's join replay (`fork_join`, run_capture.rs:1338) takes the claim lists from the verifier rather than re-deriving them; they are public words the verifier computed, so this is a capture-independence point, not a leak. The Python gate's D55-IO part derives the joined claims from each fork's slot-21 / slot-22 terminals independently (privacy_gate/README.md section 2)."},
    {"id": "N-R26-R3", "severity": "Info", "what": "The F3 marker is operational, not cryptographic: `--d55-test-receipt-not-for-publication` admits any content, and the marker is not bound to the frames (removing it leaves a receipt that verifies). While the constant is false, `stack-verify` prints `not_for_publication: true` for every D55 receipt, marked or not (trained_block.rs:3409-3427). D60's text already says so."},
    {"id": "N-R26-R4", "severity": "Info", "what": "Prover stdout now carries per-fork `prove_core` seconds (`d55-proved`) and, under HL_PB_TIMING, per-phase durations and GPU byte counts (classify_run.rs, classify_cli.rs). Prover-private under P-6, the same class as D12a's per-segment `elapsed_seconds`; nothing enters a receipt, statement or capture. An app that relays prover stdout should keep treating it as private."},
    {"id": "N-R26-R5", "severity": "Info", "what": "D60 F4 lifts the macOS run-time refusal of `prove-batch`'s request reader (classify_batch.rs:48, :119). prove-batch remains outside D58's accepted scope and R18-1 (the app's batch quarantine) is still open (round 24 section 6.5)."},
    {"id": "N-R26-R6", "severity": "Info", "what": "`classify_cli::door` (not a capture pin) differs r19b -> HEAD by three HL_PB_TIMING lines; a tool that compares the door text against r17 / r19b (round 24's `classify_cli_door_r17_equals_r19b`) would report a difference that is diagnostic only."},
    {"id": "N-R26-R7", "severity": "Info (not privacy)", "what": "`write_fork_receipt` creates each `.partial` with `File::create` after an emptiness check (run_fork.rs:1575), the same pattern as `run_sink::DirSink` (run_sink.rs:195); a symlink raced into the prover's own run directory would be followed. Receipt bytes are public, so this is write-path hygiene, not privacy."},
]


def main():
    head = head_commit()
    os.makedirs(RD, exist_ok=True)
    r19b = r19b_digests()
    own, shared, cls = pin_lists()
    d60 = {p["file"]: p["sha256"] for p in json.load(open(D60_MAN))["source_pins"]}
    # ---- every capture pin, moved or not
    pins, moved = [], []
    for lst, files in (("OWN_SOURCE_FILES", own), ("SHARED_SOURCE_FILES", shared), ("CLASSIFY_SOURCE_FILES", cls)):
        for f in files:
            key = os.path.normpath(os.path.join("hashline", f))
            rel = os.path.normpath(os.path.join(HL, f))
            hb = git_show("HEAD", rel)
            wt = open(os.path.join(REPO, rel), "rb").read()
            hd = sha(hb)
            assert sha(wt) == hd, f"working tree differs from HEAD: {f}"
            row = {"file": f, "list": lst, "r19b": r19b.get(key), "head": hd, "d60_bundles": d60.get(f)}
            pins.append(row)
            if r19b.get(key) != hd:
                if f in MINE:
                    who = "run-level reader (this file)"
                elif f in W16_READ and hd.startswith(W16_READ[f]):
                    who = "read at this digest in W16_READINGS (staging_v25 zk60_native_rg_w16.py)"
                else:
                    who = "block-level reader (not read here)"
                moved.append(dict(row, reader=who))
    # ---- diffs r19b -> HEAD, and dd81ab4f -> HEAD / r19b -> dd81ab4f for the D60 bundles' five
    diffs, per = [], {}
    for f in MINE + UNPINNED_READ:
        rel = os.path.normpath(os.path.join(HL, f))
        key = os.path.normpath(os.path.join("hashline", f))
        old_p = os.path.join(R19B_ROOT, key)
        old = open(old_p, "rb").read() if os.path.exists(old_p) else None
        new = git_show("HEAD", rel)
        name = "run-r19b-head-" + f.replace("src/private_block/", "").replace("src/", "").replace("/", "_") + ".diff"
        d = udiff(old, new, f"frozen-r19b/{key}" if old is not None else "/dev/null", f"HEAD {head[:8]}:{rel}")
        open(os.path.join(RD, name), "wb").write(d)
        p, m, h = stat(d)
        diffs.append({"file": key, "from": "r19b", "to": f"HEAD {head[:8]}", "diff": RD_REL + name, "sha256": sha(d), "plus": p, "minus": m, "hunks": h})
        per[f] = {"old": old, "new": new, "diff": d, "name": name}
        dd = git_show(D60_COMMIT, rel)
        if dd is not None and sha(dd) not in (sha(new), r19b.get(key)):
            for frm, to, a, b, la, lb in (("dd81ab4f", f"HEAD {head[:8]}", dd, new, f"{D60_COMMIT}:{rel}", f"HEAD {head[:8]}:{rel}"),
                                          ("r19b", "dd81ab4f", old, dd, f"frozen-r19b/{key}" if old is not None else "/dev/null", f"{D60_COMMIT}:{rel}")):
                dn = f"run-{frm}-{to.split()[0].lower()}-" + f.replace("src/private_block/", "").replace("/", "_") + ".diff"
                dx = udiff(a, b, la, lb)
                open(os.path.join(RD, dn), "wb").write(dx)
                p2, m2, h2 = stat(dx)
                diffs.append({"file": key, "from": frm, "to": to, "diff": RD_REL + dn, "sha256": sha(dx), "plus": p2, "minus": m2, "hunks": h2})
                per[f].setdefault("dd", {})[frm] = {"sha": sha(dd), "diff": RD_REL + dn, "stat": (p2, m2, h2)}
    # ---- readings
    readings, totals = {}, {"hunks_or_sections": 0, "test_only": 0, "production_privacy_neutral": 0, "privacy_relevant": 0, "privacy_relevant_safe": 0, "findings": 0}
    for f in MINE + UNPINNED_READ:
        meta, info = FILES[f], per[f]
        key = os.path.normpath(os.path.join("hashline", f))
        r19 = r19b.get(key)
        hd = sha(info["new"])
        p, m, h = stat(info["diff"])
        entry = {"r19b": r19, "head": hd, "d60_bundles": d60.get(f), "capture_pin": f not in UNPINNED_READ,
                 "pinned_by": [l for l, fs in (("OWN_SOURCE_FILES", own), ("SHARED_SOURCE_FILES", shared), ("CLASSIFY_SOURCE_FILES", cls)) if f in fs],
                 "compiled": meta["compiled"], "diff_file": RD_REL + info["name"], "diff_stat": f"+{p} / -{m}, {h} hunk(s) against {(r19 or 'absent')[:8]} (frozen-r19b)"}
        if f in SECTIONS:
            nlines = info["new"].count(b"\n")
            items = []
            for (a, b), c, note in SECTIONS[f]:
                assert 1 <= a <= b <= nlines, (f, a, b, nlines)
                items.append({"head_lines": [a, b], "class": c, "note": note})
            entry["unit"] = "section (a NEW file: one diff hunk; classified by item, read in full)"
            entry["sections"] = items
            units = items
        else:
            hk = parse_hunks(info["diff"])
            spec = HUNKS[f]
            assert len(hk) == len(spec), (f, len(hk), len(spec))
            units = []
            for i, (x, (c, note)) in enumerate(zip(hk, spec), 1):
                units.append({"n": i, "head_lines": x["head_lines"], "r19b_at": x["r19b_at"], "plus": x["plus"], "minus": x["minus"], "class": c, "note": note})
            entry["unit"] = "hunk (diff -u)"
            entry["hunks"] = units
        cnt = {"units": len(units), "test_only": sum(u["class"] == T for u in units),
               "production_privacy_neutral": sum(u["class"] == N for u in units),
               "privacy_relevant": sum(u["class"] in (R, C) for u in units)}
        cnt["privacy_relevant_safe"] = cnt["privacy_relevant"]
        cnt["findings"] = 0
        assert cnt["test_only"] + cnt["production_privacy_neutral"] + cnt["privacy_relevant"] == cnt["units"]
        entry["counts"] = cnt
        for k in ("test_only", "production_privacy_neutral", "privacy_relevant", "privacy_relevant_safe", "findings"):
            totals[k] += cnt[k]
        totals["hunks_or_sections"] += cnt["units"]
        entry["findings"] = []
        entry["verdict"] = "READ; safe (no finding)"
        rd = {hd: {"base": r19, "diff_stat": entry["diff_stat"], "moves_a_receipt_byte": False, "moves_a_block_stage_byte": False,
                   "new_receipt_kind": f in ("src/private_block/run_fork.rs", "src/private_block/run_fork_wire.rs"),
                   "classification": meta["cls"], "diff_file": entry["diff_file"],
                   "reading": "[GATE ROUND 26, run-level reader, frozen-r19b -> HEAD " + head[:8] + "] " + meta["reading"]}}
        if "dd" in info:
            ddsha = info["dd"]["dd81ab4f"]["sha"]
            p2, m2, h2 = info["dd"]["r19b"]["stat"]
            rd[ddsha] = {"base": r19, "diff_stat": f"+{p2} / -{m2}, {h2} hunk(s) against {(r19 or 'absent')[:8]} (frozen-r19b); dd81ab4f -> HEAD in " + info["dd"]["dd81ab4f"]["diff"],
                         "moves_a_receipt_byte": False, "moves_a_block_stage_byte": False,
                         "new_receipt_kind": f in ("src/private_block/run_fork.rs", "src/private_block/run_fork_wire.rs"),
                         "classification": meta["cls"], "diff_file": info["dd"]["r19b"]["diff"],
                         "reading": "[GATE ROUND 26, run-level reader, the D60 bundles' digest (dd81ab4f)] The HEAD reading less commit ed519548's hunks, which are exactly: F3 (the real-content constant, the CLI admission and marker, the d55-publication event), F4 (the per-target open-flag table; at dd81ab4f the readers set O_NOFOLLOW | O_NONBLOCK on x86-64 Linux only, a DoS window on macOS, not a privacy term), F7 (header-first frame reader), F8 (catch_unwind in test builds) and the registered description text in run.json (text only). None of them changes what a receipt, statement or capture contains; the dd81ab4f binary lacks F3's refusal (an operating precondition, not a property of a capture). No finding"}
        entry["readings"] = rd
        readings[f] = entry
    # ---- the w16-style table the gate can wire (one digest per entry)
    wiring = {}
    for f in MINE:
        e = readings[f]
        wiring[f] = [[e["head"][:12], "HEAD " + head[:8] + ": " + FILES[f]["reading"][:400]]]
        if e["d60_bundles"] and e["d60_bundles"] != e["head"] and e["d60_bundles"] != e["r19b"]:
            wiring[f].append([e["d60_bundles"][:12], "dd81ab4f (the D60 bundles): the HEAD reading less ed519548's F3 / F4 / F7 / F8 / text hunks; no capture byte differs"])
    out = {
        "what": "gate round 26, RUN-LEVEL reader: every moved run / wire / capture / I-O source pin, frozen-r19b -> HEAD (read hunk by hunk from the trees)",
        "privacy_acceptance": False,
        "reader": "run-level reader (Claude); the block-level pins are another reader's and are NOT read here",
        "date_utc": "2026-11-02",
        "method": "diff -u of frozen-r19b against `git show HEAD:<path>` (the working tree equals HEAD for every pin, checked); every hunk classified test-only / production privacy-neutral / privacy-relevant, and every privacy-relevant hunk decided safe with its argument and HEAD line numbers, or a finding. NEW files read in full and classified by section. Python only; no cargo run.",
        "trees": {"r19b": check_r19b(),
                  "head": {"commit": head, "source": "ops/zkp-mvp/gpu-metal/hashline (+ ../zkp-core)", "worktree_equals_head_for_every_pin": True},
                  "d60_bundles": {"source_commit": D60_COMMIT, "manifest": os.path.relpath(D60_MAN, REPO), "pins": len(d60)}},
        "capture_pins": {"counts": {"OWN_SOURCE_FILES": len(own), "SHARED_SOURCE_FILES": len(shared), "CLASSIFY_SOURCE_FILES": len(cls)},
                         "total": len(pins), "a_d55_bundle_pins": len(own) + len(shared),
                         "moved_r19b_to_head": moved,
                         "moved_counts": {"total": len(moved),
                                          "run_level_this_file": sum(m["reader"].startswith("run-level") for m in moved),
                                          "already_read_W16_READINGS": sum(m["reader"].startswith("read at") for m in moved),
                                          "block_level_other_reader": sum(m["reader"].startswith("block-level") for m in moved)}},
        "diffs": diffs,
        "readings": readings,
        "special_attention": {
            "run_capture_vs_not_in_a_capture": "Nothing on the list is written. Fork stage files = ordinary stage records of each fork (masked slot transcripts, M / A / H openings with published salts); the tail = S1 and the B_k / endpoint openings as write_pcs writes a D12a IO opening; run.json = write_run's header words, layout, D55 text and the SAME not_in_a_capture list (run_capture.rs:3288); arrays.bin = merged per-fork stores (absorb_store copies only stored arrays, :792-836); receipt/ = the receipt's own frames. ALLOWED_KEYS (:4035-4360) has no hunk r19b -> HEAD, and every key the fork writers emit (tail: schema, kind, blocks, end_tag, opening_order, header, state, next, roles, transcript_sites, stage, site, before, after) is on it. The recorder is attached only on the verifier (run_fork.rs capture calls :1279-1476), seeded from public words (ForkSeed :1157).",
            "fork_randomness": "L + 1 generators per run, each ZkRng::from_os under its own domain: the commit phase's (run_fork.rs:1095, used only by boundary::prepare for the L-1 boundaries :1104, dropped :1107 before any fork) and one per fork inside its worker (:1022, handed to prove_core by &mut). from_os reads 32 fresh bytes of /dev/urandom per call and keys BLAKE3 with them (zkp-core rng.rs:44-65; digest f6728bd2, read in W16_READINGS); the domains (SEED_USE ‖ ROLE_RUN_PROVER ‖ k ‖ profile, :371-384) only add separation. ZkRng is not Clone (rng.rs:9-14); the file has no ZkRng::new; a production Cheat is the honest constants. Independence therefore rests on independent OS draws, as D12a's one run generator rests on one.",
            "d55_join": "absorb_join (run_fork.rs:864-871) absorbs k, the fork transcript's 32-byte state ‖ squeeze counter, and the slot-21 / slot-22 claim lists (claim_bytes :843-860: count, value, part count, slice offset, log size, coefficient, point). The verifier absorbs its OWN values (verify_one_fork :1284-1290 returns verify_core's [ic, oc] and its own end state; join :1391-1394), so the transcript only matches if the prover's words equal what the verifier recomputes from the receipt; the claims are the D12a IO claims (masked by their reserved pairs, PG-8), are not written into any fork frame (ForkFrame :47-55), and are opened only in the tail. Verifier-computable words only.",
            "f3_marker": "D55_REAL_CONTENT_PRIVACY_GATE_PASSED = false (run_fork.rs:101). stack-prove --d55-workers is refused before anything is read unless --d55-test-receipt-not-for-publication is given (trained_block.rs d55_prove_admission :2690-2703, call :3053); the marker is a fixed text, create_new + flush + rename, never replaced (:1541-1555), admitted by the reader only as exactly that text (:1524-1536, :1646-1650), absorbed nowhere, in no frame, not in segments.json or statement.json; stack-verify reports it and prints not_for_publication = marked || !gate (:3409-3427). Operational, not cryptographic (N-R26-R3).",
            "reader_error_messages": "Every new or changed reader error carries a path, a directory entry name, a byte length, an index k or L, or an OS error string: read_segment_bounded / read_regular_file_bounded (run.rs:1715, :1752, text unchanged), read_frame_bounded / read_fork_receipt / the marker (run_fork.rs:1590-1683, :1524-1536), decode_* (run_fork_wire.rs), token tables (load.rs:130), tied tables (tied_tables.rs:30), the batch request (classify_batch.rs:119-124, OS error only, content never echoed). The verifier holds no witness. Prover-side errors go to the prover's stderr; fail_run removes the run directory and writes no error file (trained_block.rs:2522-2531); a test-build worker panic message becomes that fork's error and fails the whole run, release builds abort (Cargo.toml:63) exactly as D12a.",
            "timing": "No new branch on secret data: run_fork.rs schedules on public L / N / k; classify_run.rs / classify_cli.rs add HL_PB_TIMING-gated, write-only timers (timing.rs:239-252 return on their first line unless enabled) that print durations and public sizes to the prover's or verifier's own stdout."},
        "notes": NOTES,
        "not_read_here": {"block_level_pins_moved": [m["file"] for m in moved if m["reader"].startswith("block-level")],
                          "why": "the other reader's files (task split)"},
        "wiring_w16_readings_style": wiring,
        "summary": {"files_read": len(MINE) + len(UNPINNED_READ), "capture_pins_read": len(MINE), "unpinned_read_for_context": UNPINNED_READ,
                    "totals": totals, "findings": 0, "verdict": "every run-level, wire, capture and I-O pin that moved r19b -> HEAD is READ and SAFE; 0 findings; 7 Info notes",
                    "head_digests": {f: readings[f]["head"] for f in MINE + UNPINNED_READ},
                    "d60_bundle_digests_also_read": {f: readings[f]["d60_bundles"] for f in MINE if readings[f]["d60_bundles"] and readings[f]["d60_bundles"] not in (readings[f]["head"], readings[f]["r19b"])}},
    }
    p = os.path.join(OUT, "READINGS_R26_RUN.json")
    with open(p, "w") as fh:
        json.dump(out, fh, indent=1)
        fh.write("\n")
    print("wrote", p, sha(open(p, "rb").read()))
    print(json.dumps(out["summary"], indent=1))
    print(json.dumps(out["capture_pins"]["moved_counts"]))
    print(json.dumps(out["trees"]["r19b"])[:600])


if __name__ == "__main__":
    main()
