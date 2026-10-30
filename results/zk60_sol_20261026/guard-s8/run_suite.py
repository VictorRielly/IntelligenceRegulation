"""Run one installed guard/consumer suite and retain exact execution counts."""
import argparse
import datetime
import json
from pathlib import Path
import sys
import time
import unittest

p=argparse.ArgumentParser();p.add_argument("pattern");p.add_argument("--expected",type=int);p.add_argument("--out",required=True)
a=p.parse_args();root=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(root))
suite=unittest.defaultTestLoader.discover(str(root/"tests"),pattern=a.pattern)
start=time.monotonic();result=unittest.TextTestRunner(verbosity=2).run(suite)
record={"utc":datetime.datetime.now(datetime.timezone.utc).isoformat(),"pattern":a.pattern,"tests":result.testsRun,
    "failures":len(result.failures),"errors":len(result.errors),"skipped":result.skipped,
    "seconds":time.monotonic()-start,"expected":a.expected}
ok=result.wasSuccessful() and not result.skipped and result.testsRun>0 and (a.expected is None or result.testsRun==a.expected)
record["accepted"]=ok
Path(a.out).write_text(json.dumps(record,indent=2)+"\n")
sys.exit(0 if ok else 1)
