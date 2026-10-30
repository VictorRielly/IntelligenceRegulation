"""Run original guard tests against a private candidate; no live paths used."""
from pathlib import Path
import datetime
import importlib.machinery
import importlib.util
import json
import os
import subprocess
import sys
import types
import unittest

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
CANDIDATE=HERE/'zk60_resource_guard.py.candidate'

def main():
    suite_name=sys.argv[1]
    if suite_name=='existing':
        source=ROOT/'tests/test_zk60_resource_guard.py'
        text=source.read_text()
        old='self.meminfo.write_text(meminfo_text(swap_used_gib=2))'
        new='self.meminfo.write_text(meminfo_text(avail_gib=2.5, swap_used_gib=2))'
        assert text.count(old)==1
        text=text.replace(old,new)
        module=types.ModuleType('guard_s8_existing_tests');module.__file__=str(source)
        exec(compile(text,str(source),'exec'),module.__dict__)
        loader=importlib.machinery.SourceFileLoader('guard_s8_existing_candidate',str(CANDIDATE))
        spec=importlib.util.spec_from_loader(loader.name,loader)
        guard=importlib.util.module_from_spec(spec);loader.exec_module(guard)
        module.GUARD=CANDIDATE;module.guard=guard
    elif suite_name=='s3':
        os.environ['GUARD_FIX_NEW']=str(CANDIDATE)
        source=ROOT/'tests/test_zk60_guard_fix.py'
        spec=importlib.util.spec_from_file_location('guard_s8_s3_regressions',source)
        module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    else:raise ValueError(suite_name)
    result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromModule(module))
    report={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'suite':suite_name,
            'tests':result.testsRun,'failures':len(result.failures),'errors':len(result.errors),
            'skipped':len(result.skipped),'scope':'private candidate only; live guard unchanged'}
    (HERE/f'{suite_name}.json').write_text(json.dumps(report,indent=2)+'\n')
    (HERE/f'{suite_name}.done').write_text('0\n' if result.wasSuccessful() else '1\n')
    sys.exit(0 if result.wasSuccessful() else 1)

if __name__=='__main__':main()
