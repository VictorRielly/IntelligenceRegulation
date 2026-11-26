"""Read the retained pilot archive's HTTP headers and render them through the guest UI."""
import json
from pathlib import Path
import subprocess
import sys
from unittest.mock import Mock, patch

HERE = Path(__file__).resolve().parent
APP = HERE.parents[2] / 'apps/proven-media'
PILOT = HERE.parent / 'app_composed_native_20261122'
sys.path.insert(0, str(APP))
from fastapi.testclient import TestClient
from proven_media import app, manifest, tar_download
from proven_media.publisher import LocalChainPublisher


def check():
    receipt = json.loads((PILOT / 'DOWNLOAD_RESUME.json').read_bytes())
    run = PILOT / receipt['source_pilot']
    pilot = json.loads((run / 'RESULT.json').read_bytes())
    signed = json.loads((run / 'manifest.json').read_bytes())
    key = json.loads((run / 'publisher_public_key.json').read_bytes())['public_key']
    assert manifest.verify_signature(signed, key)['accepted']
    pid = signed['item']['post_id']
    public = Path(pilot['public_scratch'])
    assert (public / 'chain/blocks.jsonl').is_file()
    route = f'/api/posts/{pid}/verification-store.tar'
    store = Mock(post=Mock(return_value={'status':'published', 'manifest':json.dumps(signed)}))
    with (patch.object(app.S, 'store', store, create=True),
          patch.object(app.S, 'publisher', LocalChainPublisher(public), create=True),
          patch.object(tar_download, '_stream', side_effect=AssertionError('HEAD started a body'))):
        client = TestClient(app.app)
        try:
            head = client.head(route)
        finally:
            client.close()
    assert head.status_code == 200 and head.content == b''
    assert int(head.headers['content-length']) == pilot['downloaded_store_bytes'] == receipt['bytes']
    assert head.headers['etag'] == receipt['etag']
    assert head.headers['content-type'] == 'application/x-tar'
    # Feed the real response to the same view function as the published post. Only
    # the DOM node and fetch transport are substituted for this in-process check.
    browser = """
const vm = require('node:vm'), fs = require('node:fs'), assert = require('node:assert/strict');
const {url, status, headers} = JSON.parse(fs.readFileSync(0, 'utf8'));
const label = {}, link = {href:url, querySelector:() => label};
const fetch = async (href, options) => {
  assert.equal(href, url);
  assert.equal(options.method, 'HEAD');
  return {status, headers:new Map(Object.entries(headers))};
};
const context = vm.createContext({fetch, link});
vm.runInContext(fs.readFileSync('static/app.js', 'utf8').replace(/boot\\(\\);\\s*$/, ''), context);
vm.runInContext('showStoreDownloadSize(link)', context).then(() => {
  assert.equal(label.textContent, ' (2.01 GB)');
  assert.equal(link.title, Number(headers['content-length']).toLocaleString() + ' bytes');
  console.log(JSON.stringify({label:label.textContent.trim(), title:link.title}));
}).catch(error => { console.error(error); process.exitCode = 1; });
"""
    rendered = subprocess.run(
        ['node', '-e', browser], cwd=APP, check=True, capture_output=True,
        text=True, input=json.dumps({'url':route, 'status':head.status_code, 'headers':dict(head.headers)}))
    return {'source_pilot':run.name, 'http_status':head.status_code, 'content_type':head.headers['content-type'],
            'archive_bytes':int(head.headers['content-length']), 'response_body_bytes':len(head.content),
            'etag':head.headers['etag'], 'rendered':json.loads(rendered.stdout)}


if __name__ == '__main__':
    if not __debug__:
        raise RuntimeError('Run with assertions enabled')
    print(json.dumps(check(), indent=2))
