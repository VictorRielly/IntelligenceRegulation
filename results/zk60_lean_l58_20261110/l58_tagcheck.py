#!/usr/bin/env python3
"""D63 lane L58 (2026-11-10): CHECK in the production source that the input endpoint commitment's Merkle tag is the
run verifier's (`tagc := tag` in `ex_productionReadyL_epP_codeG`), and that the readers of the opened columns refuse a
non-canonical word (L52-5; the checked extractor drops such columns, so it must not miss a column the verifier
accepts). With a negative control: every single change below must make the check fail.

The anchors (file: what must hold):
  T1 classify_run.rs `verify_classify_run_with`: `sh` is the statement's shape, `tag = sh.hash_tag()`, and stage IN-C's
     verifier is called with the statement's input root `st.in_root()` and that `tag`;
  T2 stage_in_c.rs `verify`: the input token endpoint's closing opening is `pcs::verify_zk_tagged` at the commitment
     of `ep_root` under that `tag`;
  T3 pcs.rs `verify_zk_tagged`: an opened column's leaf is `salt_leaf_keyed(hash_column_keyed(col, column key),
     salt, leaf key)` and its path is checked with the node key, all three of `tag`;
  T4 token_io.rs `owner_rebuild_root` (the input commitment's opening relation: the owner's decommitment rebuilds the
     root): the same three keys of its `tag`, and a refusal of non-canonical words;
  T5 classify_run.rs `owner_check_input`: `owner_rebuild_root` at the statement's input root under
     `st.sh().hash_tag()` (the verifier's `sh.hash_tag()`, T1);
  C1 token_io.rs and wire.rs `Reader::fp`: a word `>= P` is refused.
usage: python3 l58_tagcheck.py <WT>
"""
import sys

WT = sys.argv[1] if len(sys.argv) > 1 else "."
SRC = WT + "/ops/zkp-mvp/gpu-metal/"
FILES = {
    "classify_run": SRC + "hashline/src/private_block/token_io/classify_run.rs",
    "stage_in_c": SRC + "hashline/src/private_block/token_io/stage_in_c.rs",
    "pcs": SRC + "zkp-core/src/pcs.rs",
    "token_io": SRC + "hashline/src/private_block/token_io.rs",
    "wire": SRC + "hashline/src/private_block/wire.rs",
}


def body(text, head):
    """The text of the function starting at `head` up to the next line that is exactly `}` (a top-level fn's end)."""
    if text.count(head) != 1:
        return None
    a = text.index(head)
    b = text.find("\n}\n", a)
    return text[a:b] if b >= 0 else None


def in_order(text, parts):
    if text is None:
        return False
    at = 0
    for p in parts:
        k = text.find(p, at)
        if k < 0:
            return False
        at = k + len(p)
    return True


def check(t):
    res = []
    b1 = body(t["classify_run"], "pub(crate) fn verify_classify_run_with(st: &ClassifyRunStatement")
    res.append(("T1 verifier: sh = st.sh(), tag = sh.hash_tag(), IN-C verified at st.in_root() under tag",
                in_order(b1, ["let (sh, l, cp) = (st.sh(), st.l(), &st.cp);", "let tag = sh.hash_tag();",
                              "super::stage_in_c::verify(&in_lay, cp, tables, &seg, &b0, &st.in_spec, &st.in_root(), "
                              "&ntt, &mut tr, &tag)?;"])
                and b1.count("let tag =") == 1))
    b2 = body(t["stage_in_c"], "pub(crate) fn verify(\n")
    res.append(("T2 IN-C: the input endpoint's closing opening at ep_root under tag",
                in_order(b2, ["ep_root: &Digest,", "tag: &zkp_core::hashtag::HashTag,",
                              "pcs::verify_zk_tagged(&ep_params, &ZkOpts::standard(&ep_params), "
                              "&protocol::commitment(*ep_root, ep_spec.commitment_rows(), cp.tier.ep_log_n), &ic, "
                              "&seg.closes[0], ntt, tr, tag)"])))
    b3 = body(t["pcs"], "pub fn verify_zk_tagged(")
    res.append(("T3 verify_zk_tagged: column, leaf and node keys of tag",
                in_order(b3, ["tag: &HashTag,",
                              "let leaf = salt_leaf_keyed(&hash_column_keyed(col, tag.column_key()), salt, tag.leaf_key());",
                              "MerkleTree::verify_path_keyed(&cm.root, *j, &leaf, path, tag.node_key())"])))
    b4 = body(t["token_io"], "pub(crate) fn owner_rebuild_root(")
    res.append(("T4 owner_rebuild_root: the same three keys of its tag, non-canonical words refused",
                in_order(b4, ["tag: &zkp_core::hashtag::HashTag",
                              "if dec.data.iter().chain(dec.pads.iter()).any(|x| x.0 >= P) {",
                              "hash_columns_keyed(&encoded, rows, nn, tag.column_key())",
                              "salt_leaf_keyed(l, s, tag.leaf_key())",
                              "MerkleTree::build_keyed(salted, tag.node_key())",
                              "if tree.root() != *root {"])))
    b5 = body(t["classify_run"], "pub(crate) fn owner_check_input(")
    res.append(("T5 owner_check_input: owner_rebuild_root at st.in_root() under st.sh().hash_tag()",
                in_order(b5, ["owner_rebuild_root(&st.in_spec, &st.in_root(), dec, &st.sh().hash_tag())"])))
    fp = "        let v = u64::from_le_bytes(self.take()?);\n        if v >= P {\n            return Err(\"%s\".into());\n        }\n        Ok(Fp(v))"
    res.append(("C1 token I/O Reader::fp refuses a word >= P", (fp % "token I/O wire: noncanonical field word") in t["token_io"]))
    res.append(("C1 private block Reader::fp refuses a word >= P", (fp % "private block wire: noncanonical field word") in t["wire"]))
    return res


texts = {k: open(v).read() for k, v in FILES.items()}
ok = check(texts)
nfail = 0
for name, v in ok:
    print(("ok   " if v else "FAIL ") + name)
    nfail += 0 if v else 1
print("L58 tag check: %d checks, %d failed" % (len(ok), nfail))

MUT = [
    ("classify_run", "let (sh, l, cp) = (st.sh(), st.l(), &st.cp);", "let (sh, l, cp) = (other.sh(), st.l(), &st.cp);"),
    ("classify_run", "    let tag = sh.hash_tag();\n    let ntt = NttTables::new(st.ntt_log());",
     "    let tag = sh.other_tag();\n    let ntt = NttTables::new(st.ntt_log());"),
    ("classify_run", "&st.in_root(), &ntt, &mut tr, &tag)?;", "&st.in_root(), &ntt, &mut tr, &tag2)?;"),
    ("classify_run", "&st.in_spec, &st.in_root(), &ntt, &mut tr, &tag)?;", "&st.in_spec, &st.out_root(), &ntt, &mut tr, &tag)?;"),
    ("stage_in_c", "&seg.closes[0], ntt, tr, tag)", "&seg.closes[0], ntt, tr, &other)"),
    ("stage_in_c", "&protocol::commitment(*ep_root, ep_spec", "&protocol::commitment(*other_root, ep_spec"),
    ("pcs", "salt_leaf_keyed(&hash_column_keyed(col, tag.column_key()), salt, tag.leaf_key());",
     "salt_leaf_keyed(&hash_column_keyed(col, tag.leaf_key()), salt, tag.leaf_key());"),
    ("pcs", "path, tag.node_key())", "path, tag.leaf_key())"),
    ("token_io", "hash_columns_keyed(&encoded, rows, nn, tag.column_key())", "hash_columns_keyed(&encoded, rows, nn, other.column_key())"),
    ("token_io", "salt_leaf_keyed(l, s, tag.leaf_key())", "salt_leaf_keyed(l, s, tag.node_key())"),
    ("token_io", "MerkleTree::build_keyed(salted, tag.node_key())", "MerkleTree::build_keyed(salted, tag.leaf_key())"),
    ("token_io", ".any(|x| x.0 >= P) {", ".any(|x| x.0 > P) {"),
    ("classify_run", "dec, &st.sh().hash_tag())", "dec, &other_tag)"),
    ("token_io", "            return Err(\"token I/O wire: noncanonical field word\".into());\n",
     "            eprintln!(\"token I/O wire: noncanonical field word\");\n"),
    ("wire", "            return Err(\"private block wire: noncanonical field word\".into());\n",
     "            eprintln!(\"private block wire: noncanonical field word\");\n"),
]
AFTER = {"classify_run": "pub(crate) fn verify_classify_run_with(st: &ClassifyRunStatement"}
caught = 0
for f, old, new in MUT:
    # a change is made at the first occurrence AFTER the verifier's own function head (the prover repeats some lines)
    a = texts[f].index(AFTER[f]) if f in AFTER and old not in ("dec, &st.sh().hash_tag())",) else 0
    k = texts[f].find(old, a)
    assert k >= 0, (f, old[:60])
    t2 = dict(texts)
    t2[f] = texts[f][:k] + new + texts[f][k + len(old):]
    bad = [n for n, v in check(t2) if not v]
    if bad:
        caught += 1
        print("control caught: %s: %s -> %s (%s)" % (f, old.strip()[:50], new.strip()[:40], bad[0][:2]))
    else:
        print("CONTROL MISSED: %s: %s" % (f, old.strip()[:60]))
print("L58 tag check controls: %d changes, %d caught" % (len(MUT), caught))
sys.exit(0 if nfail == 0 and caught == len(MUT) else 1)
