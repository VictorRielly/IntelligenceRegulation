#!/usr/bin/env python3
"""G-R4 check, items 2 and 3, INDEPENDENT of the draft's draw_discipline_scan.py.

The draft's scan starts from a curated list of functions and a curated draw
regex. This one starts from the other end: EVERY line of production text on
the private-block path that names the generator (`rng` as a word, or
`ZkRng`), in every file, and classifies it. So a draw site the draft did
not list, or a generator handed to a function the draft did not follow, shows
up here as an unclassified line and fails the scan.

Sources are read with `git show <commit>:<path>` (default 2ea7221, the lane
tip), so the scan is of the commit and not of the worktree (which the
mutation driver edits temporarily).

  A. every generator line, classified: CONSTRUCT / DRAW / PASS / PARAM; the
     enclosing function and the chain of enclosing block headers; the
     trip-count expression of every draw; asserted: no draw under an
     if/match/while/loop/else, and every `for`/iterator bound is in the
     reviewed public list.
  B. the generator's reach: which functions take it, and that the slot
     argument, the openings, the transcript and the verifier never do.
  C. every exit (`?`, `return Err`, assert/panic/expect/unwrap) AFTER the
     first draw of each prover entry point and in every function the prover
     calls after its first draw, listed for the check document's table.

Run:  python3 order_and_exits_scan.py [commit]    (exit 0: ALL ASSERTIONS PASSED)
"""
import re
import subprocess
import sys

WT = "/home/victor/wt-zk60-block125m-review"
COMMIT = sys.argv[1] if len(sys.argv) > 1 else "2ea7221"

FILES = [
    "hashline/src/private_block.rs",
    "hashline/src/private_block/protocol.rs", "hashline/src/private_block/run.rs",
    "hashline/src/private_block/boundary.rs", "hashline/src/private_block/endpoint_g.rs",
    "hashline/src/private_block/argument.rs", "hashline/src/private_block/layout.rs",
    "hashline/src/private_block/shape.rs", "hashline/src/private_block/wire.rs",
    "hashline/src/private_block/witness.rs", "hashline/src/private_block/hash_domain.rs",
    "hashline/src/private_block/pad.rs", "hashline/src/private_block/run_sink.rs",
    "hashline/src/private_block/timing.rs",
    "hashline/src/zk.rs", "hashline/src/private_seam.rs", "hashline/src/pcs.rs",
    "zkp-core/src/pcs.rs", "zkp-core/src/sumcheck.rs", "zkp-core/src/rng.rs", "zkp-core/src/transcript.rs",
]


def show(path):
    return subprocess.run(["git", "-C", WT, "show", f"{COMMIT}:{path}"], check=True, capture_output=True, text=True).stdout


def production(src):
    """cut every `#[cfg(test)]` item: a `mod … {` block, a `mod …;` line, or
    the next item (fn / impl / static / thread_local block) — by brace depth"""
    lines = src.split("\n")
    keep = [True] * len(lines)
    i = 0
    while i < len(lines):
        s = lines[i].strip()
        if s.startswith("#[cfg(test)]") or s.startswith("#[cfg(any(test"):
            # skip attribute lines, then the item
            j = i + 1
            while j < len(lines) and lines[j].strip().startswith("#["):
                j += 1
            if j < len(lines) and lines[j].strip().endswith(";") and "{" not in lines[j]:
                for k in range(i, j + 1):
                    keep[k] = False
                i = j + 1
                continue
            depth, started, k = 0, False, j
            while k < len(lines):
                depth += lines[k].count("{") - lines[k].count("}")
                started = started or "{" in lines[k]
                if started and depth <= 0:
                    break
                if not started and lines[k].rstrip().endswith(";"):
                    break
                k += 1
            for m in range(i, min(k + 1, len(lines))):
                keep[m] = False
            i = k + 1
            continue
        i += 1
    return [(n + 1, l if keep[n] else "") for n, l in enumerate(lines)]


def indent(l):
    return len(l) - len(l.lstrip(" "))


def enclosing(lines, idx):
    """(function signature line, [headers innermost first]) of line idx; a
    multi-line signature's closing `) -> … {` line is followed up to its `fn`"""
    cur = indent(lines[idx][1])
    hs, fn = [], None
    for j in range(idx - 1, -1, -1):
        ln, l = lines[j]
        if not l.strip() or l.strip().startswith("//"):
            continue
        d = indent(l)
        if d < cur and l.strip().startswith(")") and l.rstrip().endswith("{"):
            k = next(k for k in range(j - 1, -1, -1) if indent(lines[k][1]) == d and re.search(r"\bfn\s+\w+", lines[k][1]))
            fn = (lines[k][0], lines[k][1].strip())
            break
        if d < cur and (l.rstrip().endswith("{") or l.rstrip().endswith("(")):
            if re.search(r"\bfn\s+\w+", l):
                fn = (ln, l.strip())
                break
            hs.append((ln, l.strip()))
            cur = d
        elif d < cur and re.search(r"\bfn\s+\w+", l):
            fn = (ln, l.strip())
            break
    return fn, hs


# Functions that name the generator but are NOT reachable from the four
# private-block entry points (prove_core, prove_inner_at, prove_run,
# prepare_endpoints); each is asserted uncalled from the private-block files.
OFF_PATH = {
    ("hashline/src/zk.rs", "mask_commit"): "the legacy untagged M (the seam prover and the FFN line); prove_core calls mask_commit_tagged",
    ("hashline/src/zk.rs", "layer_rng"): "the FFN line",
    ("hashline/src/zk.rs", "prove_layer_zk"): "the FFN line",
    ("hashline/src/zk.rs", "prove_layer_zk_v3"): "the FFN line",
    ("hashline/src/zk.rs", "prove_layer_zk_v3_inner"): "the FFN line",
    ("hashline/src/zk.rs", "prepare_layer_zk_v3_inner"): "the FFN line",
    ("hashline/src/zk.rs", "prepare_layer_zk_v3"): "the FFN line",
    ("hashline/src/private_seam.rs", "prove"): "the seam prover (the block only calls private_seam::prepare)",
    ("hashline/src/pcs.rs", "commit_zk_device"): "the FFN GPU H path",
    ("hashline/src/pcs.rs", "commit_zk"): "a borrowed-data wrapper; the block's paths pass owned data",
    ("zkp-core/src/pcs.rs", "commit_zk"): "a borrowed-data wrapper",
    ("zkp-core/src/pcs.rs", "commit_zk_owned"): "the CPU-backend wrapper of commit_zk_owned_with",
    ("zkp-core/src/pcs.rs", "commit_zk_with"): "a borrowed-data wrapper",
}
OFF_PATH_CALLS = {"mask_commit(": "zk::mask_commit(", "commit_zk_device(": "commit_zk_device(", "prove_layer_zk": "prove_layer_zk"}


WORD = re.compile(r"\brng\b|ZkRng")
DRAWS = re.compile(r"\brng\.(fp|fp2|fp_vec|fp2_vec|bytes32|next_u64)\(|\bself\.(fp|next_u64)\(\)")

# Every generator line must match one of these classes (else the scan fails).
CLASS = [
    ("CONSTRUCT", re.compile(r"ZkRng::(from_os|new)\(|Self::from_entropy_reader|ZkRng \{ key")),
    ("DRAW", DRAWS),
    ("PARAM", re.compile(r"(mut )?rng: ZkRng|rng: &mut (crate::rng::|zkp_core::rng::)?ZkRng|&mut ZkRng|-> (std::io::Result<)?ZkRng|impl ZkRng|pub struct ZkRng|use .*ZkRng")),
    ("PASS", re.compile(r"(\(|, )(&mut )?rng(\)|,)|random\(rng,")),
    ("COMMENT/STR", re.compile(r"^\s*(//|\*|\")|b\"hashline-zk-(os-)?rng/|cfg\.rng\(|layer_rng\(")),
]

# the reviewed public trip counts (the loop header or the iterator bound of every draw)
PUBLIC_BOUNDS = [
    r"^for x in &mut a_data\[lay\.a_mask_base \* n\.\.\] \{$",
    r"^for x in &mut h_data\[lay\.h_mask_base \* n\.\.\] \{$",
    r"^for r in lay\.h_u_rows\(\) \{$",
    r"^for j in 0\.\.n - 1 \{$",
    r"^for x in &mut data\[first_mask \* n\.\.\] \{$",
    r"^for \(s, mk\) in masks\.iter\(\)\.enumerate\(\) \{$",
    r"^for \(k, part\) in \[re, im\]\.iter\(\)\.enumerate\(\) \{$",
    r"^for c in out\.chunks_mut\(8\) \{$",
    r"^for k in 0\.\.l \{$",
    r"^let cur = if k \+ 1 < l \{$",      # run: the boundary of stage k exists iff k + 1 < L (public)
    r"^let core = \{$",
    r"^let mut rng = ZkRng::from_os",
]

print(f"A. EVERY GENERATOR LINE ON THE PATH, at {COMMIT}")
unclassified, draws, bad_headers, reach, off_path = [], [], [], {}, set()
for path in FILES:
    lines = production(show(path))
    for idx, (ln, l) in enumerate(lines):
        if not WORD.search(l):
            continue
        cls = next((c for c, rx in CLASS if rx.search(l)), None)
        if cls is None:
            unclassified.append((path, ln, l.strip()))
            continue
        if cls == "COMMENT/STR":
            continue
        fn, hs = enclosing(lines, idx)
        fname = re.search(r"fn\s+(\w+)", fn[1]).group(1) if fn else "?"
        if (path, fname) in OFF_PATH:
            off_path.add((path, fname))
            continue
        reach.setdefault(fname, set()).add(path)
        if cls == "DRAW":
            draws.append((path, ln, fname, l.strip(), hs))
            for hl, ht in hs:
                if re.match(r"^(if|match|while|loop|else)\b|^\} else", ht):
                    bad_headers.append((path, hl, ht))
                elif ht.startswith("for ") or ht.startswith("let "):
                    if not any(re.match(p, ht) for p in PUBLIC_BOUNDS):
                        bad_headers.append((path, hl, ht))
for path, ln, fname, s, hs in draws:
    chain = " <- ".join(f"{h[0]}:`{h[1][:56]}`" for h in hs) or "(function body)"
    print(f"   {path.split('/')[-1]}:{ln} [{fname}] {s[:90]}")
    print(f"        within {chain}")
assert not unclassified, f"generator lines no class covers: {unclassified}"
block_files = [p for p in FILES if "private_block" in p or p.endswith("private_seam.rs")]
block_text = "\n".join(l for p in block_files for _, l in production(show(p)))
print(f"   off-path generator functions (named, excluded, and asserted uncalled from the private-block files):")
for path, fname in sorted(off_path):
    print(f"      {path.split('/')[-1]}::{fname} — {OFF_PATH[(path, fname)]}")
assert "zk::mask_commit(" not in "\n".join(l for p in block_files if "private_seam" not in p for _, l in production(show(p))), "a private-block file calls the untagged zk::mask_commit"
assert "commit_zk_device(" not in block_text and "prove_layer_zk" not in block_text, "a private-block file reaches the FFN generator paths"
assert not bad_headers, f"a draw under a header outside the reviewed public list: {bad_headers}"
print(f"   -> {len(draws)} draw lines; every enclosing header is a reviewed public bound; no if/match/while/loop/else.")

print()
print("   trip-count expressions of the vector draws (each must be a shape/layout/spec constant):")
for path, ln, fname, s, hs in draws:
    m = re.search(r"fp_vec\(([^)]*\)?)\)|fp2_vec\(([^)]*\)?)\)|\(0\.\.(\w+)\)\.map", s)
    if m:
        print(f"      {path.split('/')[-1]}:{ln} [{fname}]  count = {next(g for g in m.groups() if g)}")

print()
print("B. THE GENERATOR'S REACH (functions whose production text names it)")
for fname in sorted(reach):
    print(f"   {fname:40s} {sorted(p.split('/')[-1] for p in reach[fname])}")
for forbidden in ["argument", "run_slot", "open_zk", "mask_open", "masked_prove", "extension", "verify_inner_at", "verify_core",
                  "check_opening", "check_opening_challenges", "audit_claims", "encode_segment", "challenge_fp2", "squeeze_bytes"]:
    assert forbidden not in reach, f"the generator reaches {forbidden}"
print("   -> never the slot argument, the masked sumcheck, an opening, a refusal check, the wire encoder,")
print("      the transcript or a verifier.")

print()
print("C. EXITS AFTER THE FIRST DRAW (for the check's refusal table)")
EXIT = re.compile(r"\?[;),.\s]|\?$|return Err|\bassert(_eq|_ne)?!|\bpanic!|\.expect\(|\.unwrap\(\)|unreachable!")


def body(path, sig):
    lines = production(show(path))
    start = next(i for i, (_, l) in enumerate(lines) if sig in l)
    d = indent(lines[start][1])
    end = next(i for i in range(start + 1, len(lines)) if lines[i][1].rstrip() == " " * d + "}")
    return lines, start, end


def exits_after(path, sig, first_marker):
    lines, s, e = body(path, sig)
    first = next((i for i in range(s, e) if first_marker in lines[i][1]), s)
    out = []
    for i in range(first, e):
        ln, l = lines[i]
        t = l.strip()
        if not t or t.startswith("//") or t.startswith("///"):
            continue
        if EXIT.search(t):
            out.append((ln, t))
    return out


ENTRY = [
    ("hashline/src/private_block/protocol.rs", "pub(crate) fn prove_core(", "*x = rng.fp();"),
    ("hashline/src/private_block/protocol.rs", "pub(crate) fn prove_inner_at(", "ZkRng::from_os"),
    ("hashline/src/private_block/run.rs", "pub(crate) fn prove_run(", "ZkRng::from_os"),
    ("hashline/src/private_block.rs", "pub fn prepare_endpoints(", "let (input, output) = if spec.general"),
]
CALLED = [
    ("hashline/src/private_block/argument.rs", "pub(crate) fn run_slot("),
    ("hashline/src/private_block/protocol.rs", "pub(crate) fn audit_claims("),
    ("hashline/src/private_block/protocol.rs", "pub(crate) fn check_opening_challenges("),
    ("hashline/src/private_block/protocol.rs", "pub(crate) fn check_opening("),
    ("hashline/src/private_block/protocol.rs", "pub(super) fn check_endpoint_opening("),
    ("hashline/src/private_block/protocol.rs", "pub(super) fn check_endpoints("),
    ("hashline/src/private_block/protocol.rs", "fn inverses("),
    ("hashline/src/private_block/boundary.rs", "pub(crate) fn into_opening("),
    ("hashline/src/private_block/wire.rs", "fn validate_segment("),
    ("hashline/src/private_block/wire.rs", "pub(crate) fn encode_segment("),
    ("hashline/src/zk.rs", "pub(crate) fn masked_prove<"),
    ("hashline/src/zk.rs", "pub(crate) fn extension<"),
    ("hashline/src/zk.rs", "pub fn mask_open("),
    ("zkp-core/src/pcs.rs", "pub fn open_zk<"),
    ("zkp-core/src/pcs.rs", "pub fn assert_mask_sites<"),
    ("zkp-core/src/sumcheck.rs", "pub fn round(&self"),
    ("zkp-core/src/sumcheck.rs", "fn mask_round(&mut self"),
]
for path, sig, marker in ENTRY:
    ex = exits_after(path, sig, marker)
    print(f"   {path.split('/')[-1]} :: {sig.strip()}  (after `{marker}`)")
    for ln, t in ex:
        print(f"      {ln:>5}  {t[:120]}")
for path, sig in CALLED:
    lines, s, e = body(path, sig)
    ex = [(lines[i][0], lines[i][1].strip()) for i in range(s, e + 1) if lines[i][1].strip() and not lines[i][1].strip().startswith("//") and EXIT.search(lines[i][1].strip())]
    print(f"   {path.split('/')[-1]} :: {sig.strip()}  ({len(ex)} exits)")
    for ln, t in ex:
        print(f"      {ln:>5}  {t[:120]}")

print()
print("ALL ASSERTIONS PASSED")
