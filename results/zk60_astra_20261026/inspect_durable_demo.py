"""Read-only progress from durable markers; never infer death from a stale PID."""
import json
from pathlib import Path
from datetime import datetime,timezone

HERE=Path(__file__).resolve().parent;OUT=HERE/'real_app_demo_2'


def main():
    plan=json.loads((OUT/'plan.json').read_text());private=Path(plan['private_root'])
    result={'at':datetime.now(timezone.utc).isoformat(),'post_id':plan['post_id'],'categories':{}}
    for chunk in plan['plan']:
        category=chunk['category'];index=chunk['index']
        job=private/'jobs'/plan['post_id']/('prove' if index==0 else f'prove-c{index}')
        row={'status':'not launched'}
        if (OUT/(category+'.launch.json')).exists():
            row={'status':'running or queued; marker not yet terminal'}
            if (job/'step.current').exists():row['step']=(job/'step.current').read_text().split()[0]
            if (job/'logs/prove.log').exists():
                events=[]
                for line in (job/'logs/prove.log').read_text().splitlines():
                    try:events.append(json.loads(line))
                    except ValueError:pass
                row['proof_segments_written']=sum(e.get('event')=='segment' for e in events)
            if (job/'logs/prove.guard.json').exists():
                guard=json.loads((job/'logs/prove.guard.json').read_text())
                row['native_prove']={k:guard.get(k) for k in ('exit','child_wall_seconds','peak_rss_gib','enforcement')}
            done=OUT/(category+'.supervisor.done')
            if done.exists():row.update(status='terminal',exit=int(done.read_text()))
            accepted=OUT/(category+'.json')
            if accepted.exists():
                evidence=json.loads(accepted.read_text());record=evidence['record']
                row.update(verdict=record['labels'][category]['value'],work_s=record['timings']['work_s'])
        result['categories'][category]=row
    result['anchored_completion']=(OUT/'complete.json').exists()
    print(json.dumps(result))


if __name__=='__main__':main()
