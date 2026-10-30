#!/usr/bin/env python3
"""Prepare a throwaway wallet and deploy ONLY the pinned Base Sepolia anchor.

key: create a 0600 throwaway file; status: read chain/balance; deploy: sign once,
persist before send, resume the same envelope, and write config only after the
expected runtime is confirmed. Free test ETH must be supplied by a faucet.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from proven_media.base_sepolia import (CHAIN_ID, create_throwaway_key,
                                     read_throwaway_key, keccak)
from proven_media.publisher import PublishError
from proven_media.sepolia_bridge import TestnetRPC
from proven_media.testnet_publisher import atomic_json
from proven_media import config
from proven_media.storage_policy import durable_path

APP = Path(__file__).resolve().parents[1]


def expected_runtime(artifact, address):
    deployed = artifact['evm']['deployedBytecode']
    code = bytearray.fromhex(deployed['object'])
    refs = deployed['immutableReferences']
    if len(refs) != 1:
        raise PublishError('expected exactly the publisher immutable in compiled runtime')
    value = bytes(12) + bytes.fromhex(address.removeprefix('0x'))
    for ref in next(iter(refs.values())):
        if ref['length'] != 32:
            raise PublishError('unexpected immutable width')
        code[ref['start']:ref['start'] + 32] = value
    return bytes(code)


def deploy(rpc, account, artifact, directory, rpc_url):
    from eth_account import Account
    from eth_account.typed_transactions import TypedTransaction
    from hexbytes import HexBytes
    pending = directory / 'deployment.pending.json'
    config = directory / 'sepolia.json'
    source = (APP/'contracts/ProvenMediaAnchor.sol').read_bytes()
    if (artifact['schema'] != 'proven-media/testnet-anchor-contract/1' or artifact['compiler'] != '0.8.28'
            or artifact['source_sha256'] != hashlib.sha256(source).hexdigest()):
        raise PublishError('compiled artifact does not match the pinned contract source/compiler')
    creation = bytes.fromhex(artifact['evm']['bytecode']['object'])
    runtime = expected_runtime(artifact, account.address)
    rpc.check_chain()
    if config.exists():
        raise PublishError('deployment already configured; use status or the app')
    if pending.exists():
        plan = json.loads(pending.read_text())
    else:
        base = int(rpc.call('eth_getBlockByNumber', ['latest', False])['baseFeePerGas'], 16)
        tip = min(int(rpc.call('eth_maxPriorityFeePerGas', []), 16), 200_000_000)
        fee = 2 * base + tip
        if fee > 2_000_000_000:
            raise PublishError('testnet fee above 2 gwei cap')
        estimated = int(rpc.call('eth_estimateGas', [{'from': account.address,
                          'data': '0x' + creation.hex(), 'value': '0x0'}]), 16)
        gas = (estimated * 125 + 99) // 100
        if gas > 500_000:
            raise PublishError('deployment estimate above 500000 gas cap')
        balance = int(rpc.call('eth_getBalance', [account.address, 'latest']), 16)
        if balance < gas * fee:
            raise PublishError('throwaway address needs free Base Sepolia test ETH from a faucet')
        tx = {'chainId': CHAIN_ID, 'nonce': int(rpc.call('eth_getTransactionCount', [account.address, 'pending']), 16),
              'value': 0, 'data': creation, 'gas': gas, 'maxFeePerGas': fee, 'maxPriorityFeePerGas': tip, 'type': 2}
        signed = account.sign_transaction(tx)
        plan = {'raw_transaction': '0x' + signed.raw_transaction.hex(),
                'tx_hash': '0x' + signed.hash.hex(), 'source_sha256': artifact['source_sha256']}
        atomic_json(pending, plan)
    raw = HexBytes(plan['raw_transaction'])
    tx = TypedTransaction.from_bytes(raw).as_dict()
    tx_hash = '0x' + keccak(raw).hex()
    if (tx['chainId'] != CHAIN_ID or tx.get('to') not in (None, b'') or tx['value'] != 0
            or bytes(tx['data']) != creation or tx['gas'] > 500_000 or tx['maxFeePerGas'] > 2_000_000_000
            or Account.recover_transaction(raw) != account.address or tx_hash != plan['tx_hash']):
        raise PublishError('persisted deployment envelope differs from the pinned deployment')
    receipt = rpc.call('eth_getTransactionReceipt', [tx_hash])
    if receipt is None:
        if rpc.call('eth_getTransactionByHash', [tx_hash]) is None:
            rpc.check_chain()
            if rpc.call('eth_sendRawTransaction', [plan['raw_transaction']]).lower() != tx_hash:
                raise PublishError('RPC returned another deployment transaction hash')
        return {'status': 'pending', 'tx_hash': tx_hash, 'next': 'rerun deploy to check confirmation'}
    if int(receipt['status'], 16) != 1:
        raise PublishError('deployment reverted; retained envelope will not be replaced automatically')
    block = rpc.call('eth_getBlockByNumber', [receipt['blockNumber'], False])
    if block['hash'].lower() != receipt['blockHash'].lower():
        return {'status': 'pending', 'tx_hash': tx_hash, 'reason': 'receipt block is not canonical'}
    confirmations = int(rpc.call('eth_blockNumber', []), 16) - int(receipt['blockNumber'], 16) + 1
    if confirmations < 3:
        return {'status': 'pending', 'tx_hash': tx_hash, 'confirmations': confirmations}
    address = receipt['contractAddress']
    actual = bytes.fromhex(rpc.call('eth_getCode', [address, 'latest']).removeprefix('0x'))
    if actual != runtime or receipt['transactionHash'].lower() != tx_hash:
        raise PublishError('deployed runtime or receipt differs from expected contract')
    cfg = {'schema': 'proven-media/base-sepolia/1', 'chain_id': CHAIN_ID,
           'rpc_url': rpc_url, 'contract': address, 'runtime_code_hash': keccak(runtime).hex(),
           'publisher_address': account.address, 'key_file': 'throwaway.sepolia-key.json',
           'confirmations': 3, 'deployment_tx': tx_hash, 'source_sha256': artifact['source_sha256']}
    atomic_json(config, cfg)
    return {'status': 'deployed', 'config': str(config), 'contract': address, 'tx_hash': tx_hash}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('action', choices=['key', 'status', 'deploy'])
    ap.add_argument('--private-dir', type=Path, default=config.PRIVATE_DIR/'testnet')
    ap.add_argument('--rpc-url', default='https://sepolia.base.org')
    ap.add_argument('--artifact', type=Path)
    a = ap.parse_args()
    try:
        private = durable_path(a.private_dir, 'testnet private directory')
    except ValueError as exc:
        raise PublishError(str(exc)) from exc
    if private.is_relative_to(config.REPO.resolve()):
        raise PublishError('testnet private directory must be outside the repository')
    if not a.private_dir.exists():
        a.private_dir.mkdir(mode=0o700, parents=True)
    if a.private_dir.is_symlink() or a.private_dir.stat().st_mode & 0o077:
        raise PublishError('testnet private directory must have mode 0700 and be a real directory')
    key = a.private_dir/'throwaway.sepolia-key.json'
    if a.action == 'key':
        address = create_throwaway_key(key)
        print(json.dumps({'chain_id': CHAIN_ID, 'address': address, 'key_file': str(key)}))
        return
    account = read_throwaway_key(key)
    rpc = TestnetRPC(a.rpc_url, CHAIN_ID, account.address)
    rpc.check_chain()
    if a.action == 'status':
        print(json.dumps({'chain_id': CHAIN_ID, 'address': account.address,
            'balance_wei': int(rpc.call('eth_getBalance', [account.address, 'latest']), 16),
            'config_exists': (a.private_dir/'sepolia.json').exists()}))
    elif a.artifact is None:
        raise PublishError('--artifact is required to deploy')
    else:
        print(json.dumps(deploy(rpc, account, json.loads(a.artifact.read_text()), a.private_dir, a.rpc_url)))


if __name__ == '__main__':
    try:
        main()
    except PublishError as e:
        diagnostic = {'status': 'refused', 'reason': str(e)}
        if e.__cause__ is not None:
            # Types/status codes diagnose connectivity without exposing URLs or credentials.
            diagnostic['cause_type'] = type(e.__cause__).__name__
            if isinstance(getattr(e.__cause__, 'code', None), int):
                diagnostic['http_status'] = e.__cause__.code
        print(json.dumps(diagnostic))
        raise SystemExit(1)
