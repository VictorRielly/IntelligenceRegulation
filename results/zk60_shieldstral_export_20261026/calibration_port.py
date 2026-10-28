"""One import boundary for the isolated Shieldstral calibration implementation."""
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
VENDOR = HERE/'vendor'
sys.path.insert(0, str(VENDOR))
for name in ('tlcalib', 'b3calib', 'b3_ladder', 'fp_lib'):
    if name in sys.modules and Path(sys.modules[name].__file__).resolve().parent != VENDOR:
        raise RuntimeError(f'{name} already imported from another model; use a fresh process')
import tlcalib as tc
import b3calib as b3
import b3_ladder as bl
import fp_lib as fl

assert tc.GEO == b3.GEO == fl.GEO
assert (tc.GEO.d, tc.GEO.H * tc.GEO.dh, tc.GEO.f) == (3072, 4096, 9216)
