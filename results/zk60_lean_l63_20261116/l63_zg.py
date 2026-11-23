#!/usr/bin/env python3
"""D63 lane L63 (2026-11-22, leg 21): ruling L63-15, the chain GENERIC in the zero-knowledge error function.

A helper, loaded by path (importlib) from the generators l63_mk_cl.py, l63_mk_lo.py, l63_mk_oc.py, l63_mk_ef.py and
l63_mk_topl.py (they run under `python3 -I`, so no sibling import). It is not run on its own.

`apply(text, name, subs)` rewrites ONE theorem `name` of a generated file's text into two:
  1. `name_zg`, GENERIC: the binder `O : ClassifyOpenP … (refErr RunK.kinds)` is stated at an implicit
     `{εzk : ℕ → ℕ → ℝ≥0∞}` (inserted just before `O`), and ONE premise is added just after `O`:
       (hzkB : ∀ q R', q ≤ 2 ^ 64 → R' ≤ 2 ^ 64 → εzk q R' ≤ εzkTarget q R')
     Its proof is the old proof with the literal replaced by `εzk` and the substitutions `subs` (each must occur exactly
     once): the call of the previous theorem of the chain goes to its `_zg` version with `(hzkB := hzkB)`, or, at the
     bottom, `(hzk := shdP_hzk)` becomes `(hzk := hzkB)`. Its lead (comment, `include … in`, docstring) is the old
     one, the docstring extended by one sentence.
  2. `name` itself, with its statement UNCHANGED (the same text), proved as the instance
       name_zg (εzk := refErr RunK.kinds) (hzkB := shdP_hzk) (every explicit binder by name)
     with the old `include … in` line and a short docstring.
"""
import re

LIT = "(ZK60.ZKHonest.refErr ZK60.ZKCount.RunK.kinds)"
SUF = "_zg"
EZK = "    {εzk : ℕ → ℕ → ℝ≥0∞}\n"
HZKB = "    (hzkB : ∀ q R', q ≤ 2 ^ 64 → R' ≤ 2 ^ 64 → εzk q R' ≤ εzkTarget q R')\n"
INST = "(εzk := ZK60.ZKHonest.refErr ZK60.ZKCount.RunK.kinds) (hzkB := shdP_hzk)"
CLOSE = {"(": ")", "{": "}", "[": "]"}


def match(s, i):
    """s[i] is an opening bracket; index just after its partner (only that bracket kind is counted)"""
    o, c, d = s[i], CLOSE[s[i]], 0
    for j in range(i, len(s)):
        if s[j] == o:
            d += 1
        elif s[j] == c:
            d -= 1
            if d == 0:
                return j + 1
    raise ValueError("unbalanced")


def one(txt, pat):
    assert txt.count(pat) == 1, (pat[:80], txt.count(pat))
    return txt.find(pat)


def block(text, name):
    """(a, t, s, b): a = start of the theorem's lead (just after the blank line before it), t = start of
    `theorem name`, s = just after its ` := by` line, b = just after the last line of its proof (a blank line
    follows)"""
    t = one(text, "\ntheorem " + name + "\n") + 1
    a = text.rfind("\n\n", 0, t) + 2
    s = text.index(" := by\n", t) + len(" := by\n")
    b = text.index("\n\n", s) + 1
    assert text[b + 1] not in " \t", (name, text[b:b + 40])
    return a, t, s, b


def group_names(g):
    """the names bound by one parenthesised binder `(a b : T)`"""
    return re.match(r"\(([^:]+?) :", g).group(1).split()


def own_binders(stmt):
    """the explicit binder names of a statement `theorem X\\n    (…) {…} […] … :\\n …`, in order"""
    i = stmt.index("\n") + 1
    names = []
    while True:
        while stmt[i] in " \n":
            i += 1
        if stmt[i] not in CLOSE:
            break
        j = match(stmt, i)
        if stmt[i] == "(":
            names += group_names(stmt[i:j])
        i = j
    assert stmt[i] == ":", stmt[i:i + 40]
    return names


def sec_vars(text, pos):
    """the explicit section variables of the `variable {Hdr Coins : Type} …` block before `pos`"""
    v = text.rfind("\nvariable {Hdr Coins : Type}", 0, pos) + 1
    assert v > 0
    blk = text[v:text.index("\n\n", v)]
    names, i = [], 0
    while i < len(blk):
        if blk[i] == "(":
            j = match(blk, i)
            names += group_names(blk[i:j])
            i = j
        else:
            i += 1
    return names


def generic_stmt(stmt, name, hzkb=True):
    """`theorem name` -> `theorem name_zg`, `{εzk}` before `O`, `O` at `εzk`, then (optionally) `hzkB`"""
    assert stmt.count(LIT) == 1, (name, stmt.count(LIT))
    o = one(stmt, "\n    (O : ClassifyOpenP") + 1
    oe = match(stmt, o + 4)
    assert stmt[oe] == "\n" and LIT in stmt[o:oe]
    g = stmt[:o] + EZK + stmt[o:oe + 1].replace(LIT, "εzk") + (HZKB if hzkb else "") + stmt[oe + 1:]
    head = "theorem " + name + "\n"
    assert g.startswith(head)
    return "theorem " + name + SUF + "\n" + g[len(head):]


def note(name, hzkb=True):
    prem = ("\nwith the one added premise `hzkB` (`εzk q R' ≤ εzkTarget q R'` for `q, R' ≤ 2^64`)" if hzkb
            else "\n(no added premise: the proof reads only `O.inPub`)")
    inst = "`refErr RunK.kinds`, `shdP_hzk`" if hzkb else "`refErr RunK.kinds`"
    return ("\n**Generic in the zero-knowledge error function** (ruling L63-15): the binder `O` at any implicit `εzk`,"
            + prem + ";\n`" + name + "` is its instance at " + inst + ".")


def lead_generic(lead, name, hzkb=True):
    d = lead.rindex("-/")
    return lead[:d].rstrip(" \n") + note(name, hzkb) + " " + lead[d:]


def lead_inst(lead, name, hzkb=True):
    inc = "".join(l + "\n" for l in lead.split("\n") if l.startswith("include "))
    what = "`hzkB := shdP_hzk`" if hzkb else "no premise"
    return (inc + "/-- **`" + name + "` at the reference error function** (ruling L63-15):\n`" + name + SUF
            + "` at `εzk := refErr RunK.kinds`, " + what + "; the statement is unchanged, binder for binder. -/\n")


def wrap(args, per=8):
    return "\n    ".join(" ".join(args[x:x + per]) for x in range(0, len(args), per))


ONLY = "\n\nOnly `propext`, `Classical.choice`, `Quot.sound`.\n-/\n"


def header_note(text, names):
    """one paragraph in the file's header comment naming the generic theorems"""
    k = one(text, ONLY)
    gens = ", ".join("`" + n + SUF + "`" for n in names)
    par = ("\n\nRuling L63-15 (2026-11-22, leg 21; written by `results/zk60_lean_l63_20261116/l63_zg.py`):\n"
           + gens + "\nGENERIC in the zero-knowledge\nerror function (`O` at any implicit `εzk`, one added premise `hzkB`, "
           "the range bound); the old names are their instances\nat `refErr RunK.kinds`, `shdP_hzk`, statements "
           "unchanged.")
    return text[:k] + par + text[k:]


def apply(text, name, subs):
    a, t, s, b = block(text, name)
    lead, stmt, proof = text[a:t], text[t:s], text[s:b]
    assert lead.lstrip().startswith(("/--", "--", "include ")), (name, lead[:60])
    g = generic_stmt(stmt, name)
    gp = proof.replace(LIT, "εzk")
    for old, new in subs:
        assert gp.count(old) == 1, (name, old, gp.count(old))
        gp = gp.replace(old, new)
    assert "shdP_hzk" not in gp and "refErr" not in gp, name
    sv = [v for v in sec_vars(text, t) if v != "E0" or re.search(r"(?<![\w.])E0(?![\w'])", stmt)]
    args = ["(%s := %s)" % (n, n) for n in ["Hdr", "Coins"] + sv + own_binders(stmt)]
    ip = "  exact " + name + SUF + " " + INST + "\n    " + wrap(args) + "\n"
    return (text[:a] + lead_generic(lead, name) + g + gp + "\n" + lead_inst(lead, name) + stmt + ip + text[b:])
