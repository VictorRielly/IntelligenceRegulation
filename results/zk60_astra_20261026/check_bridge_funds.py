"""Read-only inspection of the known throwaway wallet on both testnets."""
from datetime import datetime, timezone
import json
from pathlib import Path
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'apps/proven-media'))
from proven_media.base_sepolia import BaseSepoliaRPC, keccak
from proven_media.publisher import PublishError


class PacedRPC(BaseSepoliaRPC):
    def call(self, method, params):
        for attempt in range(5):
            time.sleep(1 if attempt == 0 else 2 ** attempt)
            try:
                return super().call(method, params)
            except PublishError as error:
                if getattr(error.__cause__, 'code', None) != 429 or attempt == 4:
                    raise

ADDRESS = '0x775E8A2D741446d74E3f5a02244D1241eceB187d'
BRIDGE = '0xfd0Bf71F60660E2f608ed56e1659C450eB113120'
ENDPOINTS = [(11155111, 'https://eth-sepolia.api.onfinality.io/public'),
             (84532, 'https://base-sepolia.api.onfinality.io/public')]
rows = []
for expected, url in ENDPOINTS:
    rpc = PacedRPC(url, '00'*20, '00'*32, ADDRESS)
    actual = int(rpc.call('eth_chainId', []), 16)
    if actual != expected:
        raise ValueError('unexpected RPC chain')
    row = {'chain_id': actual, 'address': ADDRESS, 'balance_wei': int(rpc.call('eth_getBalance', [ADDRESS, 'latest']), 16),
           'pending_nonce': int(rpc.call('eth_getTransactionCount', [ADDRESS, 'pending']), 16)}
    if expected == 11155111:
        code = bytes.fromhex(rpc.call('eth_getCode', [BRIDGE, 'latest']).removeprefix('0x'))
        row.update(bridge=BRIDGE, bridge_code_bytes=len(code), bridge_code_keccak=keccak(code).hex())
        row['canary_gas_estimate'] = int(rpc.call('eth_estimateGas', [{'from': ADDRESS, 'to': BRIDGE,
            'value': hex(10**16), 'data': '0x'}]), 16)
        row['latest_base_fee_per_gas'] = int(rpc.call('eth_getBlockByNumber', ['latest', False])['baseFeePerGas'], 16)
    rows.append(row)
result = {'at': datetime.now(timezone.utc).isoformat(), 'networks': rows,
          'bridge_documentation': 'https://docs.base.org/specifications/reference/base-contracts'}
out = Path(__file__).resolve().parent / 'testnet/bridge_funds_status.json'
out.write_text(json.dumps(result, indent=2)+'\n')
print(json.dumps(result))
