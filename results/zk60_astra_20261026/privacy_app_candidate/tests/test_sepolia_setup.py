"""Deployment-envelope recovery, fee/funding refusals, and immutable patching."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import sys

APP = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(APP))

try:
    from eth_account import Account
    from eth_account.typed_transactions import TypedTransaction
    from hexbytes import HexBytes
except ImportError:
    Account = None

from proven_media.publisher import PublishError
from proven_media.base_sepolia import CHAIN_ID, keccak

spec = importlib.util.spec_from_file_location('sepolia_setup', APP/'tools/sepolia_setup.py')
setup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(setup)


class FakeDeployRPC:
    def __init__(self):
        self.balance=10**18;self.sent=[];self.receipt=None;self.visible=False;self.lost=False
        self.code=b'';self.chain=CHAIN_ID;self.checks=0

    def check_chain(self):
        self.checks+=1
        if self.chain!=CHAIN_ID:raise PublishError('wrong chain')

    def call(self,method,params):
        if method=='eth_getBlockByNumber':return {'baseFeePerGas':'0x64','hash':'0x'+'aa'*32}
        if method=='eth_maxPriorityFeePerGas':return '0x64'
        if method=='eth_estimateGas':return hex(100000)
        if method=='eth_getBalance':return hex(self.balance)
        if method=='eth_getTransactionCount':return '0x0'
        if method=='eth_getTransactionReceipt':return self.receipt
        if method=='eth_getTransactionByHash':return {'hash':params[0]} if self.visible else None
        if method=='eth_sendRawTransaction':
            self.sent.append(params[0]);self.visible=True
            if self.lost:raise PublishError('simulated response lost after acceptance')
            return '0x'+keccak(bytes.fromhex(params[0][2:])).hex()
        if method=='eth_blockNumber':return '0x66'
        if method=='eth_getCode':return '0x'+self.code.hex()
        raise AssertionError(method)


@unittest.skipIf(Account is None,'optional requirements-testnet.txt not installed')
class SepoliaSetupTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.dir=Path(self.tmp.name);self.account=Account.create();self.rpc=FakeDeployRPC()
        # A tiny fixture exercises envelope handling; it does not simulate EVM execution.
        self.artifact={'schema':'proven-media/testnet-anchor-contract/1','compiler':'0.8.28',
            'source_sha256':hashlib.sha256((APP/'contracts/ProvenMediaAnchor.sol').read_bytes()).hexdigest(),
            'evm':{'bytecode':{'object':'60006000'},'deployedBytecode':{
                'object':'ff'+'00'*32+'ee','immutableReferences':{'1':[{'start':1,'length':32}]}}}}

    def deploy(self):return setup.deploy(self.rpc,self.account,self.artifact,self.dir,'https://example.test')

    def test_deployment_loss_recovery_and_runtime_pin(self):
        self.rpc.lost=True
        with self.assertRaises(PublishError):self.deploy()
        pending=json.loads((self.dir/'deployment.pending.json').read_text())
        raw=HexBytes(pending['raw_transaction']);tx=TypedTransaction.from_bytes(raw).as_dict()
        self.assertEqual(tx['chainId'],CHAIN_ID);self.assertEqual(tx['value'],0)
        self.assertEqual(bytes(tx['data']),bytes.fromhex('60006000'))
        self.assertEqual(Account.recover_transaction(raw),self.account.address)
        self.assertEqual(self.deploy()['status'],'pending')
        self.assertEqual(len(self.rpc.sent),1)
        self.rpc.receipt={'status':'0x1','blockNumber':'0x64','blockHash':'0x'+'aa'*32,
            'transactionHash':pending['tx_hash'],'contractAddress':'0x'+'11'*20}
        self.rpc.code=setup.expected_runtime(self.artifact,self.account.address)
        result=self.deploy();self.assertEqual(result['status'],'deployed')
        config=json.loads((self.dir/'sepolia.json').read_text())
        self.assertEqual(config['runtime_code_hash'],keccak(self.rpc.code).hex())
        self.assertGreaterEqual(self.rpc.checks,4)

    def test_no_funds_wrong_chain_and_modified_source_refuse(self):
        self.rpc.balance=0
        with self.assertRaisesRegex(PublishError,'free Base Sepolia test ETH'):self.deploy()
        self.assertFalse((self.dir/'deployment.pending.json').exists())
        self.rpc.chain=1
        with self.assertRaisesRegex(PublishError,'wrong chain'):self.deploy()
        self.artifact['source_sha256']='00'*32
        with self.assertRaisesRegex(PublishError,'pinned contract'):self.deploy()
        self.assertEqual(self.rpc.sent,[])

    def test_immutable_offsets_and_runtime_mismatch(self):
        result=setup.expected_runtime(self.artifact,self.account.address)
        self.assertEqual(result,b'\xff'+bytes(12)+bytes.fromhex(self.account.address[2:])+b'\xee')
        self.deploy()
        pending=json.loads((self.dir/'deployment.pending.json').read_text())
        self.rpc.receipt={'status':'0x1','blockNumber':'0x64','blockHash':'0x'+'aa'*32,
            'transactionHash':pending['tx_hash'],'contractAddress':'0x'+'11'*20}
        self.rpc.code=b'wrong'
        with self.assertRaisesRegex(PublishError,'runtime or receipt'):self.deploy()
        self.assertFalse((self.dir/'sepolia.json').exists())


if __name__=='__main__':unittest.main()
