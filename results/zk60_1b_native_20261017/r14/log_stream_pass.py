"""Publish terminal component evidence in the authorized Sol coordination log."""
from datetime import datetime, timezone
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
now = datetime.now(timezone.utc).isoformat()
note = f'''
- {now}: R14 native stream gates PASS 8/0, source 57c204b6 / 281 files, binary 36667fc2: DD/non-DD two-block serialized honest runs with distinct CN, fresh-process verification, canonical scalar corruption rejected, complete narrow-boundary forgeries rejected at native physical slot30 round0. DD segment bytes [34107208,35649320], non-DD [33872200,35414312], exact codec counter matches; receipts +~6% T128, A/H words -24..25%. Full-test times include setup/controls; no prove-time claim yet. R13 matched baseline attempt1 failed before proof: fixture expected incoming stage1 boundary index while accepted R13 asks outgoing block0. Failed source/binary/log retained; test-only index fixed, source 222a775b, guarded build2 original73724. R14 C7g repeated-root check and prove-only clocks installed after all stream jobs terminal; new source 067ba462 / 281 files held for guarded build4 original48930. Token round16b accepted-with-fixes coordinator note acknowledged; app/token lane untouched. R13/F1 frozen bytes unchanged; no R14 trained-model/privacy/profile activation; T256 desktop-only, S6 parked.
'''
path = ROOT / 'docs/zkmatrix-poc/ZK60_SOL_ASTRA_TODOS_20261026.md'
text = path.read_text()
marker = '\n## Astra — model calibration, benchmarks and the app\n'
assert text.count(marker) == 1
path.write_text(text.replace(marker, '\n' + note + marker, 1))
path = ROOT / 'results/zk60_sol_20261026/PROGRESS.md'
path.write_text(path.read_text() + note)
path = HERE / 'CURRENT_DEV_STATE.json'
state = json.loads(path.read_text())
state['live_tool_sessions'] = [
    {'session': 73724, 'task': 'matched R13 build2 source222a775b'},
    {'session': 48930, 'task': 'R14 root audit/timing build4 source067ba462'},
]
path.write_text(json.dumps(state, indent=2) + '\n')
print('Published Sol component update')
