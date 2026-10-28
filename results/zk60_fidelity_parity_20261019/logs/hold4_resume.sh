#!/bin/bash
# hold #4: the deferred (a)-exact builds exit 3 at start (logs/HOLD2_build_*_dg_aex) and their evaluations fail fast
# on the missing variant, so both lanes go idle after e8_c2_dg. When the token lane's r11_chain.done exists, remove
# the holds and re-append the four jobs (lane X: 8B, lane Y: TinyLlama) under fresh labels.
D=/home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019
until [ -f /home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/logs/r11_chain.done ]; do sleep 30; done
rm -f $D/logs/HOLD2_build_l8_dg_aex $D/logs/HOLD2_build_tl_dg_aex
cat >> $D/logs/jobs_X.txt <<'EOX'
t_c2gpc_y4|3|1|tinyllama|fp_eval.py --export /home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019/exports/tinyllama_dg_rot1_T128 --corpora fineweb:48,wikitext:48 --tag t_c2gpc_y4 --mult-bits q:5,k:5,v:7,o:8,g:6,u:4,d:6 --gate-pc=-5:mc3 --mods y4
t_c2gpc_y8|3|1|tinyllama|fp_eval.py --export /home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019/exports/tinyllama_dg_rot1_T128 --corpora fineweb:48,wikitext:48 --tag t_c2gpc_y8 --mult-bits q:5,k:5,v:7,o:8,g:6,u:4,d:6 --gate-pc=-5:mc3 --mods y8
t_c2gpc_y4fp12|3|1|tinyllama|fp_eval.py --export /home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019/exports/tinyllama_dg_rot1_T128 --corpora fineweb:48,wikitext:48 --tag t_c2gpc_y4fp12 --mult-bits q:5,k:5,v:7,o:8,g:6,u:4,d:6 --gate-pc=-5:mc3 --mods y4,fp12
e8_c2gpc|5|2|llama3-8b|fp_eval.py --export /home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019/exports/llama3_8b_dg_rot1_voc0_T128 --corpora fineweb:48,wikitext:48 --tag e8_c2gpc --mult-bits q:5,k:5,v:7,o:8,g:6,u:4,d:6 --gate-pc=-5:mc3 --pos-chunk 256
e8_c2gpc_y4fp12|5|2|llama3-8b|fp_eval.py --export /home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019/exports/llama3_8b_dg_rot1_voc0_T128 --corpora fineweb:48,wikitext:48 --tag e8_c2gpc_y4fp12 --mult-bits q:5,k:5,v:7,o:8,g:6,u:4,d:6 --gate-pc=-5:mc3 --mods y4,fp12 --pos-chunk 256
e8_c2gpc_y4|5|2|llama3-8b|fp_eval.py --export /home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019/exports/llama3_8b_dg_rot1_voc0_T128 --corpora fineweb:48,wikitext:48 --tag e8_c2gpc_y4 --mult-bits q:5,k:5,v:7,o:8,g:6,u:4,d:6 --gate-pc=-5:mc3 --mods y4 --pos-chunk 256
EOX
sed 's/^build_l8_aex|/build_l8_aex2|/; s/^e8_aex_fh|/e8_aex_fh2|/' $D/logs/_resume_X.txt >> $D/logs/jobs_X.txt
echo "e8_aex_c2gpc_fh|5|2|llama3-8b|fp_eval.py --export /home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019/variants/l8_dg_aex --corpora fineweb:48,wikitext:48 --tag e8_aex_c2gpc_fh --head float --mult-bits q:5,k:5,v:7,o:8,g:6,u:4,d:6 --gate-pc=-5:mc3 --pos-chunk 256" >> $D/logs/jobs_X.txt
cat >> $D/logs/jobs_Y.txt <<'EOY'
t_c2gpc_fp10|3|1|tinyllama|fp_eval.py --export /home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019/exports/tinyllama_dg_rot1_T128 --corpora fineweb:48,wikitext:48 --tag t_c2gpc_fp10 --mult-bits q:5,k:5,v:7,o:8,g:6,u:4,d:6 --gate-pc=-5:mc3 --mods fp10
t_c2gpc_fp11|3|1|tinyllama|fp_eval.py --export /home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019/exports/tinyllama_dg_rot1_T128 --corpora fineweb:48,wikitext:48 --tag t_c2gpc_fp11 --mult-bits q:5,k:5,v:7,o:8,g:6,u:4,d:6 --gate-pc=-5:mc3 --mods fp11
t_c2gpc_fp12|3|1|tinyllama|fp_eval.py --export /home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019/exports/tinyllama_dg_rot1_T128 --corpora fineweb:48,wikitext:48 --tag t_c2gpc_fp12 --mult-bits q:5,k:5,v:7,o:8,g:6,u:4,d:6 --gate-pc=-5:mc3 --mods fp12
t_c2gpc_y4fp12_af|3|1|tinyllama|fp_eval.py --export /home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019/exports/tinyllama_dg_rot1_T128 --corpora fineweb:48,wikitext:48 --tag t_c2gpc_y4fp12_af --mult-bits q:5,k:5,v:7,o:8,g:6,u:4,d:6 --gate-pc=-5:mc3 --mods y4,fp12 --relax attn_core
EOY
sed 's/^build_tl_aex|/build_tl_aex2|/; s/^var_aex|/var_aex2|/' $D/logs/_resume_Y.txt >> $D/logs/jobs_Y.txt
echo "aex_c2gpc|3|1|tinyllama|fp_eval.py --export /home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019/variants/tl_dg_aex --corpora fineweb:48,wikitext:48 --tag aex_c2gpc --mult-bits q:5,k:5,v:7,o:8,g:6,u:4,d:6 --gate-pc=-5:mc3" >> $D/logs/jobs_Y.txt
echo "[$(date -u +%H:%M:%SZ)] r11_chain.done present: hold #4 over; activation-width, c2 and (a)-exact jobs queued"
