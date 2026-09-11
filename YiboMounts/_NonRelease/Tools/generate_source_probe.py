#!/usr/bin/env python3
"""Generate a YMS-only runtime probe manifest from offline numeric facts."""
from __future__ import annotations
import argparse,json
from pathlib import Path

def lua(v):
 if v is None:return "nil"
 if isinstance(v,bool):return "true" if v else "false"
 if isinstance(v,(int,float)):return str(v)
 if isinstance(v,str):return '"'+v.replace('\\','\\\\').replace('"','\\"')+'"'
 if isinstance(v,list):return "{"+",".join(lua(x) for x in v)+"}"
 return "{"+",".join("["+lua(str(k))+"]="+lua(val) for k,val in sorted(v.items()))+"}"
def main():
 p=argparse.ArgumentParser();p.add_argument('--facts',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 facts=json.loads(a.facts.read_text(encoding='utf8'))['mounts']
 data={str(x['spellID']):x['hints'] for x in facts}
 a.output.write_text('-- GENERATED NON-RELEASE PROBE DATA\nlocal _, NS = ...\nNS.SourceFacts = '+lua(data)+'\n',encoding='utf8',newline='\n')
 print(f'generated {len(data)} source fact probe entries')
if __name__=='__main__':main()
