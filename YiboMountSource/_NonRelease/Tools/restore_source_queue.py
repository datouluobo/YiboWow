#!/usr/bin/env python3
"""Restore unresolved source records to the candidate research queue."""
from __future__ import annotations
import argparse,json
from pathlib import Path

def main():
 p=argparse.ArgumentParser();p.add_argument('--catalog',type=Path,required=True);a=p.parse_args()
 root=json.loads(a.catalog.read_text(encoding='utf-8')); restored=0
 for mount in root['mounts']:
  source=next((s for s in mount['sources'] if s['sourceID']==mount['primarySourceID']),None)
  if not source or source.get('type')!='research': continue
  mount['status']='candidate'
  for node in source.get('path',[]):
   labels=node.get('labels',{})
   if '已从游戏提示中隐藏' in labels.get('zhCN','') or '不属于目标客户端或为技术重复法术' in labels.get('zhCN',''):
    labels['zhCN']='来源待补全'; labels['enUS']='Source pending completion'
  restored+=1
 a.catalog.write_text(json.dumps(root,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
 print(f'restored {restored} source records to the candidate queue')
if __name__=='__main__':main()
