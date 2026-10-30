"""Independent R13 public-shape schedule; inherits previously validated coordinates."""
from dataclasses import dataclass
import legacy_catalog as base

@dataclass(frozen=True)
class Geometry(base.Geometry):
 h24:bool=True
 def planes(self):
  # Independent count from R13 AccuracyIds word/group allocation, not
  # extracted Shape::a_plane_doms (the compiled comparison).
  return dict(T=4,Ht=2,L=2,D=39 if self.h24 else 38,Q=14,Kv=14,
              S=7 if self.dd else 9+2*self.ls,F=16,Tab=3,
              Dd=4+2*self.ls if self.dd else 0)
 def helpers(self):
  # Byte expression emitter has full-byte pins, even at coefficient one.
  n=dict(L=2,D=34 if self.h24 else 33,Q=14,Kv=14,F=14,
         S=6 if self.dd else 11+2*self.ls,Dd=5+2*self.ls if self.dd else 0)
  return {d:(v+1)//2 for d,v in n.items()}

def geometry(row):
 name=row['profile'];tiny='tinyllama' in name;dev='rung-' in name
 h24=not tiny and 'rung-lo-' not in name and 'rung-ld-' not in name
 h=32 if not dev else 16
 dh=row['query_width']//h
 kv=4 if tiny else 8
 # Padded dimensions are essential to the native natural domain logs.
 return Geometry(name,row['tokens'],row['width'],row['hidden'],h,dh,kv,
                 base.lg(row['n']),base.lg(row['n']),ln=3,
                 ls=(base.lg(row['tokens'])+row['f_e']+7)//8,
                 lp=2,full_norm=True,dd=32 if row['dd'] else 0,h24=h24)

def census(g,capacity=1):return base.census(g,capacity)
