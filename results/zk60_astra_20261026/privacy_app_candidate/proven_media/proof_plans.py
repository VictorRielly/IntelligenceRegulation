"""Queue identity and coverage for separate category proofs.

`index` is the stable, post-wide job/ledger key. `category_chunk_index` is
the native chunk index within one policy. Keeping both avoids collisions
when categories have different prompt lengths and therefore different splits.
These checks do not replace native verification or the input-owner check.
"""
from . import records
from .prompting import ContentRefused


def category_work_plan(total, templates):
    from .shieldstral_text import category_plans
    plans = category_plans(total, templates)
    by_category = {t.category: t for t in templates}
    work = []
    for category in records.category_ids():
        template = by_category[category]
        for chunk in plans[category]:
            work.append({**chunk, 'index': len(work), 'category': category,
                         'category_chunk_index': chunk['index'], 'category_chunks': len(plans[category]),
                         'content_total': total, 'policy_id': template.policy_id,
                         'chunk_tokens': template.chunk_size, 'overlap_tokens': template.overlap,
                         'context_tokens': template.context_tokens})
    return work


def categories_for(chunk):
    return [chunk['category']] if 'category' in chunk else records.category_ids()


def proof_count(plan):
    return sum(len(categories_for(ch)) for ch in plan)


def is_category_plan(plan):
    return any('category' in ch for ch in plan)


def check_plan(actual, expected):
    # Compare canonical bytes, so bools and integers cannot compare equal.
    if not actual or records.canonical(actual) != records.canonical(expected):
        raise ContentRefused('the stored proof plan differs from the whole post and current policies')
    if any(type(ch.get('index')) is not int or ch['index'] != i for i, ch in enumerate(actual)):
        raise ContentRefused('proof jobs must have distinct sequential indices')
    if is_category_plan(actual) and (any('category' not in ch for ch in actual)
            or {ch['category'] for ch in actual} != set(records.category_ids())):
        raise ContentRefused('all registered categories require their own complete proof plan')


def check_category_record(rec, post_id, chunk, *, require_verdict=False):
    """Bind a collected category record to its queue slot and registered policy."""
    if 'category' not in chunk:
        return
    from .classifier_cli import R_C3_SCHEMA
    cat = chunk['category']
    policy = next((c for c in records.categories() if c['id'] == cat), None)
    if (not policy or rec.get('post_id') != post_id or rec.get('item_kind') != 'text'
            or records.canonical(rec.get('chunk')) != records.canonical(chunk)
            or set(rec.get('labels') or {}) != {cat}):
        raise ContentRefused('the proof record belongs to another item, category or chunk')
    label = rec['labels'][cat]
    if require_verdict and (label.get('bound_by_proof') is not True
            or rec.get('checks', {}).get('verify', {}).get('ok') is not True
            or rec.get('checks', {}).get('content_binding', {}).get('ok') is not True):
        raise ContentRefused('the category proof lacks accepted verification or input binding')
    if (label.get('policy_id') != chunk['policy_id'] or label.get('policy_id') != policy['policy']['id']
            or label.get('policy_sha256') != policy['policy']['sha256']):
        raise ContentRefused('the category proof differs from the registered policy')
    threshold = rec.get('threshold') or {}
    if any(records.canonical(threshold.get(k)) != records.canonical(records.threshold()[k]) for k in ('tau', 'c')):
        raise ContentRefused('the category proof differs from the screening threshold')
    st = rec.get('statement') or {}
    expected = {'index': chunk['category_chunk_index'], 'count': chunk['category_chunks'],
                'content_total': chunk['content_total'], 'chunk_size': chunk['chunk_tokens'],
                'overlap': chunk['overlap_tokens'], 'range': [chunk['start'], chunk['end']]}
    bounds = st.get('chunk') or {}
    if (st.get('schema') != R_C3_SCHEMA or st.get('policy') != chunk['policy_id']
            or any(records.canonical(bounds.get(k)) != records.canonical(v) for k, v in expected.items())
            or type(st.get('content_length_n')) is not int
            or st['content_length_n'] != chunk['end'] - chunk['start']):
        raise ContentRefused('the verified category statement does not cover its planned content')
    bit = st.get('verdict_bit')
    if type(bit) is not int or bit not in (0, 1) or label.get('value') != ('yes' if bit else 'no'):
        raise ContentRefused('the category label differs from its statement')
