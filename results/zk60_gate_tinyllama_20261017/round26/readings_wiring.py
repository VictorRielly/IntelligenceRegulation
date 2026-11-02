"""Gate round 26, the WIRING's own reading: build READINGS_R26_WIRING.json and its diff.

SELF-READ (the agent that wrote the change read it): the run_capture.rs diff of this round's F-B1 fix
(HEAD 6d06b8b0 = the readers' 8b78aabd for every source file -> 23199feb), and the two Metal backend
files at the CPU-PATH scope.  Owed: an independent check at the v25 freeze review.
Read-only on source.  Writes only under results/zk60_gate_tinyllama_20261017/round26/.
Usage: python3 readings_wiring.py  (no arguments; paths inside)
"""
import hashlib, json, os, re, subprocess, tempfile

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
HL = "ops/zkp-mvp/gpu-metal/hashline"
OUT = os.path.join(REPO, "results/zk60_gate_tinyllama_20261017/round26")
RD_REL = "results/zk60_gate_tinyllama_20261017/round26/readings_wiring/"
BASE, NEW = "6d06b8b0", "23199feb"
RC = f"{HL}/src/private_block/run_capture.rs"
METAL, KERNELS = f"{HL}/src/gpu/metal.rs", f"{HL}/src/gpu/metal_kernels.metal"


def sha(b):
    return hashlib.sha256(b).hexdigest()


def git_show(rev, rel):
    return subprocess.run(["git", "-C", REPO, "show", f"{rev}:{rel}"], capture_output=True, check=True).stdout


def udiff(old, new, la, lb):
    with tempfile.TemporaryDirectory() as td:
        a, b = os.path.join(td, "a"), os.path.join(td, "b")
        open(a, "wb").write(old)
        open(b, "wb").write(new)
        return subprocess.run(["diff", "-u", "--label", la, "--label", lb, a, b], capture_output=True).stdout


def hunks_of(d):
    out = []
    for line in d.decode().splitlines():
        m = re.match(r"@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@", line)
        if m:
            nn = int(m.group(4) if m.group(4) is not None else 1)
            out.append({"base_at": int(m.group(1)), "new_lines": [int(m.group(3)), int(m.group(3)) + nn - 1], "plus": 0, "minus": 0})
        elif out and line.startswith("+"):
            out[-1]["plus"] += 1
        elif out and line.startswith("-"):
            out[-1]["minus"] += 1
    return out


# per hunk, in diff order: (class, what, argument)
READ = [
    ("production privacy-neutral (test-only module; a type)",
     "SHARED_SOURCE_FILES: [&str; 29] -> [&str; 31]",
     "The array length only; the compiler checks it against the entries."),
    ("privacy-relevant (what a manifest lists)",
     "two pins appended to SHARED_SOURCE_FILES after ../zkp-core/src/tables.rs: src/gpu/metal.rs and "
     "src/gpu/metal_kernels.metal, with the F-B1 comment",
     "A pin is (file name, SHA-256 of the PUBLIC source file at capture time), read by source_pins() (:4618) from "
     "CARGO_MANIFEST_DIR; nothing is absorbed into any transcript, frame or statement, and the manifest is not hashed "
     "into a receipt. Appended: source_files() (:4613) is OWN then SHARED, so every earlier pin keeps its index; the "
     "classifier's five (classify_source_pins) now follow two later, and every reader indexes pins by file name "
     "(zk60_native_rg_classpins.check_classify_pins, zk60_native_rg_w16.classify_pins, zk60_native_rg_terminals). "
     "s24's partition test covers OWN_SOURCE_FILES only (private_block's modules), so the gpu files need no excusal; "
     "s24 (d3) now asserts both are pinned. Closes F-B1's pin-coverage half."),
    ("text only",
     "the M26 comment above slot_ir.rs / slot_ir_accuracy.rs / metal_slot.rs corrected",
     "It said a Metal-built bundle is 'tied to them as well' (overstating: those three are the IR and its codegen, not "
     "the backend that runs the kernels and computes the commitments); it now says so and points at the two new "
     "SHARED pins. Comment only."),
    ("privacy-relevant (the allow-list)",
     "ALLOWED_KEYS gains \"proved_on_gpu\" in its manifest section",
     "The allow-list grows by ONE key whose value is a boolean (hunks 5, 6). The value is a function of the prover's "
     "environment (HL_GPU and whether the Metal device initialised), not of any witness value, hidden input, output, "
     "activation, weight, pad, mask coefficient, salt or prover draw (P1's hidden set). No run.json / stage / tail "
     "writer emits the key (those writers are unchanged), so PG-7's scans of those files are unaffected; the "
     "forbidden-word scan is unchanged. every_key_of_a_bundle_is_on_the_allow_list (run_capture_tests.rs:361) scans the "
     "generic writer's manifest and passes with the key listed."),
    ("privacy-relevant (a new manifest field)",
     "the registered-D55 fork-run manifest (write_fork_bundle :4467-4469) writes \"proved_on_gpu\":<bool> after "
     "\"writer\" and before \"source_pins\", the value crate::gpu::enabled()",
     "gpu::enabled() is the switch every device path of the prover is gated on (gpu/mod.rs:774, :786, :798 the Metal "
     "commit seam; argument.rs:2636 / :2662-2688 the slot IR and so every metal_rounds / MetalTables call; "
     "trained_block.rs:2600). It is read in the proving process at write time: both writers run in-process after the "
     "verifier closed with the recorder attached, and no test changes HL_GPU between the proof and the write (the "
     "tests that toggle HL_GPU in-process -- w16_privacy_gate_tests::metal_gate_at, slot_ir_accuracy.rs, "
     "w16r2_tests.rs -- check their captures in memory and call neither writer). "
     "No-feature build: always false. gpu-metal: HL_GPU == \"1\" and ctx() Ok (metal.rs:96-109); with HL_GPU unset "
     "it returns before touching the device; with HL_GPU=1 the context is the one the prover already made. It "
     "discloses only how the prover ran, which the bundle README's note already states (gpu::label(), "
     "run_fork_tests.rs:1177) and the prover's logs print; no branch, absorb or byte of run.json / stage files / tail / "
     "frames moves. Rust's bool Display is JSON true / false. The Rust REG check (contains the writer string) is "
     "unaffected."),
    ("privacy-relevant (a new manifest field)",
     "the generic write_bundle manifest (:4587) writes \"proved_on_gpu\":<bool> after \"source_commit\"",
     "The same field and value as hunk 5, for every other bundle kind (block runs, token-I/O, classifier); the same "
     "argument. The rest of the manifest (pins, files, total) is unchanged."),
]

METAL_CPU = (
    "CPU-PATH SCOPE ONLY (a CPU-made bundle: proved_on_gpu = false). The block reader's F-B1 says it: 'for them "
    "metal.rs only answers enabled() == false'; re-checked here at this digest. metal.rs is compiled only under "
    "feature gpu-metal without gpu-cuda (gpu/mod.rs:25-26). Its reachable surface from the prover: enabled() (:96-109) and label() "
    "(:112-124) return before ctx() (:70-88) unless HL_GPU == \"1\"; every device entry is gated at its caller by "
    "gpu::enabled(): the commitment seam's try_commit / try_commit_zk_keyed / try_commit_zk return None first "
    "(gpu/mod.rs:774, :786, :798), so no commitment carries a MetalCommit store and MetalCommit::fold_rows / columns "
    "(the EncodedStore of a device commitment) are never called; the slot IR and every metal_rounds / "
    "metal_rounds_owned / MetalTables::new call need def.metal = Some, set only under metal_on = Prove && "
    "gpu::enabled() (argument.rs:2636, :2662-2688, :897-903, :980, :1002); trained_block.rs:2600 is a label. With "
    "enabled() false this file computes no byte of a receipt or a bundle. The device paths (metal_commit_zk, "
    "MetalCommit::columns / fold_rows, MetalRounds::masked_prove) are F-B1's privacy-relevant reading (no leak) and "
    "are NOT read in full: a GPU-made bundle is refused.")
KERNELS_CPU = (
    "CPU-PATH SCOPE ONLY. The kernel source is include_str! into metal.rs's SRC (:31) and compiled to a device "
    "library only inside ctx() (newLibraryWithSource, :75), which enabled() / label() reach only under HL_GPU=1; on a "
    "CPU-made bundle it is a string constant in the binary, never compiled or executed. NOT read as kernel code (F-B1: "
    "a GPU-made bundle is refused until it is).")


def main():
    old, new = git_show(BASE, RC), git_show(NEW, RC)
    work = open(os.path.join(REPO, RC), "rb").read()
    assert work == new, "the working tree's run_capture.rs is not 23199feb's"
    assert sha(old) == "cbb78dc04ac5ca62e56318ae6b2e844666ef3016e03a774e81d7e3d6dc569135", "the base is not the run-level reader's HEAD"
    d = udiff(old, new, f"a/{RC} ({BASE}, cbb78dc0)", f"b/{RC} ({NEW})")
    os.makedirs(os.path.join(OUT, "readings_wiring"), exist_ok=True)
    dpath = os.path.join(OUT, "readings_wiring", "wiring-head-r26w-run_capture.rs.diff")
    open(dpath, "wb").write(d)
    hs = hunks_of(d)
    assert len(hs) == len(READ), (len(hs), len(READ))
    hunks = [dict(h, n=i + 1, **{"class": c, "what": w, "argument": a}) for i, (h, (c, w, a)) in enumerate(zip(hs, READ))]
    plus, minus = sum(h["plus"] for h in hs), sum(h["minus"] for h in hs)
    m, k = git_show(NEW, METAL), git_show(NEW, KERNELS)
    assert git_show("8b78aabd", METAL) == m and git_show("8b78aabd", KERNELS) == k, "the Metal files moved since the block reader's 8b78aabd"
    assert (len(m), len(k)) == (92982, 39117), "not the sizes F-B1 names"
    new_sha = sha(new)
    counts = {"hunks": len(hs), "test_only": 0, "production_privacy_neutral": 1, "text_only": 1, "privacy_relevant": 4,
              "privacy_relevant_safe": 4}
    rc_reading = ("[GATE ROUND 26, the wiring's own reading, SELF-READ, cbb78dc0 -> " + new_sha[:8] + "] F-B1's capture half: "
                  "src/gpu/metal.rs and src/gpu/metal_kernels.metal appended to SHARED_SOURCE_FILES; \"proved_on_gpu\" "
                  "(= gpu::enabled() in the proving process) in both manifest writers and on ALLOWED_KEYS; the M26 pin "
                  "comment corrected. Nothing on not_in_a_capture is written; no transcript, frame, stage, tail or run.json "
                  "byte moves; the value is prover-environment metadata, not a function of any hidden value. Chained on "
                  "the run-level reader's r19b -> cbb78dc0 reading (READINGS_R26_RUN.json). No finding.")
    doc = {
        "what": "gate round 26, the WIRING's own reading: the run_capture.rs diff of the F-B1 fix and the CPU-path scope of "
                "the two Metal backend files (the digests a fresh bundle at 23199feb pins)",
        "privacy_acceptance": False,
        "reader": "the round-26 wiring agent (Claude), who WROTE the run_capture.rs change: SELF-READ. Owed an independent "
                  "check at the v25 freeze review; the gate names these readings in every record that uses them "
                  "(PINS.self_read_pending_independent_check)",
        "self_read": True,
        "date_utc": "2026-11-02",
        "method": "diff -u of run_capture.rs at 6d06b8b0 (equal to 8b78aabd for every source file: `git diff --stat 8b78aabd "
                  "6d06b8b0 -- hashline/src zkp-core/src` is empty; its digest cbb78dc0 is the run-level reader's HEAD) "
                  "against 23199feb; every hunk classified and every privacy-relevant one argued with line numbers of the "
                  "new file. The Metal files: their 8b78aabd blobs (equal at 23199feb) re-read for the CPU path only "
                  "(their reachable surface when gpu::enabled() is false), sizes checked against F-B1's.",
        "trees": {"base": {"commit": BASE, "equals": "8b78aabd for hashline/src and zkp-core/src", "run_capture_rs": sha(old)},
                  "new": {"commit": NEW, "run_capture_rs": new_sha}},
        "capture_pins": {"source": "run_capture.rs OWN_SOURCE_FILES (44) + SHARED_SOURCE_FILES (31) = 75 at 23199feb",
                         "added": ["src/gpu/metal.rs", "src/gpu/metal_kernels.metal"],
                         "moved_by_this_change": ["src/private_block/run_capture.rs"]},
        "diffs": [{"file": f"hashline/{RC.split('hashline/')[1]}", "from": f"{BASE} (cbb78dc0)", "to": NEW, "diff": RD_REL + os.path.basename(dpath),
                   "sha256": sha(d), "plus": plus, "minus": minus, "hunks": len(hs)}],
        "readings": {
            "src/private_block/run_capture.rs": {
                "r19b": "cce0fc2a4062fcb4c92e771b8d7ac7f996c9ccfbc985bfb6decd79b29fba7ddf", "base": sha(old), "new": new_sha,
                "capture_pin": True, "pinned_by": ["OWN_SOURCE_FILES"],
                "compiled": "TEST-ONLY module (`#[cfg(test)] mod run_capture;`); its content IS what a capture contains",
                "diff_file": RD_REL + os.path.basename(dpath), "diff_sha256": sha(d),
                "diff_stat": f"+{plus} / -{minus}, {len(hs)} hunk(s) against cbb78dc0 (the run-level reader's HEAD)",
                "unit": "hunk (diff -u)", "hunks": hunks, "counts": counts, "findings": [],
                "verdict": "SELF-READ; safe (no finding); owed an independent check at the v25 freeze review",
                "readings": {new_sha: {"base": sha(old), "diff_stat": f"+{plus} / -{minus}, {len(hs)} hunk(s) against cbb78dc0",
                                       "moves_a_receipt_byte": False, "moves_a_block_stage_byte": False, "new_receipt_kind": False,
                                       "classification": "test-only", "diff_file": RD_REL + os.path.basename(dpath),
                                       "chained_on": "READINGS_R26_RUN.json readings['src/private_block/run_capture.rs'] (r19b -> cbb78dc0)",
                                       "reading": rc_reading}}},
            "src/gpu/metal.rs": {
                "r19b": None, "head": sha(m), "bytes": len(m), "capture_pin": True, "pinned_by": ["SHARED_SOURCE_FILES (since 23199feb)"],
                "compiled": "gpu-metal production only", "scope": "cpu-path",
                "readings": {sha(m): {"scope": "cpu-path", "basis": "READINGS_R26_BLOCK.json findings F-B1 (the block reader; "
                                      "HEAD 8b78aabd, by size), re-checked here", "reading": METAL_CPU}},
                "verdict": "CPU-PATH SCOPE: SELF-READ, no byte computed when gpu::enabled() is false; the device paths are NOT read in full"},
            "src/gpu/metal_kernels.metal": {
                "r19b": None, "head": sha(k), "bytes": len(k), "capture_pin": True, "pinned_by": ["SHARED_SOURCE_FILES (since 23199feb)"],
                "compiled": "a string constant (include_str!) of the gpu-metal build", "scope": "cpu-path",
                "readings": {sha(k): {"scope": "cpu-path", "basis": "READINGS_R26_BLOCK.json findings F-B1, re-checked here",
                                      "reading": KERNELS_CPU}},
                "verdict": "CPU-PATH SCOPE: SELF-READ, never compiled or run when gpu::enabled() is false; NOT read as kernel code"},
        },
        "special_attention": {
            "proved_on_gpu_semantics": "gpu::enabled() at write time in the proving process. Conservative: HL_GPU=1 with every "
                                       "device call declined still says true (and is refused); HL_GPU=1 with no device says "
                                       "false, and then every device path is off. A future out-of-process writer, or a test that "
                                       "toggles HL_GPU between a proof and a write, would have to carry the value from the "
                                       "proof (none exists at 23199feb).",
            "gate_rule": "staging_v25 zk60_native_rg_r26readings.gpu_backend: absent -> refused (UNKNOWN), true -> refused while "
                         "either Metal file lacks a FULL reading, false -> admissible with the CPU-path readings above",
        },
        "notes": [{"id": "N-R26-W1", "severity": "Info",
                   "what": "The test-only W16 fork writer (w16_privacy_gate_tests::write_fork_bundle) does not record "
                           "proved_on_gpu; its bundles are refused as UNKNOWN by the gate (they are test-only identities "
                           "with unread test pins and never reach PASS)."},
                  {"id": "N-R26-W2", "severity": "Info",
                   "what": "F-B2 (slot_ir.rs's stale module doc) and F-B3 (the 'byte table' wording) are production text; "
                           "not changed here (no production Rust change in this round)."}],
        "not_read_here": {"src/gpu/metal.rs (device paths)": "F-B1's privacy-relevant paths only (block reader); a full reading "
                                                              "is owed before any GPU-made bundle can be admitted",
                          "src/gpu/metal_kernels.metal": "not read as kernel code"},
        "wiring_w16_readings_style": {
            "src/private_block/run_capture.rs": [[new_sha[:12], "23199feb (SELF-READ): cbb78dc0 + the F-B1 capture fix (two pins, "
                                                 "proved_on_gpu in both manifests and on ALLOWED_KEYS, a comment); no finding"]],
            "src/gpu/metal.rs": [[sha(m)[:12], "CPU-PATH ONLY (SELF-READ on F-B1): enabled() / label() return before ctx() unless "
                                  "HL_GPU=1; every device entry gated by gpu::enabled() at its caller"]],
            "src/gpu/metal_kernels.metal": [[sha(k)[:12], "CPU-PATH ONLY (SELF-READ on F-B1): compiled only inside ctx(); never "
                                             "run when gpu::enabled() is false"]],
            "note": "wired in staging_v25/scripts/zk60_native_rg_r26readings.py R26_READINGS (full digests; the two Metal "
                    "entries at scope cpu-path, admissible only on a bundle whose manifest says proved_on_gpu: false)"},
        "summary": {"files_read": 3, "capture_pins_read": 3, "self_read": True,
                    "totals": {"hunks": len(hs), "privacy_relevant": 4, "privacy_relevant_safe": 4, "findings": 0},
                    "new_digests": {"src/private_block/run_capture.rs": new_sha, "src/gpu/metal.rs": sha(m),
                                    "src/gpu/metal_kernels.metal": sha(k)},
                    "verdict": "SELF-READ, no finding; the run_capture.rs diff is safe and the Metal files compute nothing on "
                               "a CPU-made bundle; owed an independent check at the v25 freeze review"},
    }
    path = os.path.join(OUT, "READINGS_R26_WIRING.json")
    with open(path, "w") as fh:
        json.dump(doc, fh, indent=1)
        fh.write("\n")
    print(path, sha(open(path, "rb").read())[:16], "| diff", sha(d)[:16], f"+{plus}/-{minus} {len(hs)} hunks | run_capture.rs", new_sha[:12],
          "| metal.rs", sha(m)[:12], "| metal_kernels.metal", sha(k)[:12])


if __name__ == "__main__":
    main()
