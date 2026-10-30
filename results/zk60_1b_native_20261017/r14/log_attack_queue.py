from datetime import datetime,timezone
import json
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
now=datetime.now(timezone.utc).isoformat()
note=f'''
- {now}: Resumed best-effort continuation. R14 source5f8147cc /282 files component build5 PASS16/0+11ignored (183s,2.05GiB watchdog). Six DD/non-DD complete-receipt attack cases installed: per-piece Q rounding, wrong local AO c2, one-piece norm, wrong omitted source bit, missing public lift gate, local-reset ACT group IDs; group test first requires both honest contexts to verify. Prover-only faults / existing cfg(test) host-miss bypass leave verifier, native constraints, M and PCS enabled. Attack driver original44198 withdrew via original tool Ctrl-C (terminal130, no heavy leaf) to tighten lean admission: no light job >1GiB beside >=3GiB proof. First command/log retained under checkpoints/attack-launcher-withdrawn-1; no guard/foreign job signalled. Corrected attempt2 original34732 waits outside heavy lock behind astra-gpu-benchmark-l05 and gate20 light1.3GiB. Actual S2 L00 T128 19-oracle-site parity/native proof/fresh/corrupt tests prepared in independent actual-working-tree, source087016a3 /283 files; compile original77357 queued,2.6GiB. Main queued attack source unchanged. All R13/F1/frozen artifacts and token/app sources untouched. Matched report remains35.05/33.85s R14 vs49.23/48.66s R13, -25% peak/+6%receipt (n1 public synthetic sharedhost). Remaining native capture/rank/NL1/joint-view adapter, generic dense, old compatibility, experimental CLI, exact actual whole-run bounds/freeze/D24/privacy still owed. No R14 production activation or privacy acceptance. After the current GPU leaf and privacy-analysis batch drain, a bounded native gap would let the six mandatory split attacks and actual-weight gates advance; no preemption requested.
'''
path=ROOT/'docs/zkmatrix-poc/ZK60_SOL_ASTRA_TODOS_20261026.md';text=path.read_text();marker='\n## Astra — model calibration, benchmarks and the app\n';assert text.count(marker)==1
path.write_text(text.replace(marker,'\n'+note+marker,1));path=ROOT/'results/zk60_sol_20261026/PROGRESS.md';path.write_text(path.read_text()+note)
path=HERE/'CURRENT_DEV_STATE.json';state=json.loads(path.read_text());state.update(utc=now,
    phase='Build5 PASS16/0; strict lean-memory attack driver waiting; isolated actual branch compiling next',
    live_tool_sessions=[{'session':34732,'task':'DD/nonDD6malicious receipts, main source5f8147cc'},
        {'session':77357,'task':'actual S2 isolated branch build source087016a3'}],source_edits_held=True,
    next='Poll original34732/77357, never restart from stale state. No main/actual source edits while queued/running. Diagnose any test failure with source/binary checkpoint and new attempt labels.')
path.write_text(json.dumps(state,indent=2)+'\n');print('Published queued native acceptance state')
