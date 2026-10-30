from pathlib import Path
p=Path(__file__).resolve().parent
src=p.parent/"working-tree/hashline/src/private_block/accuracy_act.rs"
s=src.read_text();marker="#[cfg(test)]\nmod tests {"
assert s.count(marker)==1
s=s.replace(marker,(p/"query_helpers.rs").read_text()+marker)
at=s.rfind("\n}");s=s[:at]+"\n"+(p/"query_tests.rs").read_text()+s[at:]
(p/"accuracy_act.query.candidate.rs").write_text(s)
