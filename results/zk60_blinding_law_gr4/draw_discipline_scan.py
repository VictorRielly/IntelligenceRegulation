#!/usr/bin/env python3
"""G-R4: the draw discipline read off the code, pinned to a commit.

Evidence for docs/zkmatrix-poc/ZK60_BLINDING_LAW_GR4.md section 3.

Every source file is read with `git show <commit>:<path>` from the lane
worktree (READ-ONLY; nothing is written there), so the scan is of the
commit, not of whatever the worktree holds.  Default commit: 2ea7221, the
lane tip `zk60-private-block-125m` at stage 46.

What it prints and asserts:

  A. Every generator consumption on the private-block path, IN SOURCE ORDER
     per production function, with the chain of enclosing block headers
     (by rustfmt indentation).  Asserted: the exact (line, text) sequence at
     the pinned commit, and that no enclosing header is an `if`, `match`,
     `while` or `loop` EXCEPT the one public run-loop condition
     `if k + 1 < l` (run.rs) -- i.e. the ORDER and NUMBER of draws are
     functions of shape constants, the loop index and L, nothing else.
  B. Every early exit (`?`, `return Err`) inside prove_core AFTER its first
     draw, so the refusal inventory of section 5 can be audited line by line.
  C. That no generator reaches the slot argument or any opening: argument.rs
     has no `rng` in its production text, and `pcs::open_zk` / `zk::mask_open`
     take no generator.
  D. The generator's public surface (rng.rs production part): no seek, no
     set, no Clone/Copy/Serialize -- so a stream word is returned at most once.
  E. A REPLICA, in Python, of the lane's Rust test
     `s36_tests::the_only_relations_imposed_on_drawn_values_are_the_three_
     the_schedule_declares` (J-5's assertion 6), run on the same nine files at
     the same commit: which drawn buffers its scan can see, and three
     mutations -- two it does not flag, one it does (the control).  This is
     MY PORT of the test's matching logic (s36_tests.rs:727-796, helpers
     :880-906), not the Rust test; a checker should confirm on the Rust.

Run:  python3 draw_discipline_scan.py [commit]    (exits 0: ALL ASSERTIONS PASSED)
"""

import re
import subprocess
import sys

LANE = "/home/victor/wt-zk60-block125m"
COMMIT = sys.argv[1] if len(sys.argv) > 1 else "2ea7221"


def show(path):
    return subprocess.run(["git", "-C", LANE, "show", f"{COMMIT}:{path}"],
                          check=True, capture_output=True, text=True).stdout


def indent(line):
    return len(line) - len(line.lstrip(" "))


def body_range(lines, signature):
    """(open, close) 0-based line indices of the function whose signature
    line contains `signature`: `open` is the line that opens the body (the
    signature itself, or the last line of a multi-line signature), `close`
    the first later line that is exactly the signature's indentation
    followed by '}'."""
    starts = [i for i, l in enumerate(lines) if signature in l]
    assert len(starts) == 1, f"`{signature}`: {len(starts)} matches"
    i0 = starts[0]
    d = indent(lines[i0])
    op = next(j for j in range(i0, len(lines)) if lines[j].rstrip().endswith("{") and indent(lines[j]) == d)
    close = " " * d + "}"
    for j in range(op + 1, len(lines)):
        if lines[j].rstrip() == close:
            return op, j
    raise AssertionError(f"`{signature}`: no closing brace")


def headers(lines, i, i0):
    """the enclosing block headers of line i, innermost first, down to i0"""
    out = []
    cur = indent(lines[i])
    for j in range(i - 1, i0, -1):
        l = lines[j]
        if not l.strip() or l.strip().startswith("//"):
            continue
        d = indent(l)
        if d < cur and l.rstrip().endswith("{"):
            out.append((j + 1, l.strip()))
            cur = d
    return out


DRAW = re.compile(r"rng\.(fp\(|fp_vec\(|fp2_vec\(|fp2\(|bytes32\()|ZkRng::from_os\(|CfsMask::random\(rng|"
                  r"commit_zk_owned_tagged\(|commit_zk_owned\(|mask_commit_tagged\(|boundary::prepare\(|"
                  r"prove_core\(|prepare_with_rng\(")

# (file, signature, expected [(line, fragment)] in order) at 2ea7221
FUNCS = [
    ("hashline/src/private_block/protocol.rs", "pub(crate) fn prove_inner_at(", [
        (813, "ZkRng::from_os(&super::hash_domain::single_block_seed_domain(sh))"),
        (818, "prove_core(sh, &lay, blk, wit,"),
    ]),
    ("hashline/src/private_block/protocol.rs", "pub(crate) fn prove_core(", [
        (1003, "*x = rng.fp();"),                                  # A mask + proximity rows (for at 1002)
        (1009, "pcs::commit_zk_owned_tagged(&params, a_data"),     # A pads, A salts
        (1021, "zk::mask_commit_tagged(&lay.mask_specs()"),        # M: alpha, pads, b, u, salts
        (1116, "*x = rng.fp();"),                                  # H mask + proximity rows (for at 1115)
        (1121, "let v = rng.fp();"),                               # H zero-sum rows, n-1 each
        (1128, "pcs::commit_zk_owned_tagged(&params, h_data"),     # H pads, H salts
    ]),
    ("hashline/src/private_block/run.rs", "pub(crate) fn prove_run(", [
        (727, "ZkRng::from_os(&super::hash_domain::run_seed_domain("),
        (756, "boundary::prepare(&spec, &words(&plane), &ntt, &mut rng, &tag)?"),
        (774, "protocol::prove_core(sh, &lay, &blocks[k], wit,"),
    ]),
    ("hashline/src/private_block/boundary.rs", "pub(crate) fn prepare(spec: &BoundarySpec", [
        (347, "*x = rng.fp();"),
        (350, "pcs::commit_zk_owned_tagged(&params, data"),
    ]),
    ("hashline/src/private_block/endpoint_g.rs", "pub(crate) fn prepare(spec: &EndpointSpecG", [
        (269, "ZkRng::from_os(&seed_domain(spec, role))"),
        (277, "*x = rng.fp();"),
        (280, "pcs::commit_zk_owned_tagged(&params, data"),
    ]),
    ("hashline/src/private_seam.rs", "pub fn prepare(", [
        (196, "ZkRng::from_os(DOMAIN)"),
        (197, "prepare_with_rng(spec, side, values, ntt, &mut rng)"),
    ]),
    ("hashline/src/private_seam.rs", "fn prepare_with_rng(", [
        (212, "*x = rng.fp();"),
        (215, "pcs::commit_zk_owned(&params, data"),
    ]),
    ("hashline/src/zk.rs", "pub fn mask_commit_tagged(", [
        (485, "CfsMask::random(rng, n, d)"),
        (496, "let pads = rng.fp_vec(MASK_Q);"),
        (503, "let mut b_re = rng.fp_vec(2 * m);"),
        (504, "let mut b_im = rng.fp_vec(2 * m);"),
        (507, "let u_re = rng.fp_vec(2 * m);"),
        (508, "let u_im = rng.fp_vec(2 * m);"),
        (513, "rng.bytes32()"),
    ]),
    ("zkp-core/src/pcs.rs", "pub fn commit_zk_owned_with_tag<", [
        (777, "let pads = rng.fp_vec(rows * q);"),
        (778, "rng.bytes32()"),
    ]),
    ("zkp-core/src/pcs.rs", "pub fn commit_zk_owned_with<", [
        (724, "let pads = rng.fp_vec(rows * q);"),
        (725, "rng.bytes32()"),
    ]),
    ("zkp-core/src/sumcheck.rs", "pub fn random(rng: &mut crate::rng::ZkRng", [
        (202, "rng.fp2_vec(Self::len(n_vars, degree))"),
    ]),
]

PUBLIC_HEADERS = [
    # every loop / block header that encloses a draw, and why it is public
    (r"^for x in &mut a_data\[lay\.a_mask_base \* n\.\.\] \{$", "a layout constant"),
    (r"^for x in &mut h_data\[lay\.h_mask_base \* n\.\.\] \{$", "a layout constant"),
    (r"^for r in lay\.h_u_rows\(\) \{$", "a layout constant (two rows)"),
    (r"^for j in 0\.\.n - 1 \{$", "the row width"),
    (r"^for x in &mut data\[first_mask \* n\.\.\] \{$", "spec.data_rows(), a spec constant"),
    (r"^for k in 0\.\.l \{$", "the run length L"),
    (r"^let cur = if k \+ 1 < l \{$", "the loop index and L"),
    (r"^let core = \{$", "a plain block"),
    (r"^for \(s, mk\) in masks\.iter\(\)\.enumerate\(\) \{$", "the 23 slot specs (layout)"),
    (r"^for \(k, part\) in \[re, im\]\.iter\(\)\.enumerate\(\) \{$", "two parts"),
    (r"^let core = protocol::prove_core", "n/a"),
]

print(f"A. GENERATOR CONSUMPTION IN SOURCE ORDER at {COMMIT}")
bad = []
for path, sig, want in FUNCS:
    lines = show(path).split("\n")
    i0, i1 = body_range(lines, sig)
    got = []
    for i in range(i0 + 1, i1):
        l = lines[i]
        s = l.strip()
        if s.startswith("//") or s.startswith("*") and not s.startswith("*x"):
            continue
        if DRAW.search(l):
            got.append((i + 1, s, headers(lines, i, i0)))
    print(f"   {path} :: {sig.strip()}  (lines {i0 + 1}-{i1 + 1})")
    for ln, s, hs in got:
        chain = " <- ".join(f"{h[0]}:`{h[1][:60]}`" for h in hs) or "(function body)"
        print(f"      {ln:>5}  {s[:78]}")
        print(f"             within {chain}")
        for hl, ht in hs:
            if re.match(r"^(if|match|while|loop)\b|^\} else", ht) or (" if " in ht and "if k + 1 < l" not in ht):
                bad.append((path, hl, ht))
            elif not any(re.match(p, ht) for p, _ in PUBLIC_HEADERS):
                bad.append((path, hl, ht))
    assert [(ln, ) for ln, _, _ in got] == [(ln, ) for ln, _ in want], \
        f"{path} {sig}: draw lines {[g[0] for g in got]} != expected {[w[0] for w in want]}"
    for (ln, s, _), (wl, frag) in zip(got, want):
        assert frag in s, f"{path}:{ln}: `{frag}` not in `{s}`"
assert not bad, f"a draw sits under a header that is not a public loop/condition: {bad}"
print("   -> every draw is under public loops only (shape/layout constants, the run index k and L);")
print("      no draw is under an if/match/while/loop on a witness value, a challenge, a drawn value,")
print("      a feature flag or an environment variable.")

print()
print("B. EARLY EXITS in prove_core AFTER its first draw (the refusal inventory of section 5)")
lines = show("hashline/src/private_block/protocol.rs").split("\n")
i0, i1 = body_range(lines, "pub(crate) fn prove_core(")
first_draw = 1003 - 1
exits = []
for i in range(first_draw, i1):
    s = lines[i].strip()
    if s.startswith("//"):
        continue
    if "?" in s and ("(" in s or ")?" in s) or "return Err" in s:
        exits.append((i + 1, s))
for ln, s in exits:
    print(f"      {ln:>5}  {s[:110]}")
EXPECTED_EXITS = [1052, 1053, 1060, 1062, 1092, 1111, 1140, 1153, 1157]
assert [e[0] for e in exits] == EXPECTED_EXITS, f"exits moved: {[e[0] for e in exits]}"
print("   (1111 is inside a #[cfg(test)] injection block, 1102-1114; not in a release build)")

print()
print("C. NO GENERATOR IN THE SLOT ARGUMENT OR THE OPENINGS")
arg = show("hashline/src/private_block/argument.rs")
arg_prod = arg[: arg.find("\n#[cfg(test)]\nmod tests {")] if "\n#[cfg(test)]\nmod tests {" in arg else arg
assert "rng" not in re.sub(r"//.*", "", arg_prod), "argument.rs production text mentions rng"
pcs = show("zkp-core/src/pcs.rs").split("\n")
a, b = body_range(pcs, "pub fn open_zk<")
assert "rng" not in "\n".join(pcs[a:b + 1])
zk = show("hashline/src/zk.rs").split("\n")
a, b = body_range(zk, "pub fn mask_open(")
assert "rng" not in "\n".join(zk[a:b + 1])
print("   argument.rs (production text): no `rng`;  pcs::open_zk: no generator;  zk::mask_open: no generator")

print()
print("D. THE GENERATOR'S PUBLIC SURFACE (zkp-core/src/rng.rs, production part = lines 1-100)")
rng = show("zkp-core/src/rng.rs").split("\n")
prod = rng[:100]
pubs = [l.strip() for l in prod if l.strip().startswith("pub fn")]
for p in pubs:
    print(f"      {p}")
assert [p.split("(")[0] for p in pubs] == ["pub fn new", "pub fn from_os", "pub fn next_u64", "pub fn fp",
                                           "pub fn fp2", "pub fn fp_vec", "pub fn fp2_vec", "pub fn bytes32"]
joined = "\n".join(prod)
for forbidden in ["impl Clone", "derive(", "Serialize", "fn set_", "fn seek", "pub key", "pub counter", "pub pos", "pub buf"]:
    assert forbidden not in joined, forbidden
assert "self.pos += 8;" in joined and "self.counter += 1;" in joined
print("   -> no seek/set/rewind, fields private, not Clone/Copy/Serialize: `pos` only grows by 8 inside a")
print("      buffer and `counter` only grows, so each stream word is returned AT MOST ONCE per generator.")

print()
print("E. REPLICA of the Rust assertion-6 scan (J-5 #6) on its own nine files at", COMMIT)
FILES6 = ["hashline/src/zk.rs", "hashline/src/pcs.rs", "hashline/src/private_seam.rs",
          "hashline/src/private_block/protocol.rs", "hashline/src/private_block/endpoint_g.rs",
          "hashline/src/private_block/boundary.rs", "zkp-core/src/pcs.rs", "zkp-core/src/sumcheck.rs",
          "zkp-core/src/rng.rs"]


def production_text(src):
    k = src.find("\n#[cfg(test)]\nmod tests {")
    return src if k < 0 else src[: k + 1]


def binding_name(line):
    t = line.strip()
    if not t.startswith("let "):
        return None
    t = t[4:]
    if t.startswith("mut "):
        t = t[4:]
    m = re.match(r"[A-Za-z0-9_]*", t)
    return m.group(0) or None


# NB the Rust test skips a line whose trimmed text starts with '*'
# (s36_tests.rs:738, meant for doc-comment continuation lines), which ALSO
# skips `*x = rng.fp();` -- the fill idiom never reaches binding_name, and
# binding_name needs a `let` anyway (s36_tests.rs:897-906).
def scan_exact(texts):
    found, drawn_by_file, fills = [], {}, []
    for path, text in texts.items():
        drawn = set()
        for ln, line in enumerate(text.split("\n"), 1):
            t = line.strip()
            if "*x = rng.fp();" in t:
                fills.append((path, ln))
            if t.startswith("//") or t.startswith("*"):
                continue
            for pat in ["rng.fp_vec(", "rng.fp2_vec(", "rng.bytes32(", "rng.fp()"]:
                if pat in t:
                    n = binding_name(t)
                    if n:
                        drawn.add(n)
        drawn_by_file[path] = sorted(drawn)
        for ln, line in enumerate(text.split("\n"), 1):
            t = line.strip()
            if t.startswith("//") or t.startswith("*") or " = " not in t:
                continue
            lhs = t.split(" = ")[0]
            while lhs.startswith("let "):
                lhs = lhs[4:]
            lhs = lhs.strip()
            for name in drawn:
                if lhs.startswith(name + "[") and "rng." not in t:
                    found.append(f"{path}:{ln}: {t}")
    return sorted(found), drawn_by_file, fills


texts = {p: production_text(show(p)) for p in FILES6}
found, drawn, fills = scan_exact(texts)
for p in FILES6:
    print(f"      drawn buffers the scan can see in {p}: {drawn[p]}")
print(f"   relations found: {len(found)}")
for f in found:
    print(f"      {f}")
assert len(found) == 4 and all(f.endswith("b_re[m] = b_re[0].neg();") or f.endswith("b_im[m] = b_im[0].neg();") for f in found), \
    "the replica does not reproduce the Rust test's four declared sites"
print("   -> reproduces the Rust test's result: exactly the four declared overwrite sites.")
print(f"   the fill idiom `*x = rng.fp();` (skipped by the scan: the line starts with '*'): {len(fills)} production sites")
for p, ln in fills:
    print(f"      {p}:{ln}")
assert sorted(fills) == sorted([("hashline/src/private_block/protocol.rs", 1003), ("hashline/src/private_block/protocol.rs", 1116),
                                ("hashline/src/private_block/endpoint_g.rs", 277), ("hashline/src/private_block/boundary.rs", 347),
                                ("hashline/src/private_seam.rs", 212)])
for p in FILES6:
    assert "a_data" not in drawn[p] and "h_data" not in drawn[p] and "data" not in drawn[p] and "masks" not in drawn[p]
print("   -> NOT in the scan's drawn set: A's and H's reserved pairs + proximity rows (a_data, h_data),")
print("      every endpoint's and boundary's mask rows (data), and the CFS coefficients alpha (masks,")
print("      drawn through CfsMask::random(rng, ..), which contains no `rng.` pattern).")

# mutations: each inserted as ONE line into the production text, then the replica re-run
MUT = [
    ("m1: overwrite a DRAWN A proximity-row word after the fill", "hashline/src/private_block/protocol.rs", 1004,
     "    a_data[lay.a_prox * n] = Fp::ZERO;", False),
    ("m2: copy an A reserved-pair word into H's reserved rows", "hashline/src/private_block/protocol.rs", 1117,
     "    h_data[lay.h_mask_base * n] = a_data[lay.a_mask_base * n];", False),
    ("m3 (CONTROL): overwrite a drawn u_re word (a let-bound draw)", "hashline/src/zk.rs", 508,
     "    u_re[1] = u_re[0].neg();", True),
]
print()
print("   mutations (one inserted line each; does the replica flag it?)")
for label, path, after, text, expect in MUT:
    t2 = dict(texts)
    ls = t2[path].split("\n")
    ls.insert(after, text)
    t2[path] = "\n".join(ls)
    f2, _, _ = scan_exact(t2)
    flagged = len(f2) != len(found)
    assert flagged == expect, f"{label}: flagged={flagged}, expected {expect}"
    print(f"      {label:62s} flagged={flagged}")
print("   -> the scan pins the relations on pads, salts, b and u; it cannot see a relation or a copy")
print("      imposed on the reserved pairs, the proximity rows, the endpoint/boundary mask rows or alpha.")

print()
print("ALL ASSERTIONS PASSED")
