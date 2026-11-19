#!/usr/bin/env python3
"""D63 lane L63 (2026-11-18, leg 9): ruling L63-11, the chain with the IN-C cover premise stated UNDER THE INPUT
ENDPOINT'S CLOSENESS (the reordered joint cover, option (b) of finding L63-11).

Writes, from the source files below (never edited), one new file per source,
  formal/ZK60Formal/RunStgShieldCl*.lean,
each a copy of the source's sections that hold a theorem of the chain from `sshC_productionReadyL_epP_blkIOv` down to
`rc_productionReadyL_runChainP_some_range`, with
  R1  every chain theorem renamed `X` -> `X_cl` (definitions and uses); every other public declaration dropped (it is
      imported from the source); private declarations of the kept sections kept;
  R2  in each chain theorem's IN-C cover premise (`hdinX`, `hdinS` or `hdin`) ONE hypothesis inserted before its
      `¬ InOkP` / `¬ InSat`: the input endpoint's closeness
        CloseIn (LinearMap.range (encLin (Q := (C).Q) (C).pts (C).form)) e (exX (ops lg s)) (exU (ops lg s))
      with `C`, `ops`, `e` read off the same theorem's `hdzero` (or its extractor `epxE C mk pos ops …`);
  R3  the two places where that premise is applied (blkIO: `hdinS` from `hdinX`; exec_alive: `hdin` from `hdinS`)
      get the extra argument;
  R4  the bottom (`rc_productionReadyL_runChainP_some_range_cl`) gets a new proof: the ordered cover
      `rc_cover3_someP` at the extra event `Ex ∨ ¬ CloseIn`, its `¬ CloseIn` branch sent to the column test's kinds by
      the gate's own `hX`;
  R5  a new top `sshC_productionReadyL_epP_blkCl` (RunStgShieldClTopL.lean): a copy of
      `sshC_productionReadyL_epP_blkIOl` with the binder `hdinX` REMOVED and discharged by `shd_hdinX_blk` and
      `cl_agree` (= `agree_of_closeIn` at the extracted columns).
Usage: l63_mk_cl.py <worktree root> [--check]"""
import re
import sys

WT = sys.argv[1]
CHECK = "--check" in sys.argv
F = WT + "/formal/ZK60Formal/"

# (source module, new module, chain theorems in it)
PLAN = [
    ("RunCoverPSomeL", "RunStgShieldClCover", ["rc_productionReadyL_runChainP_some_range"]),
    ("RunEpBChain", "RunStgShieldClEb", [
        "eb_productionReadyL_run_epP_some_range", "eb_productionReadyL_run_ep_tokenP_some_range",
        "eb_productionReadyL_epP_some_range", "eb_productionReadyL_epP_exec_some_range",
        "eb_productionReadyL_epP_exec_top_range", "eb_productionReadyL_epP_exec_rk",
        "eb_productionReadyL_epP_exec_stage"]),
    ("RunStgShieldCChain", "RunStgShieldClChain", [
        "sjC_productionReadyL_epP_exec_blk", "sjC_productionReadyL_epP_exec_alive", "sjC_productionReadyL_epP_code",
        "sjC_productionReadyL_epP_codeT", "sjC_productionReadyL_epP_wireT"]),
    ("RunStgShieldCJoin", "RunStgShieldClJoin", [
        "sjC_productionReadyL_epP_wireW", "sjC_productionReadyL_epP_wireX", "sjC_productionReadyL_epP_wireF",
        "sjC_productionReadyL_epP_wireG", "sjC_productionReadyL_epP_join"]),
    ("RunStgShieldCWire", "RunStgShieldClWire", ["bwC_productionReadyL_epP_wire", "bwC_productionReadyL_epP_shield"]),
    ("RunStgShieldCTop", "RunStgShieldClDef", ["sshC_productionReadyL_epP_def"]),
    ("RunStgShieldCTopT", "RunStgShieldClTrue", ["sshC_productionReadyL_epP_true"]),
    ("RunStgShieldCTopC", "RunStgShieldClClaimsO", ["sshC_productionReadyL_epP_claimsO"]),
    ("RunStgShieldCTopW", "RunStgShieldClClaimsW", ["sshC_productionReadyL_epP_claimsW"]),
    ("RunStgShieldCTopDg", "RunStgShieldClDg", ["sshC_productionReadyL_epP_dg"]),
    ("RunBlkPinsHd", "RunStgShieldClPins", ["sshC_productionReadyL_epP_pinsHd_aux", "sshC_productionReadyL_epP_pinsHd"]),
    ("RunStgShieldTopTrO", "RunStgShieldClTrO", ["sshC_productionReadyL_epP_trO"]),
    ("RunStgShieldTopSJ", "RunStgShieldClSJ", ["sshC_productionReadyL_epP_shieldJ", "sshC_productionReadyL_epP_shieldLu"]),
    ("RunShieldBlkInst", "RunStgShieldClBlkLu", ["sshC_productionReadyL_epP_blkLu"]),
    ("RunStgShieldTopBx", "RunStgShieldClBx", ["sshC_productionReadyL_epP_blkIO", "sshC_productionReadyL_epP_blkIOv"]),
]
TOP_SRC, TOP_MOD, TOP_OLD, TOP_NEW = ("RunStgShieldTopL", "RunStgShieldClTopL", "sshC_productionReadyL_epP_blkIOl",
                                      "sshC_productionReadyL_epP_blkCl")
CHAIN = [n for _, _, ns in PLAN for n in ns]
SUF = "_cl"
NAME_END = r"(?![A-Za-z0-9_'!?₀-₉])"
DECL = re.compile(r"^(?:@\[[^\]]*\]\s*)?(?:private |protected |noncomputable |nonrec )*"
                  r"(theorem|lemma|def|abbrev|instance|structure|inductive|example|opaque|axiom)\b\s*(\S*)")


def balanced(s, i):
    """s[i] == '(' ; index just after the matching ')'"""
    d = 0
    for j in range(i, len(s)):
        if s[j] == "(":
            d += 1
        elif s[j] == ")":
            d -= 1
            if d == 0:
                return j + 1
    raise ValueError("unbalanced")


def args_after(s, i, n):
    out = []
    while len(out) < n:
        while s[i] in " \n":
            i += 1
        if s[i] == "(":
            j = balanced(s, i)
            out.append(s[i:j])
            i = j
        else:
            m = re.match(r"[^\s()]+", s[i:])
            out.append(m.group(0))
            i += m.end()
    return out


def blocks(lines):
    """split a file into items: ('decl', name, private?, [lines]) / ('line', text). A decl item carries its docstring;
    it ends before the next column-0 line."""
    items, i, n = [], 0, len(lines)
    in_comment = False
    while i < n:
        l = lines[i]
        if in_comment:
            items.append(("line", l))
            if "-/" in l:
                in_comment = False
            i += 1
            continue
        if l.startswith("/--"):
            j = i
            while "-/" not in lines[j]:
                j += 1
            k = j + 1
            m = DECL.match(lines[k]) if k < n else None
            if m:
                e = k + 1
                while e < n and (lines[e] == "" or lines[e][0] in " \t)"):
                    e += 1
                while lines[e - 1] == "":
                    e -= 1
                items.append(("decl", m.group(2), lines[k].startswith("private"), lines[i:e]))
                i = e
                continue
            items.extend(("line", x) for x in lines[i:j + 1])
            i = j + 1
            continue
        if l.startswith("/-") and "-/" not in l:
            in_comment = True
            items.append(("line", l))
            i += 1
            continue
        m = DECL.match(l)
        if m:
            e = i + 1
            while e < n and (lines[e] == "" or lines[e][0] in " \t)"):
                e += 1
            while lines[e - 1] == "":
                e -= 1
            items.append(("decl", m.group(2), l.startswith("private"), lines[i:e]))
            i = e
            continue
        items.append(("line", l))
        i += 1
    return items


def keep_sections(items, chain):
    """drop every `section X … end X` with no chain theorem, every public non-chain decl, the leading header comment
    and the imports"""
    out, stack = [], []   # stack of (name, start index in out, has_chain)
    header = True
    for it in items:
        if header:
            # the header comment and the imports: everything before the first `set_option`
            if it[0] == "line" and it[1].startswith("set_option"):
                header = False
            else:
                continue
        if it[0] == "line":
            l = it[1]
            m = re.match(r"^section\b\s*(\S*)", l)
            if m:
                stack.append([m.group(1), len(out), False])
                out.append(it)
                continue
            m = re.match(r"^end\b\s*(\S*)", l)
            if m and stack and m.group(1) == stack[-1][0]:
                name, start, has = stack.pop()
                if has:
                    out.append(it)
                    if stack:
                        stack[-1][2] = True
                else:
                    del out[start:]
                continue
            out.append(it)
        else:
            _, name, priv, ls = it
            if name in chain:
                out.append(it)
                if stack:
                    stack[-1][2] = True
            elif priv:
                out.append(it)
    return out


def close_text(c, ops, e):
    app = "(%s (A.runLog G).2 (A.runLog G).1.1)" % ops
    return ("CloseIn (LinearMap.range (encLin (Q := (%s).Q) (%s).pts (%s).form)) %s (exX %s) (exU %s) →"
            % (c, c, c, e, app, app))


def close_params(txt, fixed=None):
    """read C, ops, e off the theorem's hdzero binder, else off its extractor `epxE C mk pos ops …`"""
    if fixed:
        return fixed
    m = re.search(r"\(hdzero :", txt)
    if m:
        seg = txt[m.start():balanced(txt, m.start())]
        k = seg.find(".decodeIn (")
        assert k > 0
        # C: the balanced group or name just before `.decodeIn`
        j = k
        if seg[j - 1] == ")":
            d, j = 0, j - 1
            while True:
                if seg[j] == ")":
                    d += 1
                elif seg[j] == "(":
                    d -= 1
                    if d == 0:
                        break
                j -= 1
            c = seg[j:k]
        else:
            mm = re.search(r"(\S+)$", seg[:k])
            c = mm.group(1)
            c = c.lstrip("(")
        a = k + len(".decodeIn ")
        b = balanced(seg, a)
        app = seg[a + 1:b - 1]
        suffix = " (A.runLog G).2 (A.runLog G).1.1"
        assert app.endswith(suffix), app[-80:]
        ops = app[:-len(suffix)]
        if not (ops.startswith("(") and balanced(ops, 0) == len(ops)) and " " in ops:
            ops = "(" + ops + ")"
        e = re.match(r"\s*(\S+?)\)", seg[b:]).group(1)
        return c, ops, e
    k = txt.find("epxE ")
    assert k > 0
    a = args_after(txt, k + 5, 4)
    return a[0], a[3], "768"


def rename(txt):
    for n in sorted(CHAIN, key=len, reverse=True):
        txt = re.sub(r"(?<![A-Za-z0-9_'.])((?:[A-Za-z0-9_]+\.)*)" + re.escape(n) + NAME_END,
                     lambda m: m.group(1) + n + SUF, txt)
    return txt


def insert_close(txt, name, fixed=None):
    """insert the closeness hypothesis into the IN-C cover premise of one theorem's text"""
    m = re.search(r"\((hdin[A-Za-z]*) :", txt)
    assert m, name
    a, b = m.start(), balanced(txt, m.start())
    seg = txt[a:b]
    k = min(x for x in [seg.find("¬ InOkP"), seg.find("¬ InSat"), seg.find("¬ InOk ")] if x >= 0)
    ls = seg.rfind("\n", 0, k)
    indent = re.match(r"\s*", seg[ls + 1:]).group(0)
    c, ops, e = close_params(txt, fixed)
    seg = seg[:k] + close_text(c, ops, e) + "\n" + indent + seg[k:]
    return txt[:a] + seg + txt[b:], (c, ops, e)


def move_ops(txt):
    """R2': where the binder `ops` follows the IN-C cover premise, move it (its type reads only the commitment) to just
    before that premise, so the inserted closeness can name it"""
    a = txt.find("\n    (hdin")
    o = txt.find("\n    (ops : ")
    if a < 0 or o < 0 or o < a:
        return txt
    e = balanced(txt, o + 5)
    assert txt[e] == "\n", txt[o:e + 20]
    blk = txt[o:e]
    txt = txt[:o] + txt[e:]
    return txt[:a] + blk + txt[a:]


# the positional calls whose argument order R2' changes (callee: the moved `ops`)
POS_FIX = [
    ("halive hdin hdblk hdout pos hplane mk ops hE", "halive ops hdin hdblk hdout pos hplane mk hE"),
    ("halive hdin\n    hdblk hdout pos (fun _ => rfl) mk ops hE", "halive ops hdin\n    hdblk hdout pos (fun _ => rfl) mk hE"),
    ("halive hdin hdblk hdout mk ops hE", "halive ops hdin hdblk hdout mk hE"),
]


def sub1(txt, old, new, name):
    assert txt.count(old) == 1, (name, old[:60], txt.count(old))
    return txt.replace(old, new)


BOTTOM_BODY = """  := by
  have hnpo : ∀ K' ∈ Ko, K'.np = R.blks.length + 2 := by
    intro K' hK'
    obtain ⟨p, hp, rfl⟩ := List.mem_map.mp (hKo K' hK')
    exact hnp p hp
  have h3x := rc_cover3_someP R (classifyProtocolUP R Lq V P Cin h64 hr hon.base e) E tr Ko hnpo
    ((kindsFK Ks ++ X).map Prod.fst) (fun K' hK' => kindsFK_mem Ks X K' (hKo K' hK'))
    (fun A G => Ex A G ∨ ¬ CloseIn (LinearMap.range (encLin (Q := Cin.Q) Cin.pts Cin.form)) e
      (exX (ops (A.runLog G).2 (A.runLog G).1.1)) (exU (ops (A.runLog G).2 (A.runLog G).1.1)))
    (fun A G hv hx => halive A G hv (fun h => hx (Or.inl h)))
    (fun A G hv hx hn => hdin A G hv (fun h => hx (Or.inl h)) (not_not.mp (fun h => hx (Or.inr h))) hn)
    (fun A G k hk hv hx hn => hdblk A G k hk hv (fun h => hx (Or.inl h)) hn)
    (fun A G hv hx hn => hdout A G hv (fun h => hx (Or.inl h)) hn)
  have hzero : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUP R Lq V P Cin h64 hr hon.base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ Ex A G →
      ¬ (∀ k i, (¬ ∃ t, pos t = (k, i)) → (Cin.decodeIn (ops (A.runLog G).2 (A.runLog G).1.1) e).1 (Cin.place k) i = 0)
        → ∃ K' ∈ (kindsFK Ks ++ X).map Prod.fst, K'.Ev A G :=
    fun A G hv hx hz => kindEv_of_dm_ord Ko (R.blks.length + 2) hnpo ((kindsFK Ks ++ X).map Prod.fst)
      (fun K' hK' => kindsFK_mem Ks X K' (hKo K' hK')) A G (halive A G hv hx) (hdzero A G hv hx hz)
  exact classifyUP_productionReadyL_ep_target_range R Lq V P Cin h64 hr hon U hbij site kOf δOf E O e he hN20
    (kindsFK Ks ++ X) Ex εx hEx
    (fun A G hv hbad => (h3x A G hv hbad).elim
      (fun h => h.elim Or.inl (fun hnc => (Classical.em (Ex A G)).elim Or.inl (fun hx => Or.inr (hX A G hv hx hnc))))
      Or.inr)
    pos hplane mk ops hE hops hcan hX hzero cx
    (fun p hp => (List.mem_append.mp hp).elim (kindsFK_ℓ Ks hℓ p) (hℓX p))
    (fun q p hp => (List.mem_append.mp hp).elim (kindsFK_lin Ks hlin q p) (hlinX q p)) hx hbud hzk
"""

HDR = """/-
D63 lane L63 (2026-11-18), ruling L63-11: the twin of `{src}.lean` with the IN-C cover premise stated UNDER THE INPUT
ENDPOINT'S CLOSENESS (`CloseIn … (exX ops) (exU ops)` inserted before its `¬ InOkP` / `¬ InSat`), theorems renamed
`…_cl`. GENERATED by `results/zk60_lean_l63_20261116/l63_mk_cl.py`; the source is not edited.{extra}

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
"""


def gen_file(src, mod, names, prev, extra_doc=""):
    lines = open(F + src + ".lean").read().split("\n")
    items = keep_sections(blocks(lines), set(names) | ({TOP_OLD} if src == TOP_SRC else set()))
    out = []
    params = {}
    for it in items:
        if it[0] == "line":
            out.append(it[1])
            continue
        _, name, priv, ls = it
        txt = "\n".join(ls)
        if name not in names:
            out.append(txt)
            continue
        if src == TOP_SRC:
            txt = top_text(txt)
        else:
            fixed = ("CinB", "OpsB", "768") if src == "RunStgShieldTopBx" else None
            txt = move_ops(txt)
            txt, params[name] = insert_close(txt, name, fixed)
            for old, new in POS_FIX:
                if old in txt:
                    txt = sub1(txt, old, new, name)
            if name == "sshC_productionReadyL_epP_blkIO":
                txt = sub1(txt, "(hdinS := fun A G hv hb hn => hdinX A G hv hb (fun h =>",
                           "(hdinS := fun A G hv hb hc hn => hdinX A G hv hb hc (fun h =>", name)
            if name == "sjC_productionReadyL_epP_exec_alive":
                txt = sub1(txt, "(hdin := fun A G hv' hx' hn' =>", "(hdin := fun A G hv' hx' hc' hn' =>", name)
                txt = sub1(txt, "(hdinS A G hv' hx' hn')", "(hdinS A G hv' hx' hc' hn')", name)
            if name == "rc_productionReadyL_runChainP_some_range":
                k = txt.find("  := by\n") if "  := by\n" in txt else txt.find(" := by\n")
                assert k > 0
                txt = txt[:k].rstrip() + "\n" + BOTTOM_BODY.rstrip("\n")
            txt = rename(txt)
        out.append(txt)
    imports = ["import ZK60Formal." + src] + (["import ZK60Formal." + prev] if prev else [])
    body = "\n".join(out).rstrip("\n") + "\n"
    # the copied private declarations renamed too (no name declared twice by the lane, no clash with the sources)
    for it in items:
        if it[0] == "decl" and it[2] and it[1] not in CHAIN:
            body = re.sub(r"(?<![A-Za-z0-9_'.])" + re.escape(it[1]) + NAME_END, it[1] + SUF, body)
    body = re.sub(r"\n{3,}", "\n\n", body)
    return HDR.format(src=src, extra=extra_doc) + "\n".join(imports) + "\n\n" + body, params


AGREE = """
/-- **The closeness of the extracted matrix gives the joint agreement set** (`agree_of_closeIn` at the columns that
open, `exX`, and the extracted matrix, `exU`). -/
theorem cl_agree {T St Salt : Type} (C : PlaneCommit T St Salt)
    (ops : Fin C.N → Option (MerkleOpening Dig Dig (ColR C.R)))
    (hcan : ∀ j o, ops j = some o → ∀ a ∈ o.col.1, a.Canon) (e : ℕ)
    (hcl : CloseIn (LinearMap.range (encLin (Q := C.Q) C.pts C.form)) e (exX ops) (exU ops)) :
    ∃ (Mg : Fin C.R → Fin C.n → GF) (Pd : Fin C.R → Fin C.Q → GF) (S : Finset (Fin C.N)),
      C.N ≤ S.card + e ∧ ∀ j ∈ S, ∃ o, ops j = some o ∧ o.col = C.colOf Mg Pd j :=
  C.agree_of_closeIn ops hcan (exX ops) (exX_spec ops) (exU ops) (exU_spec ops) e hcl

"""

DISCHARGE = """(hdinX := fun A G hv hb hc hnot => by
      have hon : ∃ (Mg : Fin 6 → Fin (2 ^ 8) → GF) (Pd : Fin 6 → Fin 256 → GF) (S : Finset (Fin (2 ^ 11))),
          2 ^ 11 ≤ S.card + 768 ∧ ∀ j ∈ S, ∃ o, (OpsB) (A.runLog G).2 (A.runLog G).1.1 j = some o
            ∧ o.col = (CinB).colOf Mg Pd j :=
        cl_agree (CinB) ((OpsB) (A.runLog G).2 (A.runLog G).1.1)
          (ex_hcan tag Lq (le64_of_le20 hL20) key DomB HsB HLB abRdIn 11 6 (A.runLog G).2 (A.runLog G).1.1) 768 hc
      exact shd_hdinX_blk (hR := hR) (site := site) (kOf := kOf) (δOf := δOf) (O := O) (E0b := E0b)
        (hV131072 := hV131072) (hEmb := hEmb) A G hv hb hon hnot)"""


def top_text(txt):
    txt = txt.replace("theorem " + TOP_OLD + "\n", "theorem " + TOP_NEW + "\n")
    assert ("theorem " + TOP_NEW) in txt
    a = txt.find("    (hdinX :")
    b = balanced(txt, txt.find("(", a))
    assert txt[b] == "\n"
    txt = txt[:a] + txt[b + 1:]
    txt = sub1(txt, "exact sshC_productionReadyL_epP_blkIOv\n", "exact sshC_productionReadyL_epP_blkIOv_cl\n", TOP_NEW)
    txt = sub1(txt, "(hdinX := hdinX)", DISCHARGE, TOP_NEW)
    # the docstring
    k = txt.find("/--")
    e = txt.find("-/", k)
    doc = ("/-- **THE CONCRETE TOP WITH `hdinX` DISCHARGED** (D63 lane L63, ruling L63-11): "
           "`sshC_productionReadyL_epP_blkIOl`'s\nstatement with the premise `hdinX` REMOVED. Through the chain with the "
           "IN-C cover premise stated under the input\nendpoint's closeness (`…_cl`, the joint cover reordered at "
           "`rc_productionReadyL_runChainP_some_range_cl`: not close\ngoes to the column test's kinds by the gate's "
           "own `hX`), the premise there is `shd_hdinX_blk` with `cl_agree`\n(`agree_of_closeIn`). Every other "
           "binder and the conclusion are blkIOl's, term for term. Remaining lane premises:\n`hLO_stg`, `hdoutC`; plus "
           "`hEmb` (L63-8, interim) and `hV131072` (L63-7). ")
    txt = txt[:k] + doc + txt[e:]
    return txt


def main():
    outs = {}
    prev = None
    for src, mod, names in PLAN:
        txt, params = gen_file(src, mod, names, prev)
        outs[mod] = txt
        prev = mod
    txt, _ = gen_file(TOP_SRC, TOP_MOD, [TOP_OLD], prev,
                      "\n\n* `cl_agree`: `agree_of_closeIn` at `exX`, `exU`.\n* **`" + TOP_NEW + "`**: blkIOl's "
                      "statement without `hdinX` (the new top).")
    # cl_agree goes before the section of the top
    k = txt.find("\nsection ")
    txt = txt[:k] + "\n" + AGREE.rstrip("\n") + "\n" + txt[k:]
    outs[TOP_MOD] = txt
    bad = 0
    for mod, t in outs.items():
        p = F + mod + ".lean"
        if CHECK:
            try:
                cur = open(p).read()
            except FileNotFoundError:
                cur = None
            if cur != t:
                print("DIFFERS", mod)
                bad += 1
        else:
            open(p, "w").write(t)
            print("wrote", mod, t.count("\n"), "lines")
    if CHECK:
        print("l63_mk_cl.py --check:", "OK" if bad == 0 else "%d differ" % bad)
        sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
