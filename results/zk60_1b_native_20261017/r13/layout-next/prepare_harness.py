"""Small isolated harness; its layout constants are read from native source.

The oracle roles/counts were independently registered before implementation.
No source in working-tree is modified here.
"""
from pathlib import Path
import json
import re

p = Path(__file__).resolve().parent
src = p.parent / "working-tree/hashline/src/private_block"
layout = (src / "layout.rs").read_text()
constants = re.findall(r"pub\(crate\) const (?:A_\w+|N_A|LN_TOY|LS_TOY|LP_TOY|SH_ROPE): (?:usize|u32) = [^;]+;",layout)
stub = "#[derive(Clone,Copy,Debug,PartialEq,Eq)] pub(crate) enum Dom {T,Ht,L,D,Q,Kv,S,F,Tab,Dd}\n"
stub += "#[derive(Clone,Debug)] pub(crate) struct Lk {pub terms:Vec<(usize,i64)>,pub cst:i64}\n"
stub += "\n".join(constants)
(p / "layout_stub.rs").write_text(stub)
cases = json.loads((p.parent / "plane_reference.json").read_text())["cases"]
rows = []
for case in cases:
    for dom,roles in case["domains"].items():
        rows.append("\t".join([case["stack"],str(int(case["dd"])),str(case["sigma_limbs"]),dom,
            ",".join(roles),str(case["u8_lookups_per_position"][dom]),str(case["output_plane"])]))
(p / "roles.tsv").write_text("\n".join(rows)+"\n")
(p / "harness.rs").write_text('''#![allow(dead_code)]
#[path="layout_stub.rs"] mod layout;
#[path="../working-tree/hashline/src/private_block/accuracy_precision.rs"] mod accuracy_precision;
#[path="accuracy_layout.rs"] mod accuracy_layout;
#[path="tests.rs"] mod tests;
''')
