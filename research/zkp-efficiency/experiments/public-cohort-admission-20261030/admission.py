"""Public requested-capacity model. No memory backend or private data.

owner/generation are trusted-driver metadata, not cryptographic authentication.
The model needs a separately justified reserve for every excluded component.
"""
class Refusal(ValueError): pass

class Arena:
    def __init__(self,budget,background,reserve_known=True):
        self.budget=budget;self.background=background;self.known=reserve_known
        self.commitments={};self.tables={};self.serial=0;self.events=[]
    def capacity(self):
        return self.background+sum(self.commitments.values())+sum(t['capacity'] for t in self.tables.values())
    def note(self,op,**kw):
        self.events.append(dict(op=op,**kw,total=self.capacity()))
    def admit(self,owner,persistent,round_bytes):
        if not self.known:raise Refusal('unknown excluded reserve')
        if owner in self.commitments or min(persistent,round_bytes)<=0:raise Refusal('descriptor')
        free=sorted((t['capacity'],i) for i,t in self.tables.items() if t['owner'] is None and t['capacity']>=round_bytes)
        extra=0 if free else round_bytes
        if self.capacity()+persistent+extra>self.budget:raise Refusal('capacity')
        self.commitments[owner]=persistent
        if free:
            _,i=free[0];t=self.tables[i];t.update(owner=owner,generation=t['generation']+1,logical=round_bytes,pending=set(),finished=False)
        else:
            i=self.serial;self.serial+=1
            t=dict(owner=owner,generation=0,capacity=round_bytes,logical=round_bytes,pending=set(),finished=False)
            self.tables[i]=t
        token=(i,owner,t['generation'])
        self.note('admit',owner=owner,persistent=persistent,requested=round_bytes,token=token,capacity=t['capacity'],reused=bool(free))
        return token
    def table(self,token):
        i,o,g=token
        if i not in self.tables:raise Refusal('slot')
        t=self.tables[i]
        if t['owner']!=o or t['generation']!=g:raise Refusal('owner/generation')
        return t
    def use(self,token,event):
        t=self.table(token)
        if t['finished'] or event in t['pending']:raise Refusal('use state')
        t['pending'].add(event);self.note('use',token=token,event=event)
    def complete(self,token,event):
        t=self.table(token)
        if event not in t['pending']:raise Refusal('unrecorded completion')
        t['pending'].remove(event);self.note('complete',token=token,event=event)
    def truncate(self,token,length):
        t=self.table(token)
        if t['finished'] or not 0<=length<=t['logical']:raise Refusal('length')
        t['logical']=length;self.note('truncate',token=token,logical=length)
    def finish_slot(self,token):
        t=self.table(token)
        if t['finished']:raise Refusal('already finished')
        t['finished']=True;self.note('finish_slot',token=token)
    def retire(self,token):
        t=self.table(token)
        if not t['finished'] or t['pending']:raise Refusal('last use incomplete')
        t['owner']=None;t['logical']=0;self.note('retire',token=token)
    def open_complete(self,owner):
        # A trusted driver must certify ALL downstream slot/PCS consumers,
        # not merely this one slot. This method models that external evidence.
        if owner not in self.commitments or any(t['owner']==owner for t in self.tables.values()):raise Refusal('owner still live')
        old=self.commitments.pop(owner);self.note('open_complete',owner=owner,released=old)
    def free_idle(self,index):
        if index not in self.tables or self.tables[index]['owner'] is not None:raise Refusal('not idle')
        old=self.tables.pop(index);self.note('free_idle',index=index,released=old['capacity'])
