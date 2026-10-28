#!/usr/bin/env python3
"""Compile the pinned testnet contract; run through the resource guard (build)."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

APP = Path(__file__).resolve().parents[1]
SOLC = "0.8.28"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', type=Path, required=True)
    ap.add_argument('--npm', default='/home/victor/.nvm/versions/node/v22.22.3/bin/npm')
    ap.add_argument('--cache', default='/tmp/zk60-astra-npm-cache')
    a = ap.parse_args()
    src = (APP/'contracts/ProvenMediaAnchor.sol').read_bytes()
    request = {'language': 'Solidity', 'sources': {'ProvenMediaAnchor.sol': {'content': src.decode()}},
               'settings': {'optimizer': {'enabled': True, 'runs': 200}, 'evmVersion': 'paris',
                            'outputSelection': {'*': {'*': ['abi', 'evm.bytecode.object',
                                'evm.deployedBytecode.object', 'evm.deployedBytecode.immutableReferences']}}}}
    command = [a.npm, 'exec', '--offline', '--cache', a.cache, '--yes', '--package', 'solc@'+SOLC,
               '--', 'solcjs', '--standard-json']
    done = subprocess.run(command, input=json.dumps(request), text=True, capture_output=True, check=True)
    result = json.loads(done.stdout[done.stdout.index('{'):])
    errors = [e for e in result.get('errors', []) if e['severity'] == 'error']
    if errors:
        raise SystemExit(json.dumps(errors, indent=2))
    artifact = result['contracts']['ProvenMediaAnchor.sol']['ProvenMediaAnchor']
    artifact.update(schema='proven-media/testnet-anchor-contract/1', compiler=SOLC,
                    source_sha256=hashlib.sha256(src).hexdigest(), settings=request['settings'])
    a.out.parent.mkdir(parents=True, exist_ok=True)
    a.out.write_text(json.dumps(artifact, indent=2)+'\n')
    print(json.dumps({'artifact': str(a.out), 'source_sha256': artifact['source_sha256'],
                      'creation_bytes': len(artifact['evm']['bytecode']['object'])//2,
                      'runtime_bytes': len(artifact['evm']['deployedBytecode']['object'])//2}))


if __name__ == '__main__': main()
