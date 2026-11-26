// Render real UI functions with synthetic descriptors; no native proof claims.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const elements = new Map();
const document = {querySelector(selector) {
  if (!elements.has(selector)) elements.set(selector, {innerHTML: '', hidden: false});
  return elements.get(selector);
}};
const context = vm.createContext({document, Headers});
const source = fs.readFileSync(path.join(__dirname, '../static/app.js'), 'utf8').replace(/boot\(\);\s*$/, '');
vm.runInContext(source, context);
const run = code => vm.runInContext(code, context);
const candidate = {kind:'shieldstral-fast-w16r2', public_content_only:true, production:false,
  privacy_statement:{accepted:false,status:'Public content only; privacy not claimed'}};
const set = p => run(`S.cfg = {prover:${JSON.stringify(p)}, classifier:{name:'Shieldstral'}, categories:[],
  threshold:{rule:'fixed threshold'}, image_spec:{text:'pending'}, publisher:{description:'local test'}}`);

set(candidate);
assert.equal(run('isShieldstral()'), true);
run('renderModebar()');
assert.match(document.querySelector('#modebar').innerHTML, /Public content only/);
assert.match(run('stubTag()'), /privacy not claimed/);
assert.doesNotMatch(run('stubTag()'), /demo stub/);
assert.match(run('stepsHTML(null)'), /public input/);
assert.doesNotMatch(run('stepsHTML(null)'), /hidden input|hidden post/);
assert.match(run('honestLimits()'), /independent verifier accepted the three category proofs/i);
assert.match(run('honestLimits()'), /statistical screening result/);
assert.doesNotMatch(run('honestLimits()'), /benchmark comparison is complete|non-public posts still apply/);
assert.match(run('privateList()'), /File permissions do not establish proof privacy/);
run("S.handle='tester'; S.composeKind='text'; S.cfg.limits={max_content_tokens:336}; S.cfg.deploy={profile:'W16R2'}");
assert.match(run('composeHTML()'), /Post only content already intended to be public/);
run("S.cfg.category_set={id:'test',digest:'test'}");
assert.match(run(`publicTable({prover:${JSON.stringify(candidate)},receipt:{bytes:0,segments:0}})`), /Input commitments \(public content\)/);
assert.doesNotMatch(run(`publicTable({prover:${JSON.stringify(candidate)},receipt:{bytes:0,segments:0}})`), /Hidden-input commitments|opening stays private/);
run('viewAbout()');
assert.doesNotMatch(document.querySelector('#app').innerHTML, /Private: the content|each hidden chunk/);
assert.match(document.querySelector('#app').innerHTML, /public content only/i);

// The record's scope controls historical verification even if current mode differs.
set({kind:'shieldstral',privacy_statement:{accepted:true,status:'CPU privacy statement accepted'}});
run(`globalThis.post = {id:'p',status:'published',checks:[]};
     globalThis.record = {prover:${JSON.stringify(candidate)},receipt:{bytes:12},verify_with:{
       privacy_statement:{accepted:true,status:'CPU privacy statement accepted',scope:'stale inherited scope'}}};`);
assert.match(run('verifySection(post, record)'), /Public content only; privacy not claimed/);
assert.match(run('verifySection(post, record)'), /every category and chunk command in VERIFY.md/);
assert.doesNotMatch(run('verifySection(post, record)'), /verification-store\.tar/);
run('post.publication = {verification_store_available:true}');
assert.match(run('verifySection(post, record)'), /\/api\/posts\/p\/verification-store\.tar/);
assert.equal(run("verifySection(post, {prover:{kind:'fake'}})"), '');
assert.doesNotMatch(run('verifySection(post, record)'), /id="verifybtn"|fresh process/);
run("post.author='@tester'; S.handle='tester'");
assert.match(run('verifySection(post, record)'), /id="verifybtn"/);
assert.match(run("manifestSection({id:'pid', manifest:{}})"), /--signature-only --public-key/);
assert.doesNotMatch(run('verifySection(post, record)'), /CPU privacy statement accepted|stale inherited scope/);
assert.match(run('privateList(record.prover)'), /Local working files/);
set(candidate);
assert.match(run("privateList({kind:'shieldstral'})"), /Private material held by the platform/);

// Known public mode never displays an injected accepted privacy status.
set({...candidate,privacy_statement:{accepted:true,status:'CPU privacy statement accepted'}});
assert.equal(run('privacyLabel()'), 'Public content only; privacy not claimed');
set({kind:'shieldstral-fast'});
assert.match(run('stepsHTML(null)'), /hidden input/);
assert.equal(run('isPublicContent()'), false);
async function checkDraftEdits() {
  document.querySelectorAll = () => [];
  const field = document.querySelector('#ctext'), button = document.querySelector('#postbtn');
  const counter = document.querySelector('#counter');
  counter.textContent = 'Up to 1000 characters and 336 tokens';
  counter.classList = {toggle() {}};
  let timer;
  context.setTimeout = callback => { timer = callback; return 1; };
  context.clearTimeout = () => { timer = null; };
  const replies = [];
  context.nextPreview = () => new Promise(resolve => replies.push(resolve));
  run('api = nextPreview; S.composeKind = "text"; bindCompose()');
  field.value = 'short'; field.oninput();
  const earlier = timer();
  field.value = 'a'.repeat(1001); field.oninput();
  assert.equal(button.disabled, true);
  const later = timer();
  replies[1]({fits:false, text_error:'the post is too long', max_text_characters:1000});
  await later;
  replies[0]({fits:true, count:3, chunks:1, proofs:3});
  await earlier;
  assert.match(counter.textContent, /1000 characters/);
  assert.equal(button.disabled, true);
  field.value = 'short again'; field.oninput();
  const accepted = timer();
  replies[2]({fits:true, count:2, profile:'per-category', proofs:3, category_chunks:{hate:1,sexual:1,violence:1}});
  await accepted;
  assert.equal(button.disabled, false);
  field.value = ''; field.oninput();
  assert.equal(button.disabled, true);
  assert.equal(counter.textContent, 'Up to 1000 characters and 336 tokens');
}

checkDraftEdits().then(() => console.log('PASS: W16R2 public scope, progress, draft limits, history and privacy-status isolation'))
  .catch(error => { console.error(error); process.exitCode = 1; });
