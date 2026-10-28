"""Pinned R-C1 command/result adapter shared by the future real app prover.

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


def chunk_plan(total,size,overlap):
    require(type(total) is int and type(size) is int and type(overlap) is int and total>=size>overlap>=0,
            'content length or registered chunk geometry is invalid')
    starts=list(range(0,total-size+1,size-overlap))
    if starts[-1]!=total-size:starts.append(total-size)
    return [(a,a+size) for a in starts]


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

    def validate(self):
        checked_digest(self.binary_sha256);checked_digest(self.statement_identity)
        require(records.sha256_file(self.binary)==self.binary_sha256,'binary hash differs from pin')
        require(type(self.min_bits) is int,'invalid verification floor')
        if self.development:
            require(self.binary_sha256==R_C1_BINARY_SHA256 and self.policy==DEV_POLICY,
                    'development exception is restricted to frozen R-C1 and its synthetic policy')
            require(self.min_bits>=93 and (self.chunk_size,self.overlap)==(23,4),'invalid development profile')
        else:
            require(self.min_bits>=95 and self.policy!=DEV_POLICY,'production requires at least 95 bits')
            require(self.binary_sha256!=R_C1_BINARY_SHA256,'frozen R-C1 has no production classifier profile')
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

    def label_command(self,artifacts):
        paths=[str(Path(p)) for p in artifacts]
        require(paths and len(set(paths))==len(paths) and all(',' not in p for p in paths),'invalid or duplicate run list')
        return self._verify_base('label')+['--runs',','.join(paths)]

    def collect_verified(self,artifact,total,chunk,verify_stdout,verify_exit,owner_stdout,owner_exit):
        """Only fresh verified/owner-checked statements can produce accepted labels.

        Prover `proved` events are intentionally not an input to this method.
        """
        d=self.deployment;d.validate();plan=chunk_plan(total,d.chunk_size,d.overlap)
        require(type(chunk) is int and 0<=chunk<len(plan),'unexpected chunk')
        verified=one_event(verify_stdout,verify_exit,'classified')
        owned=one_event(owner_stdout,owner_exit,'content-checked')
        raw=(Path(artifact)/'statement/statement.json').read_bytes()
        statement=json.loads(raw)
        require(isinstance(statement,dict),'malformed statement')
        require(statement.get('schema')=='zk60-classify-run/1','unexpected statement schema')
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
        require(statement.get('content_length_n')==d.chunk_size,'chunk content length differs')
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

    def collect_label(self,records_,stdout,exit_code,total):
        d=self.deployment;d.validate();plan=chunk_plan(total,d.chunk_size,d.overlap)
        result=one_event(stdout,exit_code,'label')
        require(len(records_)==len(plan),'category is missing a chunk')
        by_index={r['chunk']['index']:r for r in records_}
        require(set(by_index)==set(range(len(plan))),'category has duplicate or missing chunk indexes')
        for i,r in by_index.items():
            require(r['proof']=='accepted' and r['bound_by_proof'] is True and r['policy_id']==d.policy and
                    r['statement']['trained_statement_identity']==d.statement_identity and
                    r['statement']['chunk']['content_total']==total and
                    (r['chunk']['start'],r['chunk']['end'])==plan[i],'category mixes incompatible chunks')
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
