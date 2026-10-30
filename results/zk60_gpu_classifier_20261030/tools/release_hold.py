#!/usr/bin/env python3
"""GPU classifier lane: remove the lane's HOLD file once Astra's durable demo is completely finished: no process of
its pipeline (wait_turn.astra_pipeline) and no astra* / pm-* guard job (wait_turn.blocking), on 3 checks in a row
30 s apart. Logs to the queue log; gives up (leaving HOLD) after --max-secs. Never signals anything.
usage: release_hold.py QUEUE_LOG [--max-secs S]"""
import os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import wait_turn as w
log = sys.argv[1]
max_s = float(sys.argv[sys.argv.index('--max-secs') + 1]) if '--max-secs' in sys.argv else 4 * 3600
hold = w.T + '/HOLD'
t0, clear, last = time.time(), 0, 0.0
def note(m):
    with open(log, 'a') as f:
        f.write(time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()) + ' release_hold: ' + m + '\n')
note('watching (HOLD stays until Astra demo processes and astra*/pm-* guard jobs are gone, 3 checks in a row)')
while time.time() - t0 < max_s:
    why = w.astra_pipeline() + w.blocking(0)
    clear = clear + 1 if not why else 0
    if clear >= 3:
        if os.path.exists(hold):
            os.remove(hold)
        note('Astra demo finished: HOLD removed')
        sys.exit(0)
    if why and time.time() - last > 300:
        note('waiting: ' + '; '.join(why))
        last = time.time()
    time.sleep(30)
note('gave up after max-secs; HOLD left in place')
sys.exit(1)
