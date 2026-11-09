#!/usr/bin/env python3
"""D63 lane L28 (2026-11-09): write formal/ZK60Formal/LinkW16GlueR13.lean, the R13 instance of the block's knowledge
statement with the openings' premises discharged.

The statement is GENERATED from L23's `block_knowledge_target_r13` (CoverW16R13.lean), to avoid transcription slips:
its openings' premises (`GA` .. `hexec`) are replaced by this lane's (the block copied from the W16R2 theorem in
LinkW16GlueW16T.lean, with R13's numbers), the header length becomes the profile's, the event gets the header's squeeze
count, and the bound gets the endpoint term. The proof is L23's preparation, then this lane's openings part.

usage: python3 -I l28_mk_r13.py <worktree root>
"""
import sys

wt = sys.argv[1]
fd = wt + '/formal/ZK60Formal/'
s = open(fd + 'CoverW16R13.lean').read()
t = open(fd + 'LinkW16GlueW16T.lean').read()

i = s.index("theorem block_knowledge_target_r13")
j = s.index(":= by\n", i)
stmt = s[i:j]
proof_start = j + len(":= by\n")
k = s.index("  exact block_knowledge_target_gen", proof_start)
proof = s[proof_start:k]

# the openings' premises: this lane's, from the W16R2 theorem, at R13's numbers
a = t.index("    -- the openings at W16R2 (lane L28)")
b = t.index("    -- the four relation layers")
opn = t[a:b]
for old, new, n in [
    ("the openings at W16R2 (lane L28)", "the openings at R13 (lane L28)", 1),
    ("(hm70 : pr.mI = 70)", "(hm64 : pr.mI = 64)", 1),
    ("(hPp : P.pcsVerify = pcsField pr.tag rowsOf)", "(hPp : P.pcsVerify = ZK60.Exec.R13.pcsFieldR13 pr.tag rowsOf)", 1),
    ("Link.claimSem U pr.rA 14 280", "Link.claimSem U pr.rA 14 256", 1),
    ("Link.claimSem U pr.rH 14 280", "Link.claimSem U pr.rH 14 256", 1),
    ("(decodeRows (Link.encG (K := K) 15 280) 8052 (Link.UxC pr.tag L (by omega) 15 pr.rA (N := 2 ^ 15)",
     "(decodeRows (Link.encG (K := K) 16 256) 24448 (Link.UxC pr.tag L (by omega) 16 pr.rA (N := 2 ^ 16)", 1),
    ("(decodeRows (Link.encG (K := K) 15 280) 8052 (Link.UxC pr.tag L (by omega) 15 pr.rH (N := 2 ^ 15)",
     "(decodeRows (Link.encG (K := K) 16 256) 24448 (Link.UxC pr.tag L (by omega) 16 pr.rH (N := 2 ^ 16)", 1),
]:
    assert opn.count(old) == n, (old, opn.count(old))
    opn = opn.replace(old, new)
assert "280" not in opn and "8052" not in opn and " 15 " not in opn and "70" not in opn, opn

a = stmt.index("    -- the openings: their good predicates")
b = stmt.index("    -- the four relation layers")
stmt = stmt[:a] + opn + stmt[b:]
assert stmt.count("theorem block_knowledge_target_r13") == 1
stmt = stmt.replace("theorem block_knowledge_target_r13", "theorem block_knowledge_open_r13")
old = "(hdrLen : ℕ) (hh : hdrLen ≤ 2 ^ 19)"
assert stmt.count(old) == 1
stmt = stmt.replace(old, "(pr : Link.OProf P) (hh : pr.hdrLen ≤ 2 ^ 19)")
stmt = stmt.replace(" hdrLen ", " pr.hdrLen ")
assert "hdrLen" not in stmt.replace("pr.hdrLen", "")
old = "BlockAcc key domain P pr.hdrLen G (A.run G) bga rs acc\n        ∧ ¬ ZK60.Block.BlockSat"
assert stmt.count(old) == 1
stmt = stmt.replace(old, "BlockAcc key domain P pr.hdrLen G (A.run G) bga rs acc\n        ∧ Link.sqN (A.run G).1 = pr.hdrSq"
                    " ∧ ¬ ZK60.Block.BlockSat")
assert stmt.rstrip().endswith("≤ εsTarget q"), stmt[-100:]
stmt = stmt.rstrip() + " + εend "
# the doc comment of L23's theorem is replaced by this lane's
d0 = s.rindex("/-- **One R13 rung block's knowledge error", 0, i)
assert s[d0:i].count("-/") == 1

proof = proof.replace(" hdrLen ", " pr.hdrLen ")
assert "hdrLen" not in proof.replace("pr.hdrLen", "")
for old, new in [
    ("3 * 2 ^ (126 - jM) + 2 * (2 ^ (126 - jA) + 2 ^ (126 - jB))",
     "3 * 2 ^ (126 - 106) + 2 * (2 ^ (126 - 110) + 2 ^ (126 - 126))"),
    ("exact r13_budget jM jA jB hjM.1 hjA.1 hjB.1",
     "exact r13_budget 106 110 126 (by norm_num) (by norm_num) (by norm_num)"),
]:
    assert proof.count(old) == 1, old
    proof = proof.replace(old, new)

header = open(wt + '/results/zk60_lean_l28_20261107/l28_r13_header.lean.txt').read()
tail = open(wt + '/results/zk60_lean_l28_20261107/l28_r13_tail.lean.txt').read()
footer = "\nend Open\n\nend ZK60.Exec.Block\n"
text = header + stmt + ":= by\n" + proof + tail + footer
open(fd + 'LinkW16GlueR13.lean', 'w').write(text)
print(len(text.split('\n')), "lines")
