#!/usr/bin/env bash
# New queue; retained Oct 21 logs/markers are never overwritten.
set -u
LANE=/home/victor/IntelligenceRegulation/results/zk60_shieldstral_prep_20261021
GUARD=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
LOGS=$LANE/logs/astra_20261026
mkdir -p "$LOGS"
# A second launch exits without touching the first launch's completion marker.
exec 9>"$LOGS/queue.lock"
flock -n 9 || exit 73
if [ -e "$LOGS/queue.done" ]; then exit 73; fi
printf '%s\n' "$$" > "$LOGS/queue.pid"
cat /proc/sys/kernel/random/boot_id > "$LOGS/queue.boot_id"
rc=0
trap 'printf "%s\n" "$rc" > "$LOGS/queue.done"' EXIT
for job in openai_mod:cat_violence:0:168:300 openai_mod:cat_hate:0:168:300 \
           toxicchat:mod_hate:200:0:0 toxicchat:mod_sexual:200:0:0 toxicchat:mod_violence:200:0:0 \
           openai_mod:mod_sexual:0:168:300 openai_mod:mod_violence:0:168:300 openai_mod:mod_hate:0:168:300; do
  IFS=: read -r SET TPL LIM MAXCT STRAT <<< "$job"
  SUF=""; EXTRA=()
  if [ "$MAXCT" != 0 ]; then SUF="${SUF}_le${MAXCT}"; EXTRA+=(--max-content-tokens "$MAXCT"); fi
  if [ "$STRAT" != 0 ]; then SUF="${SUF}_strat${STRAT}"; EXTRA+=(--strat-safe "$STRAT"); fi
  STEM=${SET}_${TPL}${SUF}
  for chunk in {1..60}; do
    while [ -e "$LANE/HOLD" ]; do sleep 30; done
    # Prior RSS 0.77–0.84 GiB; 1.1 GiB declaration includes >=25% margin.
    # One light CPU job at a time, with the existing 1.8 GiB cap.
    python3 "$GUARD" run --class light --need-gib 1.1 --cap-gib 1.8 \
      --label "astra-${STEM}-c${chunk}" --wait-secs 14400 --max-secs 2100 \
      --log "$LOGS/$STEM.c$chunk.log" --done "$LOGS/$STEM.c$chunk.done" \
      --result-json "$LOGS/$STEM.c$chunk.guard.json" -- \
      /usr/bin/env OPENBLAS_NUM_THREADS=6 OMP_NUM_THREADS=6 \
      python3 -I "$LANE/tools/bench_run.py" --set "$SET" --template "$TPL" --limit "$LIM" \
      --out "$LANE/bench/$STEM.jsonl" --max-minutes 26 --token-budget 4096 "${EXTRA[@]}"
    rc=$?
    if [ "$rc" -ne 3 ]; then break; fi
  done
  printf '%s\n' "$rc" > "$LOGS/$STEM.done"
  if [ "$rc" -ne 0 ]; then exit "$rc"; fi
done
