#!/usr/bin/env python3
"""D63 lane L42 (2026-11-10): the negative control of l42_statements_check.py. Writes two single changes of the amended
Statements.lean, each of which the check must refuse:
  l42_mut1_Statements.lean: an OLD definition edited (the instance-leak zero-knowledge bound doubled);
  l42_mut2_Statements.lean: a line inserted INTO an old declaration (a new field of `Protocol`).

usage: python3 -I l42_statements_mutate.py <amended Statements.lean> <out dir>
"""
import sys

src, out = sys.argv[1], sys.argv[2]
text = open(src, encoding="utf-8").read()
old1 = "      realProb M P W (q + R) Dist ≤ idealProb M P S W (q + R) Dist + εzk q R\n"
assert text.count(old1) == 1
open(f"{out}/l42_mut1_Statements.lean", "w", encoding="utf-8").write(
    text.replace(old1, old1.replace("+ εzk q R", "+ εzk q R + εzk q R")))
old2 = "  Leak : Type\n"
assert text.count(old2) == 1
open(f"{out}/l42_mut2_Statements.lean", "w", encoding="utf-8").write(text.replace(old2, old2 + "  extra : Unit\n"))
print("wrote 2 mutants")
