#!/bin/bash
# Lane A28 (from A27, A26): a list of stream runs in ONE guarded gpu-class job, in the order given (for A/B pairs in
# both orders, list them A B B A). Each run: <tag>|<binary>|<posts file>|<driver flags>|<env, space-separated K=V or ->
# read one per line from the plan file. Every receipt freshly verified unless the flags say --defer-check
# (then verified after, on its own clock).
# usage: runs.sh <job tag> <plan file>
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a6d02411a78ede69c/results/zk60_a28_app_20261107
JOB=$1; PLAN=$2
P=$R/$JOB.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say "start; plan $(basename $PLAN); free disk $(df -g /Users/victorrielly | tail -1 | awk '{print $4}') GiB"
while IFS='|' read -r tag bin posts flags envs; do
  case "$tag" in ''|'#'*) continue ;; esac
  free=$(df -g /Users/victorrielly | tail -1 | awk '{print $4}')
  if [ "$free" -lt 40 ]; then say "STOP: free disk $free GiB under 40"; exit 3; fi
  [ "$envs" = "-" ] && envs=""
  say "run $tag bin $(shasum -a 256 $bin | cut -c1-12) env [$envs] flags [$flags]"
  /usr/bin/env $envs /bin/bash $R/stream.sh $tag $posts --profile r13 --bin $bin $flags > $R/stream_$tag.out 2>&1
  say "$tag rc=$? $(tail -1 $R/stream_$tag.out | cut -c1-600)"
done < $PLAN
say "all done; free disk $(df -g /Users/victorrielly | tail -1 | awk '{print $4}') GiB"
