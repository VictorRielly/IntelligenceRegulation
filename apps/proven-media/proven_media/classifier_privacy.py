"""Display D58's existing scope; this is not a verifier or a deployment gate.

Keep these independent of mutable runtime pins: changing a binary/profile must
not carry its predecessor's acceptance. Historical signed records stay intact.
"""
ACCEPTED_STATUS = 'CPU privacy statement accepted'
PENDING_STATUS = 'privacy statement pending'
PROFILE_SHA = '2ba468f98085caf1136f27cf66220f93d8e316acb8dbae7e98f9eb68347f05a0'
IDENTITY = '29aeba6c04a819cdbafde311f7c9d0c678d85aff22292ae6b9647761158a0bd1'
RUN_PROFILE = 'hashline-zk-mr1/private-classify-run-shieldstral-3b-t128-r13-public-row/1'
BINARY_CLI = {
    'dfb8025eb903b203f4b50371fdd0dd00659d46a9dbaad9d121d6a68343ebc70c':
        'zk60_classify r16b, native R13, T128',
    '81bd86248e9f42393c9fe739e6794b7af155ad9a0a06874c89efb7a7bba18317':
        'zk60_classify r17, native R13, T128',
}
POLICIES = frozenset('shieldstral-1.0-3b-moderate-' + name + '/1'
                     for name in ('sexual', 'violence', 'hate'))


def statement_info(descriptor):
    """Describe the named profile only; never bless batch/subclass overrides.

The known legacy CPU description predates explicit device/proof-mode fields.
Its exact binary and CLI pair still identify the CPU per-category path. New
descriptions carry the fields, and any contrary/unknown value stays pending.
    """
    p = descriptor if isinstance(descriptor, dict) else {}
    binary = p.get('binary_sha256')
    policies = p.get('policy_ids')
    policy_ok = policies is None or (isinstance(policies, (list, tuple))
        and len(policies) == 3 and all(isinstance(x, str) for x in policies)
        and frozenset(policies) == POLICIES)
    accepted = (isinstance(binary, str) and binary in BINARY_CLI
        and p.get('kind') == 'shieldstral'
        and p.get('cli') == BINARY_CLI[binary]
        and p.get('model_digest') == IDENTITY
        and p.get('token_profile_digest') == PROFILE_SHA
        and p.get('run_profile') == RUN_PROFILE
        and p.get('prover_binary_sha256', binary) == binary
        and p.get('batch_proving', False) is False
        and p.get('privacy_adapter_supported', True) is True
        and p.get('device', 'cpu') == 'cpu'
        and p.get('proof_mode', 'per-category') == 'per-category'
        and policy_ok)
    return {'accepted': accepted, 'status': ACCEPTED_STATUS if accepted else PENDING_STATUS,
        'decision': 'D58' if accepted else None,
        'scope': ('Named CPU classifier build, public weights and registered moderate policies.' if accepted
                  else 'Privacy review remains pending for this proving path.'),
        'conditions': 'Deployment conditions for non-public posts still apply.',
        'permits_non_public_posts': False}
