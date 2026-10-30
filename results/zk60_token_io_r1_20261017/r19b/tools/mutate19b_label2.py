#!/usr/bin/env python3
"""Token round 19b: ONE extra mutant, after-tests-label-2, written after the chain's after-tests-label (13:17) was killed
by its named test (the label scan FAILED, exit 101, compiled) but with the scan reporting the label as `, b`, not
`r19b-planted-label`: the scan's line extractor takes the first `b"` after the word `absorb`, and the planted
`("absorb", b"...")` has one inside `absorb"` itself (round 18's label-plant had the same shape, which is why its named
reason was only "classify_batch_plan.rs absorbs"). This variant plants the label so that the extractor reads it exactly:
`const r19b_absorb_plant: &[u8] = b"r19b-planted-label";` after derive.rs's tests module.

usage: mutate19b_label2.py apply|revert|describe after-tests-label-2
(mutate19b.py's apply / revert, loaded as a module, with this one mutant added; mutate19b.py itself is not edited while
the chain that calls it runs.)
"""
import importlib.util, sys

spec = importlib.util.spec_from_file_location("mutate19b", "/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r19b/tools/mutate19b.py")
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
m.MUTANTS = {"after-tests-label-2": [("append", m.DERIVE,
    "\n// MUTANT after-tests-label-2 (token round 19b): a literal absorb label after the tests module\n"
    "#[allow(dead_code, non_upper_case_globals)]\n"
    "const r19b_absorb_plant: &[u8] = b\"r19b-planted-label\";\n")]}
if __name__ == "__main__":
    m.main()
