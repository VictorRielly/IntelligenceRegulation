"""Resumable, fixed-amount funding of the generated Base Sepolia test wallet.

Only the authorized0.01 and0.45 test-ETH deposits are supported. The signed
envelope is saved before broadcast; retries never create a replacement deposit.
"""
import json
from pathlib import Path
import time

from .base_sepolia import BaseSepoliaRPC, hex_bytes, keccak
from .publisher import PublishError
from .testnet_publisher import atomic_json

WALLET = '0x775E8A2D741446d74E3f5a02244D1241eceB187d'
BRIDGE = '0xfd0Bf71F60660E2f608ed56e1659C450eB113120'
MESSENGER = '0xC34855F4De64F1840e5686e64278da901e261f20'
L2_BRIDGE = '0x4200000000000000000000000000000000000010'
BRIDGE_CODE_HASH = 'c7b46fc754979c0fd29ec7105b045a5705d172da4364b24a72e42e586906056f'
L1_CHAIN, L2_CHAIN = 11155111, 84532
AMOUNTS = {'canary': 10**16, 'bulk': 45 * 10**16}
RESERVE = 4 * 10**16
# Oct28 live bridge estimate666742 gas; with25% margin this needs833428.
# The independent balance check still preserves0.04 test ETH after maximum fees.
MAX_GAS, MAX_FEE = 1_000_000, 10_000_000_000


def require(condition, reason):
    if not condition:
        raise PublishError('testnet bridge: ' + reason)


class TestnetRPC(BaseSepoliaRPC):
    def __init__(self, url, chain, publisher_address=None):
        require(chain in (L1_CHAIN, L2_CHAIN), 'unsupported chain')
        super().__init__(url, '00'*20, '00'*32, publisher_address or WALLET)
        self.expected_chain = chain

    def check_chain(self):
        require(int(self.call('eth_chainId', []), 16) == self.expected_chain, 'RPC chain differs')

    def call(self, method, params):
        for attempt in range(5):
            time.sleep(1 if attempt == 0 else 2**attempt)
            try:
                return super().call(method, params)
            except PublishError as error:
                if getattr(error.__cause__, 'code', None) != 429 or attempt == 4:
                    raise


class SepoliaBridge:
    def __init__(self, l1, l2, directory):
        self.l1, self.l2, self.directory = l1, l2, Path(directory)

    def check_networks(self):
        self.l1.check_chain()
        self.l2.check_chain()
        code = bytes.fromhex(self.l1.call('eth_getCode', [BRIDGE, 'latest']).removeprefix('0x'))
        require(keccak(code).hex() == BRIDGE_CODE_HASH, 'bridge proxy bytecode changed')
        for method, expected in [('messenger()', MESSENGER), ('OTHER_BRIDGE()', L2_BRIDGE)]:
            data = '0x' + keccak(method.encode())[:4].hex()
            result = self.l1.call('eth_call', [{'to': BRIDGE, 'data': data}, 'latest'])
            require(hex_bytes(result, 32) == bytes(12) + hex_bytes(expected, 20), 'bridge counterpart differs')

    def _prepare(self, stage, account):
        value = AMOUNTS[stage]
        base = int(self.l1.call('eth_getBlockByNumber', ['latest', False])['baseFeePerGas'], 16)
        tip = min(int(self.l1.call('eth_maxPriorityFeePerGas', []), 16), 200_000_000)
        fee = 2 * base + tip
        require(0 < fee <= MAX_FEE, 'fee exceeds10gwei cap')
        estimate = int(self.l1.call('eth_estimateGas', [{'from': WALLET, 'to': BRIDGE, 'value': hex(value), 'data': '0x'}]), 16)
        gas = (estimate * 125 + 99) // 100
        require(21_000 <= gas <= MAX_GAS, 'gas estimate exceeds cap')
        balance = int(self.l1.call('eth_getBalance', [WALLET, 'latest']), 16)
        require(balance >= value + gas * fee + RESERVE, 'deposit would consume the0.04 test-ETH gas reserve')
        height = self.l2.call('eth_blockNumber', [])
        baseline = int(self.l2.call('eth_getBalance', [WALLET, height]), 16)
        nonce = int(self.l1.call('eth_getTransactionCount', [WALLET, 'pending']), 16)
        if stage == 'bulk':
            canary = json.loads((self.directory / 'bridge-canary.complete.json').read_text())
            require(nonce == canary['nonce'] + 1, 'unexpected nonce after canary')
        else:
            require(nonce == 0, 'unexpected initial throwaway-wallet nonce')
        tx = {'chainId': L1_CHAIN, 'nonce': nonce, 'to': BRIDGE, 'value': value, 'data': b'',
              'gas': gas, 'maxFeePerGas': fee, 'maxPriorityFeePerGas': tip, 'type': 2}
        signed = account.sign_transaction(tx)
        return {'schema': 'pm-sepolia-bridge-envelope/1', 'stage': stage, 'value_wei': value,
                'raw_transaction': '0x' + signed.raw_transaction.hex(), 'tx_hash': '0x' + signed.hash.hex(),
                'base_start_block': int(height, 16), 'base_start_balance_wei': baseline}

    def _decode(self, stage, plan):
        from eth_account import Account
        from eth_account.typed_transactions import TypedTransaction
        from hexbytes import HexBytes
        raw = HexBytes(plan['raw_transaction'])
        tx = TypedTransaction.from_bytes(raw).as_dict()
        require(plan['schema'] == 'pm-sepolia-bridge-envelope/1' and plan['stage'] == stage
                and plan['value_wei'] == AMOUNTS[stage], 'persisted deposit stage differs')
        require(tx['chainId'] == L1_CHAIN and bytes(tx['to']) == hex_bytes(BRIDGE, 20)
                and tx['value'] == AMOUNTS[stage] and bytes(tx['data']) == b''
                and 21_000 <= tx['gas'] <= MAX_GAS and 0 < tx['maxFeePerGas'] <= MAX_FEE
                and 0 <= tx['maxPriorityFeePerGas'] <= tx['maxFeePerGas']
                and Account.recover_transaction(raw).lower() == WALLET.lower()
                and '0x' + keccak(raw).hex() == plan['tx_hash'], 'signed envelope violates fixed testnet deposit')
        require(type(plan['base_start_block']) is int and plan['base_start_block'] >= 0
                and type(plan['base_start_balance_wei']) is int and plan['base_start_balance_wei'] >= 0,
                'invalid Base observation')
        return tx

    def _reconcile(self, stage, plan, allow_send):
        tx = self._decode(stage, plan)
        tx_hash = plan['tx_hash']
        receipt = self.l1.call('eth_getTransactionReceipt', [tx_hash])
        if receipt is None:
            if allow_send and self.l1.call('eth_getTransactionByHash', [tx_hash]) is None:
                self.check_networks()
                got = self.l1.call('eth_sendRawTransaction', [plan['raw_transaction']])
                require(got.lower() == tx_hash, 'RPC returned another transaction hash')
            return {'status': 'pending_l1', 'stage': stage, 'tx_hash': tx_hash}
        require(int(receipt['status'], 16) == 1, 'deposit reverted; envelope retained')
        require(receipt['transactionHash'].lower() == tx_hash and receipt['from'].lower() == WALLET.lower()
                and receipt['to'].lower() == BRIDGE.lower(), 'deposit receipt identity differs')
        block = self.l1.call('eth_getBlockByNumber', [receipt['blockNumber'], False])
        if block['hash'].lower() != receipt['blockHash'].lower():
            return {'status': 'pending_l1', 'stage': stage, 'tx_hash': tx_hash, 'reason': 'reorg'}
        confirmations = int(self.l1.call('eth_blockNumber', []), 16) - int(receipt['blockNumber'], 16) + 1
        if confirmations < 3:
            return {'status': 'pending_l1', 'stage': stage, 'tx_hash': tx_hash, 'confirmations': confirmations}
        topic = '0x' + keccak(b'ETHBridgeInitiated(address,address,uint256,bytes)').hex()
        address_topic = '0x' + (bytes(12) + hex_bytes(WALLET, 20)).hex()
        data = '0x' + (AMOUNTS[stage].to_bytes(32, 'big') + (64).to_bytes(32, 'big') + bytes(32)).hex()
        events = [log for log in receipt['logs'] if not log.get('removed', False)
                  and log['address'].lower() == BRIDGE.lower()
                  and [t.lower() for t in log['topics']] == [topic, address_topic, address_topic]
                  and log['data'].lower() == data]
        require(len(events) == 1, 'missing or ambiguous exact ETH bridge event')
        complete_path = self.directory / f'bridge-{stage}.complete.json'
        if complete_path.exists():
            old = json.loads(complete_path.read_text())
            require(old['status'] == 'credited' and old['tx_hash'] == tx_hash and old['value_wei'] == AMOUNTS[stage]
                    and old['nonce'] == tx['nonce'] and old['l1_block_hash'].lower() == block['hash'].lower(),
                    'completion record differs')
            saved = self.l2.call('eth_getBlockByNumber', [hex(old['base_credit_block']), False])
            require(saved['hash'].lower() == old['base_credit_block_hash'].lower(), 'Base credit block reorganized')
            credited = int(self.l2.call('eth_getBalance', [WALLET, hex(old['base_credit_block'])]), 16)
            require(credited == old['base_balance_wei'] and credited >= plan['base_start_balance_wei'] + AMOUNTS[stage],
                    'saved Base credit observation differs')
            return old
        height = self.l2.call('eth_blockNumber', [])
        balance = int(self.l2.call('eth_getBalance', [WALLET, height]), 16)
        if balance < plan['base_start_balance_wei'] + AMOUNTS[stage]:
            return {'status': 'pending_base_credit', 'stage': stage, 'tx_hash': tx_hash,
                    'base_balance_wei': balance, 'l1_confirmations': confirmations}
        credit_block = self.l2.call('eth_getBlockByNumber', [height, False])
        result = {'status': 'credited', 'stage': stage, 'tx_hash': tx_hash, 'nonce': tx['nonce'],
                  'value_wei': AMOUNTS[stage], 'l1_block': int(receipt['blockNumber'], 16),
                  'l1_block_hash': block['hash'], 'l1_confirmations': confirmations,
                  'base_credit_block': int(height, 16), 'base_credit_block_hash': credit_block['hash'],
                  'base_balance_wei': balance, 'address': WALLET,
                  'note': 'L1 canonical receipt and bridge event; Base account balance observed through public RPC.'}
        atomic_json(complete_path, result)
        return result

    def run(self, stage, account):
        require(stage in AMOUNTS and account.address.lower() == WALLET.lower(), 'unexpected stage or signing wallet')
        self.check_networks()
        if stage == 'bulk':
            canary_path = self.directory / 'bridge-canary.pending.json'
            require(canary_path.exists(), 'canary must complete before bulk deposit')
            check = self._reconcile('canary', json.loads(canary_path.read_text()), False)
            require(check['status'] == 'credited', 'canary has not reached Base Sepolia')
        path = self.directory / f'bridge-{stage}.pending.json'
        if path.exists():
            plan = json.loads(path.read_text())
        else:
            plan = self._prepare(stage, account)
            atomic_json(path, plan)
        return self._reconcile(stage, plan, True)
