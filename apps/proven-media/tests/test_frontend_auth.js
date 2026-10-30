// Behavioral tests for session changes while private HTTP responses are in flight.
// A small DOM fixture is sufficient for these races; this is not a browser render test.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

async function main() {
  const elements = new Map();
  const document = {
    querySelector(selector) {
      if (!elements.has(selector)) elements.set(selector, { innerHTML: '', textContent: '', hidden: false });
      return elements.get(selector);
    }
  };
  let fetchImpl;
  const context = vm.createContext({ document, Headers, fetch: (...args) => fetchImpl(...args) });
  const source = fs.readFileSync(path.join(__dirname, '../static/app.js'), 'utf8').replace(/boot\(\);\s*$/, '');
  vm.runInContext(source, context);
  const run = code => vm.runInContext(code, context);
  const response = (body, status = 200) => ({ ok: status === 200, status,
    headers: new Headers({ 'Content-Type': 'application/json' }), json: async () => body });

  run("setSession({author:'@alice', csrf:'csrf-alice', operator:false})");
  let request;
  fetchImpl = async (url, options) => { request = { url, options }; return response({}); };
  await run("api('/api/posts', {method:'POST', body:'fixture'})");
  assert.equal(request.options.credentials, 'same-origin');
  assert.equal(request.options.headers.get('X-PM-CSRF'), 'csrf-alice');
  assert.equal(document.querySelector('[data-nav="status"]').hidden, true);

  let resolve;
  fetchImpl = () => new Promise(r => { resolve = r; });
  const stale = run("api('/api/posts/private-id')");
  run('setSession({})');
  resolve(response({ text: 'old private text' }));
  await assert.rejects(stale, /Session changed/);

  run("setSession({author:'@alice', csrf:'csrf-alice'})");
  const oldUnauthorized = run("api('/api/submissions')");
  run("setSession({author:'@bob', csrf:'csrf-bob'})");
  resolve(response({ detail: 'expired' }, 401));
  await assert.rejects(oldUnauthorized, /Session changed/);
  assert.equal(document.querySelector('#handle').textContent, '@bob');

  document.querySelector('#app').innerHTML = 'private text currently displayed';
  fetchImpl = async () => response({ detail: 'expired' }, 401);
  await assert.rejects(run("api('/api/submissions')"), /expired/);
  assert.equal(document.querySelector('#handle').textContent, 'Signed out');
  assert.ok(!document.querySelector('#app').innerHTML.includes('private text'));

  run("setSession({author:'@alice', csrf:'csrf-alice'})");
  fetchImpl = async () => response({ id: 'failed-id', status: 'failed', status_message: 'Could not be verified.' });
  await run("viewPost('failed-id')");
  const page = document.querySelector('#app').innerHTML;
  assert.ok(page.includes('Could not be verified.'));
  assert.ok(!page.includes('chunk'));
  assert.ok(!page.includes('undefined'));
  assert.equal(typeof document.querySelector('#delete-failed').onclick, 'function');
  console.log('PASS: mutation CSRF, sign-out race, account-switch race, expiry clears private view, generic failure page');
}

main().catch(error => { console.error(error); process.exitCode = 1; });
