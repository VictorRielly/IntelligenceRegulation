import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from urllib.error import HTTPError

from eth_account import Account
from eth_account.typed_transactions import TypedTransaction
from hexbytes import HexBytes

from proven_media import sepolia_bridge as B
from proven_media.publisher import PublishError


class PacedRPCTests(unittest.TestCase):
    def error(self, status):
        error = PublishError('RPC failed')
        error.__cause__ = HTTPError('https://example.invalid', status, 'error', {}, None)
        return error

    def test_rate_limit_recovers_with_the_same_request(self):
        with patch.object(B.time, 'sleep'), patch.object(B.BaseSepoliaRPC, 'call',
                side_effect=[self.error(429), '0x14a34']) as call:
            B.TestnetRPC('https://example.invalid', B.L2_CHAIN).check_chain()
        self.assertEqual(call.call_count, 2)
        self.assertTrue(all(c.args == ('eth_chainId', []) for c in call.call_args_list))

    def test_permanent_error_is_not_retried(self):
        with patch.object(B.time, 'sleep'), patch.object(B.BaseSepoliaRPC, 'call',
                side_effect=self.error(403)) as call:
            with self.assertRaises(PublishError):
                B.TestnetRPC('https://example.invalid', B.L2_CHAIN).check_chain()
        self.assertEqual(call.call_count, 1)


class FakeRPC:
    def __init__(self, chain):
        self.chain = self.expected_chain = chain
        self.balance = 505 * 10**15 if chain == B.L1_CHAIN else 0
        self.nonce = 0
        self.sent = []
        self.known = set()
        self.receipt = None
        self.lose_response = False
        self.calls = []
        self.pending_path = None
        self.wrong_counterpart = False

    def check_chain(self):
        B.require(self.chain == self.expected_chain, 'RPC chain differs')

    def call(self, method, params):
        self.calls.append(method)
        if method == 'eth_getCode': return '0x0102'
        if method == 'eth_call':
            address = B.MESSENGER if params[0]['data'] == '0x'+B.keccak(b'messenger()')[:4].hex() else B.L2_BRIDGE
            return '0x'+(bytes(32) if self.wrong_counterpart else bytes(12)+B.hex_bytes(address,20)).hex()
        if method == 'eth_getBalance': return hex(self.balance)
        if method == 'eth_getTransactionCount': return hex(self.nonce)
        if method == 'eth_maxPriorityFeePerGas': return hex(100_000_000)
        if method == 'eth_estimateGas': return hex(100_000)
        if method == 'eth_blockNumber': return hex(103)
        if method == 'eth_getBlockByNumber': return {'hash':'0x'+'ab'*32, 'baseFeePerGas':hex(100_000_000)}
        if method == 'eth_getTransactionReceipt':
            return self.receipt if self.receipt and self.receipt['transactionHash'] == params[0] else None
        if method == 'eth_getTransactionByHash': return {'hash':params[0]} if params[0] in self.known else None
        if method == 'eth_sendRawTransaction':
            assert self.pending_path.exists(), 'envelope was not persisted before broadcast'
            self.sent.append(params[0])
            tx_hash = '0x'+B.keccak(bytes.fromhex(params[0][2:])).hex()
            self.known.add(tx_hash)
            if self.lose_response:
                self.lose_response = False
                raise PublishError('simulated lost RPC response')
            return tx_hash
        raise AssertionError(method)


class BridgeTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.directory = Path(self.tmp.name)
        self.account = Account.from_key(bytes.fromhex('11'*32))
        for name, value in [('WALLET', self.account.address), ('BRIDGE_CODE_HASH', B.keccak(bytes([1,2])).hex())]:
            patcher = patch.object(B, name, value); patcher.start(); self.addCleanup(patcher.stop)
        self.l1, self.l2 = FakeRPC(B.L1_CHAIN), FakeRPC(B.L2_CHAIN)
        self.l1.pending_path = self.directory/'bridge-canary.pending.json'
        self.bridge = B.SepoliaBridge(self.l1,self.l2,self.directory)

    def mine(self, amount=None):
        plan = json.loads(self.l1.pending_path.read_text())
        value = plan['value_wei'] if amount is None else amount
        topic = '0x'+B.keccak(b'ETHBridgeInitiated(address,address,uint256,bytes)').hex()
        address = '0x'+(bytes(12)+B.hex_bytes(B.WALLET,20)).hex()
        data = '0x'+(value.to_bytes(32,'big')+(64).to_bytes(32,'big')+bytes(32)).hex()
        self.l1.receipt = {'status':'0x1','transactionHash':plan['tx_hash'], 'from':B.WALLET,'to':B.BRIDGE,
            'blockNumber':'0x64','blockHash':'0x'+'ab'*32,
            'logs':[{'address':B.BRIDGE,'topics':[topic,address,address],'data':data}]}
        self.l1.nonce = 1
        return plan

    def test_lost_response_reuses_identical_envelope_without_another_send(self):
        self.l1.lose_response = True
        with self.assertRaisesRegex(PublishError,'lost RPC'):
            self.bridge.run('canary',self.account)
        before = self.l1.pending_path.read_bytes()
        self.assertEqual(self.bridge.run('canary',self.account)['status'],'pending_l1')
        self.assertEqual(len(self.l1.sent),1)
        self.assertEqual(self.l1.pending_path.read_bytes(),before)
        self.assertEqual(self.l1.calls.count('eth_getTransactionCount'),1)
        self.mine(); self.l2.balance = B.AMOUNTS['canary']
        self.assertEqual(self.bridge.run('canary',self.account)['status'],'credited')

    def test_bulk_requires_confirmed_canary_credit(self):
        with self.assertRaisesRegex(PublishError,'canary must complete'):
            self.bridge.run('bulk',self.account)
        self.bridge.run('canary',self.account); self.mine()
        with self.assertRaisesRegex(PublishError,'has not reached'):
            self.bridge.run('bulk',self.account)
        self.assertFalse((self.directory/'bridge-bulk.pending.json').exists())
        self.l2.balance = B.AMOUNTS['canary']
        self.assertEqual(self.bridge.run('canary',self.account)['status'],'credited')
        self.l1.balance -= B.AMOUNTS['canary']
        self.l1.pending_path = self.directory/'bridge-bulk.pending.json'
        self.assertEqual(self.bridge.run('bulk',self.account)['status'],'pending_l1')
        plan = json.loads(self.l1.pending_path.read_text())
        tx = TypedTransaction.from_bytes(HexBytes(plan['raw_transaction'])).as_dict()
        self.assertEqual((tx['nonce'],tx['value']),(1,B.AMOUNTS['bulk']))
        self.assertEqual(len(self.l1.sent),2)

    def test_wrong_chain_or_counterpart_never_signs_or_broadcasts(self):
        self.l1.chain = 1
        with self.assertRaisesRegex(PublishError,'chain differs'):
            self.bridge.run('canary',self.account)
        self.l1.chain = B.L1_CHAIN; self.l1.wrong_counterpart = True
        with self.assertRaisesRegex(PublishError,'counterpart differs'):
            self.bridge.run('canary',self.account)
        self.assertFalse(self.l1.pending_path.exists()); self.assertFalse(self.l1.sent)

    def test_signed_value_tamper_is_rejected_before_send(self):
        self.bridge.run('canary',self.account)
        plan=json.loads(self.l1.pending_path.read_text())
        tx=TypedTransaction.from_bytes(HexBytes(plan['raw_transaction'])).as_dict()
        tx={key:value for key,value in tx.items() if key not in ('v','r','s')}
        tx['value'] += 1
        signed=self.account.sign_transaction(tx)
        plan['raw_transaction']='0x'+signed.raw_transaction.hex();plan['tx_hash']='0x'+signed.hash.hex()
        self.l1.pending_path.write_text(json.dumps(plan))
        with self.assertRaisesRegex(PublishError,'signed envelope'):
            self.bridge.run('canary',self.account)
        self.assertEqual(len(self.l1.sent),1)

    def test_receipt_event_and_actual_credit_are_required(self):
        self.l2.balance = 10**17
        self.bridge.run('canary',self.account); self.mine(amount=1)
        with self.assertRaisesRegex(PublishError,'exact ETH bridge event'):
            self.bridge.run('canary',self.account)
        self.mine()
        self.assertEqual(self.bridge.run('canary',self.account)['status'],'pending_base_credit')
        self.l2.balance += B.AMOUNTS['canary']
        self.assertEqual(self.bridge.run('canary',self.account)['status'],'credited')
        self.l2.balance = 0
        with self.assertRaisesRegex(PublishError,'credit observation differs'):
            self.bridge.run('canary',self.account)

    def test_gas_reserve_is_preserved(self):
        self.l1.balance = B.AMOUNTS['canary'] + B.RESERVE
        with self.assertRaisesRegex(PublishError,'gas reserve'):
            self.bridge.run('canary',self.account)
        self.assertFalse(self.l1.pending_path.exists())

    def test_excessive_gas_estimate_never_creates_an_envelope(self):
        original = self.l1.call
        self.l1.call = lambda method, params: hex(800001) if method == 'eth_estimateGas' else original(method, params)
        with self.assertRaisesRegex(PublishError,'gas estimate exceeds cap'):
            self.bridge.run('canary',self.account)
        self.assertFalse(self.l1.pending_path.exists())


if __name__ == '__main__': unittest.main()
