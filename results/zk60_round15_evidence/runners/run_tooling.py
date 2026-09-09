import json,sys,unittest
from pathlib import Path
root=Path("/home/victor/IntelligenceRegulation")
sys.path.insert(0,str(root/"tests"))
suite=unittest.TestSuite()
for pattern in ["test_hashline*.py", "test_zk60*.py"]:
    suite.addTests(unittest.defaultTestLoader.discover(str(root/"tests"),pattern=pattern))
def flatten(s):
    for x in s:
        if isinstance(x,unittest.TestSuite): yield from flatten(x)
        else: yield x.id()
ids=list(flatten(suite))
result=unittest.TextTestRunner(verbosity=2).run(suite)
record={"test_ids":ids,"ran":result.testsRun,"failures":[t.id() for t,_ in result.failures],"errors":[t.id() for t,_ in result.errors],"skipped":[t.id() for t,_ in result.skipped]}
Path(sys.argv[1] if len(sys.argv)>1 else "/tmp/zk60-round15/final/tooling_result.json").write_text(json.dumps(record,indent=2)+"\n")
sys.exit(0 if result.wasSuccessful() and not result.skipped else 1)
