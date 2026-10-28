"""S2 word-domain amendment recorded by Claude at2026-10-26 19:50Z.

The eight widened norm/attention words admit [-32768,32767]. Scores and
int8 weights retain symmetric bounds. Adjust only the evaluator recorder's
range/clamp for these exact site names/classes; every arithmetic operation is
the pinned fp_lib implementation. Float-calibration source files stay intact.
Native R13 acceptance and its endpoint/no-wrap audit remain separate work.
"""
import calibration_port as P

AMENDED_SITES=frozenset(('norm_a quotient/remainder','norm_m quotient/remainder','Q','K','V','QR','KR','O'))
DOMAIN={'sites':sorted(AMENDED_SITES),'range':[-32768,32767],
        'authority':'ZK60_SOL_ASTRA_TODOS_20261026 coordinator note2026-10-26T19:50:00Z; fidelity REPORT.md amendment',
        'unchanged':'int8 score and weights symmetric; pinned S2_BUILD_SPEC.json bytes unchanged',
        'scope':'numerical evaluator only; native proof, no-wrap and privacy acceptance are separate'}

class S2RecPos(P.fl.RecPos):
    def check(self,site,v,lo,hi,seq0,clamp,extra_bad=None):
        if site in AMENDED_SITES and (lo,hi)==(-32767,32767):lo=-32768
        return super().check(site,v,lo,hi,seq0,clamp,extra_bad=extra_bad)
