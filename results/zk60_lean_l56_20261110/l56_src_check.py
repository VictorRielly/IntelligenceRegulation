#!/usr/bin/env python3
"""D63 lane L56 (2026-11-10): SOURCE checks of the code facts lane L56's Lean objects rest on (the production verifier
in ops/zkp-mvp/gpu-metal/hashline/src/private_block, read-only). Each check is a list of exact source fragments that must
occur IN ORDER inside one function's body; with `--negative`, every fragment of every check is in turn removed from a
copy of the source at the place the check matched it (and, for the frame's order, two fragments swapped), and each change
must be refused.

  RUNLOOP  `verify_classify_run_with` (classify_run.rs): stage IN-C hands on `(b0, b_root)`; block `k`'s part loads
           block `k`, its layout `block_layout(k)`, absorbs `pb-run-stage` `k + 1`, `pb-run-block` `block_digests[k]`,
           then `absorb_root(B)` of ITS segment's boundary root (spec `boundary_spec(k + 1)`) -- the frame's position
           2; verifies its core at `stage_shape(k)`; its incoming claims follow the carried ones; the boundary opening
           is verified against the PREVIOUS part's root `proot`; the carry becomes `(spec, root)`; stage OUT-C opens
           `broot` of the carry: the closing opening of part `i + 1` opens the root part `i`'s frame absorbed at its
           position 2 (lane L56's `hgXB`: `(base (i + 1)).gX.ipos = off i + 2`);
  ROOT     `absorb_root` (protocol.rs): the root, then `rows`, then `log-cols` (three absorbs);
  INFRAME  stage IN-C's `verify` (stage_in_c.rs): `pb-run-stage` 0, `pb-run-block`, `absorb_root(B)` of `B_in`, then
           `A`: stage IN-C's frame has the same positions;
  STAGES   `ClassifyRunStatement::new`-side (classify.rs): stage `k`'s calibration and gate are layer record `k`'s,
           and layer record `k` must carry block `k`'s digest; `stage_shape(k)` reads `stage_cal[k]`, `stage_gate[k]`;
           `block_layout(k)` is the layout at `stage_shape(k)` with the IO mask rows of boundaries `k` and `k + 1`:
           block `k` IS layer `k`, in order (lane L56's `hPk`, finding L54-2), and reads boundaries `k` (input) and
           `k + 1` (output);
  BSPEC    `boundary_spec(j)` is built from the RUN's shape and `j` alone (not from a block's stage shape): block `k`
           (output) and block `k + 1` (input) read boundary `k + 1` through the same commitment geometry (finding
           L46-3's first fact).
usage: python3 l56_src_check.py <hashline/src/private_block dir> [--negative]
"""
import sys

CHECKS = {
    "RUNLOOP": ("token_io/classify_run.rs", "pub(crate) fn verify_classify_run_with(", [
        "let (mut pending, b_root) = super::stage_in_c::verify(",
        "let mut prev: (BoundarySpec, Digest) = (b0, b_root);",
        "for k in 0..l {",
        "let blk = blocks.block(k)?;",
        "let lay = st.block_layout(k)?;",
        "tr.absorb_u64(b\"pb-run-stage\", (k + 1) as u64);",
        "tr.absorb(b\"pb-run-block\", &st.block_digests[k]);",
        "let spec = st.boundary_spec(k + 1)?;",
        "let root = seg.b_root.ok_or_else(",
        "protocol::absorb_root(&mut tr, b\"B\", &root, spec.commitment_rows(), spec.log_n());",
        "let ssh = st.stage_shape(k)?;",
        "let ([ic, oc], _) = protocol::verify_core(&ssh, &lay, &blk, view, &ntt, &mut tr, &mut ph)",
        "let mut claims = std::mem::take(&mut pending);",
        "claims.extend(ic);",
        "let (pspec, proot) = prev;",
        "pcs::verify_zk_tagged(&bp, &ZkOpts::standard(&bp), &protocol::commitment(proot, pspec.commitment_rows(), pspec.log_n()), &claims, &seg.in_open,",
        "pending = oc;",
        "prev = (spec, root);",
        "let (bspec, broot) = prev;",
        "super::stage_out_c::verify(&out_lay, cp, tables, st.verdict(), &seg, &bspec, &broot, pending,",
    ]),
    "ROOT": ("protocol.rs", "pub(super) fn absorb_root(", [
        "tr.absorb(label, root);",
        "tr.absorb_u64(b\"rows\", rows as u64);",
        "tr.absorb_u64(b\"log-cols\", log_cols as u64);",
    ]),
    "INFRAME": ("token_io/stage_in_c.rs", "pub(crate) fn verify(", [
        "let b_root = seg.b_root.ok_or(",
        "tr.absorb_u64(b\"pb-run-stage\", 0);",
        "tr.absorb(b\"pb-run-block\", &cp.emb_digest);",
        "protocol::absorb_root(tr, b\"B\", &b_root, b_spec.commitment_rows(), b_spec.log_n());",
        "protocol::absorb_root(tr, b\"A\", &seg.a_root, lay.a_rows, lay.log_n);",
    ]),
    "STAGES": ("token_io/classify.rs", "let mut stage_cal = vec![base; l];", [
        "for (k, r) in model.layers.iter().enumerate() {",
        "if block_digests.get(k) != Some(&r.block_digest) {",
        "stage_gate[k] = r.accuracy_gate_shift;",
        "stage_cal[k] = cal;",
        "pub(crate) fn stage_shape(&self, k: usize) -> Result<Shape, String> {",
        "let cal = *self.stage_cal.get(k)",
        "let g = self.stage_gate.get(k).copied().flatten()",
        "pub(crate) fn block_layout(&self, k: usize) -> Result<Layout, String> {",
        "Ok(Layout::for_shape(&self.stage_shape(k)?)?.with_io_mask_rows([self.boundary_spec(k)?.mask_row(1)?, self.boundary_spec(k + 1)?.mask_row(0)?]))",
    ]),
    "BSPEC": ("token_io/classify.rs", "pub(crate) fn boundary_spec(&self, j: usize) -> Result<BoundarySpec, String> {", [
        "let sh = self.sh();",
        "BoundarySpec::new_with_tag(self.context, sh.t_pad, sh.d_pad, self.scale, (j + 1) as u64, 2, sh.endpoint_log_n,",
    ]),
}
SWAPS = [("RUNLOOP", 6, 9), ("INFRAME", 2, 3)]


def body(text, start):
    """The source from `start` to the end of that function (the first closing brace at column 0 after it)."""
    i = text.index(start)
    j = text.find("\n}\n", i)
    if start.startswith("let mut stage_cal"):
        j = text.find("pub(crate) fn block_geom(", i)
        j = text.find("\n    }\n", text.find("pub(crate) fn block_layout(", i))
    return text[i:j if j >= 0 else len(text)]


def check(srcs):
    fails, n = [], 0
    for name, (fn, start, frags) in CHECKS.items():
        text = srcs[fn]
        n += 1
        if start not in text:
            fails.append("%s: no %r" % (name, start))
            continue
        b = body(text, start)
        pos = 0
        for f in frags:
            n += 1
            i = b.find(f, pos)
            if i < 0:
                fails.append("%s: %r missing or out of order" % (name, f[:70]))
            else:
                pos = i + len(f)
    return fails, n


def main():
    d = sys.argv[1]
    files = sorted({fn for (fn, _, _) in CHECKS.values()})
    srcs = {fn: open(d + "/" + fn).read() for fn in files}
    fails, n = check(srcs)
    print("l56_src_check: %d checks, %d failures" % (n, len(fails)))
    for f in fails:
        print("  FAIL", f)
    rc = 1 if fails else 0
    if "--negative" in sys.argv:
        tot, caught = 0, 0
        for name, (fn, start, frags) in CHECKS.items():
            b = body(srcs[fn], start)
            at, pos = [], 0
            for f in frags:
                i = b.find(f, pos)
                at.append(i)
                pos = i + len(f)
            for f, i in zip(frags, at):
                m = dict(srcs)
                nb = b[:i] + "/* removed */" + b[i + len(f):]
                m[fn] = m[fn].replace(b, nb, 1)
                fl, _ = check(m)
                tot += 1
                caught += bool(fl)
                if not fl:
                    print("  negative removal %s %r: NOT REFUSED" % (name, f[:70]))
        for (name, a, b2) in SWAPS:
            fn, start, frags = CHECKS[name]
            m = dict(srcs)
            bb = body(m[fn], start)
            x, y = frags[a], frags[b2]
            nb = bb.replace(x, "\x00", 1).replace(y, x, 1).replace("\x00", y, 1)
            m[fn] = m[fn].replace(bb, nb, 1)
            fl, _ = check(m)
            tot += 1
            caught += bool(fl)
            print("  negative swap %s %d<->%d: %s" % (name, a, b2, "refused" if fl else "NOT REFUSED"))
        print("l56_src_check negative: %d of %d single changes refused" % (caught, tot))
        if caught != tot:
            rc = 1
    sys.exit(rc)


if __name__ == "__main__":
    main()
