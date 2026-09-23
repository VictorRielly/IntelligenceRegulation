"""Does the gate's H-pair (_check_pair_schedule) refuse overlapping / odd-offset / unused pairs?"""
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, "/home/victor/wt-zk60-jointview/scripts")
from zk60_native_jv_pcs import RoleView  # noqa: E402
from zk60_native_jv_field import F2_ZERO  # noqa: E402

ONE, U = (1, 0), (0, 1)


class Fake:
    def __init__(self, rws):
        self.rws = rws
        self.facts = {}
        self.findings = []

    def fail(self, m):
        self.findings.append(m)


rows = 10  # data 0..3, reserved 4..7, prox 8,9
other = list(range(4, 10))
prox = [8, 9]


def claim(pairs):
    rw = [F2_ZERO] * rows
    rw[0] = ONE
    for r, c in pairs:
        rw[r] = c
    return rw


cases = {
    "honest (4,5),(6,7)": [claim([(4, ONE), (5, U)]), claim([(6, ONE), (7, U)])],
    "overlap (4,5),(5,6); row 7 unused, row 5 shared": [claim([(4, ONE), (5, U)]), claim([(5, ONE), (6, U)])],
    "odd offset (5,6),(6,7)?": [claim([(5, ONE), (6, U)])],
    "one claim, rows 6,7 unused": [claim([(4, ONE), (5, U)])],
}
for k, rws in cases.items():
    f = Fake(rws)
    ok = RoleView._check_pair_schedule(f, list(range(4)), other, prox, [])
    print(f"{k:50s} H-pair={ok} used={f.facts['reserved_pairs_used']} findings={f.findings}")
