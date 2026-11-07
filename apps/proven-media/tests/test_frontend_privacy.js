// Exercise the rendered status for approved, batch, missing and hostile metadata.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const elements = new Map();
const document = { querySelector(selector) {
  if (!elements.has(selector)) elements.set(selector, { innerHTML: '', hidden: false });
  return elements.get(selector);
}};
const context = vm.createContext({ document, Headers });
const source = fs.readFileSync(path.join(__dirname, '../static/app.js'), 'utf8').replace(/boot\(\);\s*$/, '');
vm.runInContext(source, context);
const run = code => vm.runInContext(code, context);
const setProver = p => run(`S.cfg = {prover:${JSON.stringify(p)}, classifier:{name:'Shieldstral'}, publisher:{description:'testnet'}}`);
const approved = {kind:'shieldstral', label:'Classifier', privacy_statement:{
  accepted:true, status:'CPU privacy statement accepted', scope:'Named CPU build; public weights.'}};

setProver(approved);
run('renderModebar()');
assert.match(document.querySelector('#modebar').innerHTML, /CPU privacy statement accepted/);
assert.match(document.querySelector('#modebar').innerHTML, /moderate policies are selected/);
assert.doesNotMatch(document.querySelector('#modebar').innerHTML, /wording remains pending/);
assert.match(run('stubTag()'), /CPU privacy statement accepted/);
assert.match(run('honestLimits()'), /non-public posts still apply/);
assert.match(run('honestLimits()'), /benchmark comparison is complete/);
run("Object.assign(S.cfg, {categories:[], threshold:{rule:'fixed threshold'}, image_spec:{text:'pending image proofs'}}); viewAbout()");
assert.match(document.querySelector('#app').innerHTML, /CPU privacy statement accepted/);
assert.doesNotMatch(document.querySelector('#app').innerHTML, /privacy statement is pending acceptance|Privacy statement pending/);
assert.doesNotMatch(run('privateList()'), /Privacy statement pending/);

setProver({...approved, batch_proving:true, privacy_status:'CPU privacy statement accepted',
  privacy_statement:{accepted:false, status:'privacy statement pending', scope:'Batch review pending.'}});
run('renderModebar()');
assert.match(document.querySelector('#modebar').innerHTML, /privacy statement pending/);
assert.doesNotMatch(run('stubTag()'), /CPU privacy statement accepted/);
run("Object.assign(S.cfg, {categories:[], threshold:{rule:'fixed threshold'}, image_spec:{text:'pending image proofs'}}); viewAbout()");
assert.match(document.querySelector('#app').innerHTML, /privacy statement pending/);
assert.doesNotMatch(document.querySelector('#app').innerHTML, /CPU privacy statement accepted/);

setProver({kind:'shieldstral'});
assert.match(run('stubTag()'), /privacy statement pending/);
setProver({...approved, privacy_statement:{status:'<img src=x onerror=alert(1)>', scope:'<script>bad</script>'}});
run('renderModebar()');
assert.ok(document.querySelector('#modebar').innerHTML.includes('&lt;img'));
assert.ok(!document.querySelector('#modebar').innerHTML.includes('<img'));
assert.ok(!run('honestLimits()').includes('<script>'));

setProver(approved);
run(`globalThis.post = {id:'p', status:'published', labels:[{short:'hate',value:'no'}], checks:[]};
     globalThis.record = {prover:{kind:'shieldstral'}, receipt:{bytes:17}, verify_with:{
       privacy_statement:{accepted:false,status:'privacy statement pending',scope:'This record is outside D58.'}}};`);
assert.doesNotMatch(run('labelsHero(post, record)'), /CPU privacy statement accepted/);
assert.match(run('verifySection(post, record)'), /Profile privacy: privacy statement pending/);
assert.doesNotMatch(run('verifySection(post, record)'), /CPU privacy statement accepted/);

setProver({kind:'fake'}); assert.match(run('stubTag()'), /fake: no proof/);
setProver({kind:'stub-next-token'}); assert.match(run('stubTag()'), /demo stub/);
console.log('PASS: approved scope, batch scope, missing metadata, escaping, record-vs-current-profile isolation, fake/stub labels');
