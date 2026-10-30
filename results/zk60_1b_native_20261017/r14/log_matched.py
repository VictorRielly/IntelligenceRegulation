from datetime import datetime, timezone
import json
from pathlib import Path
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
report = json.loads((HERE / 'MATCHED_R13_R14_COMPARISON.json').read_text())
assert len(report['rows']) == 2
note = f'''
- {datetime.now(timezone.utc).isoformat()}: Coordinator10:23 requested matched S4 prove/RSS/bytes: COMPLETE, MATCHED_R13_R14_COMPARISON.json. Native R13/R14 T128 two blocks, exact same public helpers/input/model identity/block digests and distinct layer CN. Non-DD prove49.225 ->35.050s (-28.80%), guard peak7.49 ->5.56GiB (-25.77%), receipt65,381,616 ->69,286,512bytes (+5.97%). DD prove48.657 ->33.845s (-30.44%), peak7.75 ->5.78GiB (-25.42%), receipt65,851,632 ->69,756,528bytes (+5.93%). First full verify1.31 ->1.63s non-DD,1.37 ->1.67s DD. MEASURED n1 shared host public sparse synthetic only; prove clocks exclude initial setup/first witness/endpoints and later controls, include second witness on demand. Native process HWM agrees with guard samples; sandbox watchdog-only, no production/26block performance claim. R14 source067ba462 component PASS16/0+10ignored; C7g root uniqueness implemented and old DD/non-DD frames still verify fresh, canonical corruptions refuse (new replay/timing driver PASS6/0). All own tool sessions terminal. Failed R13 fixture attempt retained and corrected test-only, accepted R13 production source unchanged. Preparing mandated native rounding/global-c2/global-group/one-piece norm receipt tests next. No R14 activation/privacy acceptance; T256 no laptop proof, S6 parked.
'''
path = ROOT / 'docs/zkmatrix-poc/ZK60_SOL_ASTRA_TODOS_20261026.md'
text = path.read_text(); marker = '\n## Astra — model calibration, benchmarks and the app\n'
assert text.count(marker) == 1
path.write_text(text.replace(marker, '\n' + note + marker, 1))
path = ROOT / 'results/zk60_sol_20261026/PROGRESS.md'
path.write_text(path.read_text() + note)
path = HERE / 'CURRENT_DEV_STATE.json'; state = json.loads(path.read_text())
state.update(utc=datetime.now(timezone.utc).isoformat(), phase='Matched timing / root replay PASS6/0; preparing mandated receipt attacks',
    live_tool_sessions=[], live_tool_session=None, source_edits_held=False,
    matched_report='MATCHED_R13_R14_COMPARISON.json',
    next='Stage receipt-level arithmetic/geometry/inner-piece controls; exact19site actual trace parity and generic dense; native capture/rank/NL1, compatibility, trained CLI, bound review/freeze/D24/privacy still owed.')
path.write_text(json.dumps(state, indent=2) + '\n')
print('Published matched comparison')
