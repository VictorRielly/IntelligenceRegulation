"""Reviewed R16b/T128 deployment for the explicitly selected testnet demo.

The moderate wording is authorized for this demo; the product ruling and
classifier privacy statement remain separate. No automatic binary upgrades.
"""
import json
from pathlib import Path

from . import config, records
from .classifier_cli import Deployment, R_C3_SCHEMA, require
from .shieldstral_text import CategoryTemplate

EXPORT_ROOT = config.REPO / 'results/zk60_shieldstral_export_20261026'
EXPORT = EXPORT_ROOT / 'native_low_h24_t128'
VERIFIER_EXPORT = EXPORT_ROOT / 'native_low_h24_t128-verifier'
BINARY = config.TOKEN_IO / 'cli/zk60_classify.r16b.release.bin'
BINARY_SHA = 'dfb8025eb903b203f4b50371fdd0dd00659d46a9dbaad9d121d6a68343ebc70c'
PROFILE_SHA = '2ba468f98085caf1136f27cf66220f93d8e316acb8dbae7e98f9eb68347f05a0'
IDENTITY = '29aeba6c04a819cdbafde311f7c9d0c678d85aff22292ae6b9647761158a0bd1'
RUN_PROFILE = 'hashline-zk-mr1/private-classify-run-shieldstral-3b-t128-r13-public-row/1'
POLICIES_SHA = 'b1cfcda9ea4f48ce3b95d871b81f77c6cd27f94daa85fc618ec8e54222b44314'
WRITER = EXPORT_ROOT / 'write_item_activations.py'
WRITER_SHA = '8d6ce81b74316ef36a7b5202376f465611436d980e4a46a51aa0f32e474d922d'
TEKKEN = Path('/home/victor/models/shieldstral-1.0-3b/tekken.json')
POLICY_SHAS = {
    'sexual': 'e702f604f893d95c773dda6b1cbd30c4c3a253555075c623bc5e800d164c0822',
    'violence': 'eb124ee93d46d2f716fb6beee54a8f26d21883a2b87daa721d9cbe92e5131128',
    'hate': 'c9a65df1b6a57e0e1aa5a497949aaae2b8c00843a7b3b465d69f9ee811b68f89',
}
# Native R16 measured RSS8.27GiB prove,2.32GiB verification, plus25%.
# Retain the native7GiB verify cap (includes checkpoint page cache).
RESOURCES = {'seqgen': (1.5, 3, 600), 'prove': (10.4, 11.5, 1200),
             'verify': (2.9, 7, 600), 'inowner': (2.9, 7, 600), 'label': (2.9, 7, 1800)}


def categories():
    return [{**c, 'policy_id': f'shieldstral-1.0-3b-moderate-{c["id"]}/1',
             'file': config.POLICY_DIR / f'shieldstral-moderate-{c["id"]}-v1.txt',
             'sha256': POLICY_SHAS[c['id']]} for c in config.CATEGORIES]


def templates():
    path = EXPORT_ROOT / 'category_policy_candidates.json'
    require(records.sha256_file(path) == POLICIES_SHA, 'registered template source changed')
    data = json.loads(path.read_bytes())['policies']
    result = []
    for c in categories():
        row = data['mod_' + c['id']]
        require(c['file'].read_text() == row['prefix_text'] + ' {{private_content}}' + row['suffix_text'] + '\n'
                and records.sha256_file(c['file']) == c['sha256'], 'displayed policy differs from native template')
        result.append(CategoryTemplate(c['id'], row['proposed_policy_id'], tuple(row['prefix_ids']),
                                       tuple(row['suffix_ids']), 128, 8, 8))
    return tuple(result)


def deployment(template):
    return Deployment(BINARY, BINARY_SHA, EXPORT, VERIFIER_EXPORT, VERIFIER_EXPORT / 'token_io',
                      IDENTITY, template.policy_id, template.chunk_size, 8, 95, False, R_C3_SCHEMA)


def validate(deploy):
    require(not deploy.development and deploy.binary == BINARY and deploy.binary_sha256 == BINARY_SHA
            and deploy.statement_identity == IDENTITY and deploy.statement_schema == R_C3_SCHEMA
            and deploy.min_bits == 95 and deploy.overlap == 8, 'real deployment differs from reviewed r16b')
    by_policy = {t.policy_id: t for t in templates()}
    require(deploy.policy in by_policy and deploy.chunk_size == by_policy[deploy.policy].chunk_size,
            'real category or geometry changed')
    for directory in (deploy.prover_export, deploy.verifier_export):
        require(records.sha256_file(directory / 'profile.json') == PROFILE_SHA, 'real export profile changed')
    require(deploy.tables.resolve() == (deploy.verifier_export / 'token_io').resolve(), 'real tied tables differ')
    require(records.sha256_file(WRITER) == WRITER_SHA, 'activation writer differs from tested source')
    deploy.validate()
