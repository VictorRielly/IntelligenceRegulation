"""Pinned classifier command/result adapter shared by the future real app prover.

This module builds argv and validates fresh verifier/owner/label outputs. Execution
is supplied by the app's guarded pipeline; it never runs an unguarded heavy CLI.
The frozen development binary admits synthetic IDs only, not product categories.
"""
from __future__ import annotations

from dataclasses import dataclass
import hashlib
import json
import math
import os
from pathlib import Path
import stat

from .provers import ProverError
from . import records

R_C1_BINARY_SHA256='04036e269a5c0984c70dd2b391dc9e045156d87dfd9c41ccccad4088a204bb76'
R_C2_BINARY_SHA256='e320c2379bf765226c73e17ad5fe59dbd812e00980861102a1b9f727655feebb'
R_C3_BINARY_SHA256='5edb7241f3c6b788289fca4a03f4fd40649355cf016663ec9dadbdaaa66c9a8e'
R_C1_SCHEMA='zk60-classify-run/1'
R_C2_SCHEMA='zk60-classify-run/2'
R_C3_SCHEMA='zk60-classify-run/3'
DEV_TIED_SOURCE=('tied-source=dev-rung-synthetic-bf16 file=dev_tied_tensor_bf16.bin V=300 d=384 '
    'sha256=bba6d094831861aa0b207ae5ca46938e2115e02c81215ba95e27e2bad1cc1dd6 '
    'derivation=R12b-quantize(floor(x/scale+0.5),refuse-outside-int16,no-clip,no-rotation)')
DEV_POLICY='rung-tc-synthetic-policy-dev/1'
CONTEXT='zk60-classify-verdict'
VERIFIER_WRITER='zk60_classify verify, after its fresh-process verification of the run directory, from its own data'


def require(condition,reason):
    if not condition:raise ProverError('Classifier verification failed: '+reason)


def checked_digest(value):
    require(isinstance(value,str) and len(value)==64 and all(c in '0123456789abcdef' for c in value),'invalid pinned digest')
    return value


def in_git_tree(path):
    # Match the native owner-directory rule. An empty .git directory is not
    # a work tree (the sandbox installs such stubs in /tmp and $HOME).
    for parent in (path,*path.parents):
        marker=parent/'.git'
        if marker.is_dir() and (marker/'HEAD').exists():return True
        if marker.is_file():
            try:
                with marker.open('rb') as stream:
                    if stream.read(7)==b'gitdir:':return True
            except OSError:return True
    return False


def one_event(stdout,rc,event):
    """A terminal refusal or malformed JSON cannot be masked by a success line."""
    require(rc==0,'CLI refused or failed')
    found=[]
    for line in stdout.splitlines():
        if not line.strip():continue
        try:item=json.loads(line)
        except (ValueError,TypeError):raise ProverError('Classifier verification failed: malformed CLI event')
        require(isinstance(item,dict),'malformed CLI event')
        require(item.get('event') not in ('refused','app-outcome','REMOVAL-FAILED'),'CLI reported refusal')
        if item.get('event')==event:found.append(item)
    require(len(found)==1,'missing or duplicate '+event+' event')
    return found[0]


def chunk_plan(total,size,overlap,*,allow_short=False):
    require(type(total) is int and type(size) is int and type(overlap) is int and total>0 and size>overlap>=0,
            'content length or registered chunk geometry is invalid')
    if total<size:
        require(allow_short,'this classifier version does not support short content')
        return [(0,total)]
    starts=list(range(0,total-size+1,size-overlap))
    if starts[-1]!=total-size:starts.append(total-size)
    return [(a,a+size) for a in starts]


def check_statement_coverage(statements,total,size,overlap,policy,schema):
    """Check whole-post geometry against the caller's count, never a receipt's.

    This structural check supplies no proof acceptance or input-owner binding.
    """
    plan=chunk_plan(total,size,overlap,allow_short=schema==R_C3_SCHEMA)
    require(isinstance(statements,list) and len(statements)==len(plan),'category is missing a chunk')
    indexes=set()
    for statement in statements:
        require(isinstance(statement,dict) and statement.get('schema')==schema and
                statement.get('policy')==policy,'category mixes policies or statement schemas')
        bounds=statement.get('chunk')
        require(isinstance(bounds,dict) and all(type(bounds.get(k)) is int for k in
                ('index','count','content_total','chunk_size','overlap')),'malformed category chunk plan')
        index=bounds['index']
        require(0<=index<len(plan) and index not in indexes,'category has duplicate or unexpected chunk indexes')
        indexes.add(index)
        require(bounds['content_total']==total and bounds['count']==len(plan) and bounds['chunk_size']==size and
                bounds['overlap']==overlap,'proved content_total or chunk geometry differs from the post')
        span=bounds.get('range')
        require(isinstance(span,list) and len(span)==2 and all(type(n) is int for n in span) and
                span==list(plan[index]),'proved chunk range differs from the post')
        require(type(statement.get('content_length_n')) is int and
                statement['content_length_n']==plan[index][1]-plan[index][0],'proved chunk content length differs')
    return plan


@dataclass(frozen=True)
class Deployment:
    binary: Path
    binary_sha256: str
    prover_export: Path
    verifier_export: Path
    tables: Path
    statement_identity: str
    policy: str
    chunk_size: int
    overlap: int
    min_bits: int=95
    development: bool=False
    statement_schema: str=R_C1_SCHEMA

    def validate(self):
        checked_digest(self.binary_sha256);checked_digest(self.statement_identity)
        require(records.sha256_file(self.binary)==self.binary_sha256,'binary hash differs from pin')
        require(type(self.min_bits) is int,'invalid verification floor')
        require(self.statement_schema in (R_C1_SCHEMA,R_C2_SCHEMA,R_C3_SCHEMA),'unsupported statement schema')
        if self.development:
            require((self.binary_sha256,self.statement_schema) in
                    ((R_C1_BINARY_SHA256,R_C1_SCHEMA),(R_C2_BINARY_SHA256,R_C2_SCHEMA),
                     (R_C3_BINARY_SHA256,R_C3_SCHEMA)) and self.policy==DEV_POLICY,
                    'development exception requires a frozen binary with its matching schema and synthetic policy')
            require(self.min_bits>=93 and (self.chunk_size,self.overlap)==(23,4),'invalid development profile')
        else:
            require(self.min_bits>=95 and self.policy!=DEV_POLICY,'production requires at least 95 bits')
            require(self.statement_schema==R_C3_SCHEMA,'production requires the short-content model-bound classifier schema')
            require(self.binary_sha256 not in (R_C1_BINARY_SHA256,R_C2_BINARY_SHA256,R_C3_BINARY_SHA256),
                    'frozen development binaries have no production classifier profile')
        require(self.verifier_export.is_dir() and not any(p.name.startswith('seq_') for p in self.verifier_export.iterdir()),
                'verifier export contains private sequence data or is missing')
        require(self.prover_export.resolve()!=self.verifier_export.resolve(),'prover and verifier exports must be distinct')
        require(self.prover_export.is_dir() and self.tables.is_dir(),'prover export or classifier tables are missing')
        require(bool(self.policy) and '\x00' not in self.policy,'invalid policy')
        chunk_plan(self.chunk_size,self.chunk_size,self.overlap)


class ClassifierCLI:
    def __init__(self,deployment:Deployment):
        deployment.validate();self.deployment=deployment

    def _base(self,command):
        d=self.deployment;d.validate()
        export=d.prover_export if command=='prove' else d.verifier_export
        return [str(d.binary),command,'--export',str(export),'--tables',str(d.tables),
                '--policy',d.policy,'--label',CONTEXT]

    def _verify_base(self,command):
        d=self.deployment
        return self._base(command)+['--expect-statement',d.statement_identity,'--min-bits',str(d.min_bits)]

    def prove_command(self,content_file,chunk,sequence_dir,artifact,owner_dir):
        content_file,owner_dir,artifact=map(Path,(content_file,owner_dir,artifact))
        st=content_file.lstat()
        require(stat.S_ISREG(st.st_mode) and stat.S_IMODE(st.st_mode)==0o600 and st.st_uid==os.getuid(),
                'content must be an owned regular 0600 file')
        require(type(chunk) is int and chunk>=0,'invalid chunk index')
        owner=owner_dir.resolve();public=artifact.resolve().parent
        require(owner!=public and public not in owner.parents,'owner opening directory must be outside the public run parent')
        require(not in_git_tree(owner),'owner opening directory must be outside git work trees')
        return self._base('prove')+['--content-file',str(content_file),'--chunk',str(chunk),'--seq-dir',str(sequence_dir),
                                  '--out',str(artifact),'--owner-dir',str(owner_dir)]

    def verify_command(self,artifact):return self._verify_base('verify')+['--artifact',str(artifact)]

    def owner_command(self,artifact,decommitment,content_file):
        return self._verify_base('input-owner')+['--artifact',str(artifact),'--decommitment',str(decommitment),
                                                '--content-file',str(content_file)]

    def label_command(self,artifacts,expected_total):
        """expected_total comes from the original item, independently of proofs."""
        chunk_plan(expected_total,self.deployment.chunk_size,self.deployment.overlap,
                   allow_short=self.deployment.statement_schema==R_C3_SCHEMA)
        paths=[str(Path(p)) for p in artifacts]
        require(paths and len(set(paths))==len(paths) and all(',' not in p for p in paths),'invalid or duplicate run list')
        args=self._verify_base('label')+['--runs',','.join(paths)]
        if self.deployment.statement_schema==R_C3_SCHEMA:args+=['--expect-total',str(expected_total)]
        return args

    def _check_bound_parameters(self,statement):
        """Check R-C2's reported authorities against the verifier's export.

        Native fresh verification still supplies the model/table derivation and
        checks the profile digest against the pinned trained statement identity.
        This transport check cannot replace that verification.
        """
        d=self.deployment
        if d.statement_schema==R_C1_SCHEMA:return
        profile=json.loads((d.verifier_export/'profile.json').read_text())
        require(isinstance(profile,dict),'invalid verifier profile')
        margin=profile.get('classifier_margin_parameters');token=profile.get('token_io_parameters')
        require(isinstance(margin,dict) and isinstance(token,dict),'profile lacks classifier authorities')
        for key in ('yes_id','no_id','threshold_c'):
            require(type(margin.get(key)) is int and type(statement.get(key)) is int and
                    statement[key]==margin[key],'statement '+key+' differs from bound profile')
        require(margin['yes_id']>=0 and margin['no_id']>=0 and margin['yes_id']!=margin['no_id'],
                'invalid classifier token ids')
        scale=margin.get('public_scale');reported=statement.get('margin_scale')
        require(type(scale) in (int,float) and type(reported) in (int,float) and math.isfinite(scale)
                and scale>0 and reported==scale,'margin scale differs from bound profile')
        require(type(token.get('bos')) is int and type(statement.get('bos')) is int and
                statement['bos']==token['bos'],'BOS differs from bound profile')
        norm=token.get('classifier_final_norm');reported_norm=statement.get('final_norm')
        require(isinstance(norm,dict) and isinstance(reported_norm,dict) and all(
                type(norm.get(k)) is int and type(reported_norm.get(k)) is int and reported_norm[k]==norm[k]
                for k in ('g0','cn','tn','ceps')),'final norm differs from bound profile')
        for key in ('margin_vector_digest','embedding_digest','classifier_profile_digest'):
            checked_digest(statement.get(key))
        source=statement.get('tied_source')
        if d.development:
            require(source==DEV_TIED_SOURCE,'development tied source differs')
        else:
            require(isinstance(source,str) and source.startswith('tied-source=shieldstral-checkpoint '),
                    'production tied source differs')

    def _check_padding(self,statement,length):
        if self.deployment.statement_schema!=R_C3_SCHEMA:return
        prefix=statement.get('template_prefix_ids');suffix=statement.get('template_suffix_ids')
        require(isinstance(prefix,list) and isinstance(suffix,list) and prefix and suffix and
                all(type(n) is int and n>=0 for n in prefix+suffix),'invalid public template')
        d=self.deployment
        if d.development:
            require(prefix==list(range(1,9)) and suffix==[32],'development template differs')
        item_length=len(prefix)+length+len(suffix)
        context=len(prefix)+d.chunk_size+len(suffix)
        expected={'T':context,'item_length':item_length,'pad_id':2 if d.development else 11,
                  'pad_positions':context-item_length,'verdict_row':item_length-1}
        require(all(type(statement.get(k)) is int and statement[k]==v for k,v in expected.items()),
                'short-content padding or verdict row differs')

    def collect_verified(self,artifact,total,chunk,verify_stdout,verify_exit,owner_stdout,owner_exit):
        """Only fresh verified/owner-checked statements can produce accepted labels.

        Prover `proved` events are intentionally not an input to this method.
        """
        d=self.deployment;d.validate();plan=chunk_plan(total,d.chunk_size,d.overlap,allow_short=d.statement_schema==R_C3_SCHEMA)
        require(type(chunk) is int and 0<=chunk<len(plan),'unexpected chunk')
        verified=one_event(verify_stdout,verify_exit,'classified')
        owned=one_event(owner_stdout,owner_exit,'content-checked')
        raw=(Path(artifact)/'statement/statement.json').read_bytes()
        statement=json.loads(raw)
        require(isinstance(statement,dict),'malformed statement')
        require(statement.get('schema')==d.statement_schema,'unexpected statement schema for pinned binary')
        self._check_bound_parameters(statement)
        require(statement.get('statement_written_by')==VERIFIER_WRITER,'statement was not published by the verifier')
        require(verified.get('published_by') in ('this verifier','an earlier verifier (re-checked byte for byte)'),
                'verifier did not publish or recheck the statement')
        require(statement.get('trained_statement_identity')==d.statement_identity==verified.get('trained_statement_identity'),
                'model statement identity differs')
        require(statement.get('policy')==d.policy==verified.get('policy'),'policy differs')
        require(statement.get('context_label')==CONTEXT,'context differs')
        require(type(statement.get('verdict_bit')) is int and statement['verdict_bit'] in (0,1),'invalid verdict bit')
        verdict='flagged' if statement['verdict_bit'] else 'not-flagged'
        require(statement.get('verdict')==verdict==verified.get('verdict')==owned.get('verdict'),'verdict sources disagree')
        bounds=statement.get('chunk',{})
        require(isinstance(bounds,dict) and all(type(bounds.get(k)) is int for k in
                ('index','count','content_total','chunk_size','overlap')),'malformed chunk plan')
        require(bounds.get('index')==chunk==verified.get('chunk')==owned.get('chunk') and
                bounds.get('count')==len(plan)==verified.get('chunks') and bounds.get('range')==list(plan[chunk])==owned.get('range') and
                bounds.get('content_total')==total==owned.get('content_total') and bounds.get('chunk_size')==d.chunk_size and
                bounds.get('overlap')==d.overlap,'chunk plan differs from the item')
        length=plan[chunk][1]-plan[chunk][0]
        require(type(statement.get('content_length_n')) is int and statement['content_length_n']==length,
                'chunk content length differs')
        self._check_padding(statement,length)
        root=checked_digest(statement.get('input_token_endpoint_root'))
        require(root==verified.get('input_token_endpoint_root'),'input endpoint differs')
        for value in (statement.get('whole_run_floor_bits'),verified.get('whole_run_floor_bits')):
            require(type(value) in (int,float) and math.isfinite(value) and value>=d.min_bits,'verification floor is insufficient')
        blocks=statement.get('blocks')
        require(type(blocks) is int and 0<blocks<=1024,'invalid block count')
        directory=Path(artifact)
        names=[f'segment-{k:03}.bin' for k in range(blocks+2)]
        require(not directory.is_symlink() and set(p.name for p in directory.iterdir())==set(names+['statement']),
                'receipt directory has missing or unexpected entries')
        statement_dir=directory/'statement'
        require(not statement_dir.is_symlink() and set(p.name for p in statement_dir.iterdir())=={'statement.json'}
                and not (statement_dir/'statement.json').is_symlink(),'statement directory differs from native contract')
        # R-C1 publishes no segments.json. Keep this inventory in the app record;
        # adding it inside the native artifact would make fresh verification refuse.
        segments=[]
        for name in names:
            file=directory/name
            require(file.is_file() and not file.is_symlink(),'receipt segment is missing or is a symlink')
            segments.append({'file':name,'bytes':file.stat().st_size,'sha256':records.sha256_file(file)})
        return {'value':'yes' if statement['verdict_bit'] else 'no','proof':'accepted','bound_by_proof':True,
                'policy_id':d.policy,'development_only':d.development,'statement':statement,
                'statement_sha256':hashlib.sha256(raw).hexdigest(),'files':segments,'run_dir':str(artifact),
                'content_binding':True,'verifier_sha256':d.binary_sha256,'chunk':{'index':chunk,'start':plan[chunk][0],'end':plan[chunk][1]}}

    def check_label_records(self,records_,total):
        d=self.deployment;d.validate()
        require(isinstance(records_,list) and all(isinstance(r,dict) for r in records_),'malformed category records')
        plan=check_statement_coverage([r.get('statement') for r in records_],total,d.chunk_size,d.overlap,d.policy,d.statement_schema)
        require(all(isinstance(r.get('chunk'),dict) and type(r['chunk'].get('index')) is int for r in records_),
                'malformed app chunk records')
        by_index={r['chunk']['index']:r for r in records_}
        require(set(by_index)==set(range(len(plan))),'category has duplicate or missing chunk indexes')
        for i,r in by_index.items():
            require(r['statement'].get('schema')==d.statement_schema,'aggregate mixes statement schemas')
            self._check_bound_parameters(r['statement'])
            self._check_padding(r['statement'],plan[i][1]-plan[i][0])
            require(r.get('proof')=='accepted' and r.get('bound_by_proof') is True and r.get('policy_id')==d.policy and
                    r['statement']['trained_statement_identity']==d.statement_identity and
                    r['statement']['chunk']['index']==i and
                    (r['chunk']['start'],r['chunk']['end'])==plan[i],'category mixes incompatible chunks')
            bit=r['statement'].get('verdict_bit')
            require(type(bit) is int and bit in (0,1) and r.get('value')==('yes' if bit else 'no'),
                    'category label differs from its proved verdict')
        return plan,by_index

    def collect_label(self,records_,stdout,exit_code,total):
        d=self.deployment;plan,by_index=self.check_label_records(records_,total)
        result=one_event(stdout,exit_code,'label')
        if d.statement_schema==R_C3_SCHEMA:
            require(type(result.get('expect_total')) is int and result['expect_total']==total,
                    'native label did not check the post token count')
        flagged=[list(plan[i]) for i,r in sorted(by_index.items()) if r['value']=='yes']
        verdict='flagged' if flagged else 'not-flagged'
        ranges=result.get('flagged_ranges')
        require(isinstance(ranges,list) and all(isinstance(pair,list) and len(pair)==2 and
                all(type(n) is int for n in pair) for pair in ranges),'malformed flagged ranges')
        require(result.get('policy')==d.policy and result.get('label')==verdict and result.get('chunks')==len(plan) and
                result.get('content_total')==total and result.get('chunk_size')==d.chunk_size and result.get('overlap')==d.overlap and
                sorted(ranges)==flagged,'aggregate label differs')
        return {'value':'yes' if flagged else 'no','proof':'accepted','bound_by_proof':True,
                'policy_id':d.policy,'development_only':d.development,'flagged_ranges':flagged,'chunks':len(plan)}
