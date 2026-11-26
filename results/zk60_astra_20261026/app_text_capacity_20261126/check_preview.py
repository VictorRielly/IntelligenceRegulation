"""Exercise the actual author preview with the installed W16R2 prover configuration."""
import json
import os
from pathlib import Path
import sys
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
RUN = HERE.parent / 'app_composed_native_20261122/qualification-20261125T070919.014403Z'


def check(private):
    public = Path(json.loads((RUN / 'RESULT.json').read_bytes())['public_scratch'])
    if not (public / 'verifier-export-w16r2-94643880/profile.json').is_file():
        raise ValueError('The retained pilot verifier export is needed')
    os.environ.update(PM_PROVER='shieldstral-fast-w16r2', PM_FAST_WRITER_MODE='resident',
                      PM_PRIVATE_DIR=str(private), PM_PUBLIC_DIR=str(public), PM_REPO_ROOT=str(ROOT),
                      PM_FAST_WRITER_PYTHON=sys.executable,
                      PM_SHIELDSTRAL_TOKENIZER=str(HERE.parent / 'app_decision_refresh_20261104/tokenizers/tekken.json'))
    sys.path.insert(0, str(ROOT / 'apps/proven-media'))
    from fastapi.testclient import TestClient
    from proven_media import app, auth, provers

    app.S.auth = auth.AuthorAuth(private / 'auth.sqlite3')
    app.S.prover = provers.make_prover()
    client = TestClient(app.app)
    try:
        credential = app.S.auth.provision('preview')
        login = client.post('/api/session', json={'access_key': credential})
        login.raise_for_status()
        client.headers['X-PM-CSRF'] = login.json()['csrf']
        boundary = ('The garden is quiet today. ' * 40)[:999] + 'x'
        facts = {}
        for name, draft, count, proofs in (
                ('49 tokens with outer spaces', '  ' + ' x' * 49 + '  ', 49, 3),
                ('50 tokens', ' x' * 50, 50, 4), ('55 tokens', ' x' * 55, 55, 4),
                ('56 tokens', ' x' * 56, 56, 6), ('336 tokens', ' x' * 336, 336, 22),
                ('337 tokens', ' x' * 337, 337, 0),
                ('1000 characters', boundary, 223, 16), ('1001 characters', boundary + 'x', 0, 0)):
            reply = client.post('/api/tokenize', json={'text': draft})
            reply.raise_for_status()
            result = reply.json()
            assert (result['fits'], result['count'], result['proofs']) == (proofs > 0, count, proofs), (name, result)
            if not result['fits']:
                refused = client.post('/api/posts', data={'author': 'preview', 'kind': 'text', 'text': draft})
                assert refused.status_code == 400 and (not result['text_error'] or result['text_error'] == refused.json()['detail'])
            facts[name] = {k: result[k] for k in ('fits', 'count', 'proofs', 'text_error')}
        return facts
    finally:
        client.close()


if __name__ == '__main__':
    if not __debug__:
        raise RuntimeError('Run with assertions enabled')
    with tempfile.TemporaryDirectory() as private:
        print(json.dumps(check(Path(private)), indent=2))
