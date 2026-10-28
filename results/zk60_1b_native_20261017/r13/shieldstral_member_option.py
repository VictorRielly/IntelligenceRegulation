#!/usr/bin/env python3
"""COUNTED contingency, not an enabled registry member or fidelity result."""
import hashlib
import json
import math
from pathlib import Path
import struct

HERE = Path(__file__).resolve().parent
candidate = HERE / 'reference-next'
candidate.mkdir(exist_ok=True)
table = []
for index in range(4096):
    x = (index - 2048) / 16
    word = math.floor((x / (1 + math.exp(-x))) * 256 + .5)
    assert -32767 <= word <= 32767
    table.append(word)
payload = struct.pack('<4096h', *table)
path = candidate / 'silu_0_-8.candidate.bin'
path.write_bytes(payload)
report = dict(scope='COUNTED contingency only; not a registered member, model proof or measured fidelity result',
    member=[0, -8], input_bits=12, input_step=1/16, input_range=[-128, 127.9375],
    raw_output_range=[min(table), max(table)], output_step=1/256,
    raw_table_bytes=len(payload), table_sha256=hashlib.sha256(payload).hexdigest(),
    saturated_outputs=0, selected_only_if='Astra confirms actual integer refusal and the coordinator selects this profile-specific member',
    group_cost='One 4096-entry table when used. Keep <=4 active groups at T128; a fifth group does not fit a 2^14 Tab row and is not enabled by this proposal.',
    committed_cost='No additional committed plane/helper/claim when the active group count stays <=4 and tables fit the existing Tab row; table generation/hash work may increase.',
    scaling_class=dict(max_out_delta=5, min_out_delta=-5, max_coefficient=1 << 16,
                       conservative_scaled_table_abs=32767 * (1 << 16), storage='int64, signed32 magnitude class'),
    obligations=['Bind a separate allowed-member registry to Shieldstral profiles; TinyLlama/8B reject the extension.',
                 'Update group/derived-table validation beyond the current exponent4..15 class where needed.',
                 'Recount all affected no-wrap feeds with coefficient<=2^16 before use.',
                 'Use the full calibration set to select/merge at most four active groups.',
                 'Do not clip an out-of-range gate into the table.'])
(HERE / 'shieldstral_member_option.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
