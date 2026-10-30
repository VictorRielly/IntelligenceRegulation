"""Guarded development build and component filter; no proof activation."""
from pathlib import Path
import importlib.util
import sys

root=Path(__file__).resolve().parents[4]
spec=importlib.util.spec_from_file_location('sol_r13_runner',root/'results/zk60_sol_20261026/r13_guard.py')
runner=importlib.util.module_from_spec(spec);spec.loader.exec_module(runner)
name=sys.argv[1]
runner.run(name,'build',2.14,5,[
    '/usr/bin/env','CARGO_PROFILE_RELEASE_LTO=false','CARGO_PROFILE_RELEASE_CODEGEN_UNITS=16',
    'RAYON_NUM_THREADS=2','OPENBLAS_NUM_THREADS=2','/home/victor/.cargo/bin/cargo',
    'test','--release','--offline','--locked','-j2','--manifest-path',
    str(runner.R13/'working-tree/hashline/Cargo.toml'),'--lib','accuracy','--',
    '--test-threads=1','--nocapture'],seconds=900)
