// Category-local chunk numbers must not be confused with global ledger keys.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const context = vm.createContext({});
const source = fs.readFileSync(path.join(__dirname, '../static/app.js'), 'utf8').replace(/boot\(\);\s*$/, '');
vm.runInContext(source, context);
const run = code => vm.runInContext(code, context);
run(`S.cfg = {prover:{kind:'shieldstral'}, deploy:{},
  publisher:{description:'LOCAL STUB: no chain, network, wallet or key.'},
  threshold:{rule:'fixed',tau:0.5,c:0}, categories:[
    {id:'sexual',short:'explicit',policy:{}},
    {id:'violence',short:'violence',policy:{}},
    {id:'hate',short:'hate',policy:{}}]};
  globalThis.post = {chunks:[
    {index:0,category:'sexual',category_chunk_index:0,start:0,end:55,tokens:55},
    {index:1,category:'sexual',category_chunk_index:1,start:47,end:60,tokens:13},
    {index:2,category:'violence',category_chunk_index:0,start:0,end:55,tokens:55},
    {index:3,category:'hate',category_chunk_index:0,start:0,end:49,tokens:49}],
    labels:[{category:'hate',name:'hate',short:'hate',value:'unproved'}],
    publication:{anchors:{h:{chunk:3,category:'hate',status:'anchored',chain:'local-chain'}}}};
  globalThis.record = {labels:{hate:{chunks:[{index:3,value:'unproved'}]}}};`);
const grid = run('chunkGrid(post, "Proofs")');
assert.match(grid, /explicit · chunk 1/);
assert.match(grid, /explicit · chunk 2/);
assert.match(grid, /violence · chunk 1/);
assert.match(grid, /hate · chunk 1/);
assert.doesNotMatch(grid, /chunk [34]/);
assert.match(run('anchorSection(post)'), /hate · chunk 1/);
assert.match(run('labelsTable(post, record)'), /no proof in hate · chunk 1/);
run("record.labels.hate.chunks[0].value = 'yes'");
assert.match(run('labelsTable(post, record)'), /yes in hate · chunk 1/);

// Missing or mismatched plan metadata must not invent a category-local index.
run('post.chunks = post.chunks.slice(0, 3)');
assert.match(run('anchorSection(post)'), /hate · proof 4/);
run("post.chunks.push({index:3,category:'sexual',category_chunk_index:0})");
assert.match(run('anchorSection(post)'), /hate · proof 4/);
assert.equal(run('chunkLabel({index:2})'), 'chunk 3');
assert.equal(run("chunkLabel({index:2,category:'hate',category_chunk_index:0})"), 'hate · chunk 1');

const local = run('honestLimits()');
assert.match(local, /LOCAL STUB: no chain, network, wallet or key/);
assert.doesNotMatch(local, /Base Sepolia/);
run("S.cfg.publisher.description = 'Base Sepolia testnet: batch digest only.'");
assert.match(run('honestLimits()'), /Base Sepolia testnet: batch digest only/);
run("S.cfg.publisher.description = '<script>bad</script>'");
assert.doesNotMatch(run('honestLimits()'), /<script>/);
run("S.cfg.categories[2].short = '<img src=x>'; post.chunks[3].category = 'hate'");
assert.doesNotMatch(run('anchorSection(post)'), /<img/);
assert.match(run('anchorSection(post)'), /&lt;img/);
run(`S.cfg.expected = {stub_work_s:150};
  globalThis.pending = {status:'queued',chunks:post.chunks,job:{status:'queued',progress:{total:4,done:0,failed:0}}};
  globalThis.queue = {queued_jobs:4,queued:[{kind:'prove',jobs:4,post_id:'public-fixture',position:1,eta_s:60}]};`);
assert.match(run('labelsHero(pending, null)'), /4 category proofs/);
assert.doesNotMatch(run('labelsHero(pending, null)'), /4 chunks × 3/);
assert.match(run('queueHTML(queue, true)'), /4 category proofs/);
assert.doesNotMatch(run('queueHTML(queue, true)'), /12 proofs/);
run("S.cfg.prover.kind = 'shieldstral-fast'");
assert.match(run('queueHTML(queue, true)'), /4 category proofs/);
assert.match(run('labelsHero(pending, null)'), /4 category proofs/);
assert.doesNotMatch(run('labelsHero(pending, null)'), /per stub run|one at a time/);
assert.match(run('honestLimits()'), /category proofs concurrently/);
run("S.cfg.prover.kind = 'stub-next-token'");
assert.match(run('queueHTML(queue, true)'), /4 chunk runs \(12 proofs\)/);
const recheck = run(`verifySection({id:'fixture',status:'published',
  chunks:[{index:2,category:'violence',category_chunk_index:0}],
  checks:[{ok:true,at:'2026-11-12T00:00:00Z',verdict:{chunk:2,details:{verify_seconds:1}}}]},
  {prover:{kind:'shieldstral-fast'},receipt:{bytes:1}})`);
assert.match(recheck, /violence · chunk 1: proof valid/);
assert.doesNotMatch(recheck, /Chunk 3: proof valid|chunk 3: proof valid/);
console.log('PASS: category-local chunk identity, ledger lookup, legacy/missing metadata, publication scope and escaping');
