#!/usr/bin/env python3
"""Import client-localized YMS fact labels into the non-release catalog.

The input is YMS SavedVariables only. It is parsed as a Lua table without
executing it; ATT source files and runtime code are never read by this step.
"""
from __future__ import annotations
import argparse,json,re
from pathlib import Path

def balanced_table(text, start):
 start=text.find('{',start)
 if start<0: raise ValueError('Lua table opening brace not found')
 depth,index,quote=0,start,None
 while index<len(text):
  char=text[index]
  if quote:
   if char=='\\': index+=2;continue
   if char==quote: quote=None
  elif char in {'\'', '"'}: quote=char
  elif char=='{': depth+=1
  elif char=='}':
   depth-=1
   if depth==0:return text[start:index+1]
  index+=1
 raise ValueError('unterminated Lua table')

def brace_depth_at(text, position):
 depth,index,quote=0,0,None
 while index<position:
  char=text[index]
  if quote:
   if char=='\\': index+=2;continue
   if char==quote: quote=None
  elif char in {'\'', '"'}: quote=char
  elif char=='{': depth+=1
  elif char=='}': depth-=1
  index+=1
 return depth

def child_tables(table):
 return {int(m.group(1)):balanced_table(table,m.start()) for m in re.finditer(r'\[(?:"|\')?(\d+)(?:"|\')?\]\s*=\s*\{',table) if brace_depth_at(table,m.start())==1}

def decode_lua_string(value):
 return value.replace(r'\\', '\\').replace(r'\"', '"').replace(r'\n', '\n').replace(r'\r', '\r').replace(r'\t', '\t')

def string_entries(table):
 return {int(i):decode_lua_string(value) for i,value in re.findall(r'\[(\d+)\]\s*=\s*"((?:\\.|[^"\\])*)"',table)}

FIELDS={'npcNames':'NPC','mapNames':'Map','achievementNames':'Achievement','questNames':'Quest','instanceNames':'Instance','encounterNames':'Encounter','professionNames':'Profession','factionNames':'Faction'}

def main():
 p=argparse.ArgumentParser();p.add_argument('--saved-variables',type=Path,required=True);p.add_argument('--catalog',type=Path,required=True);a=p.parse_args()
 text=a.saved_variables.read_text(encoding='utf8'); start=text.find('["sourceFactNames"]')
 if start<0: raise SystemExit('sourceFactNames not found')
 names={}
 for spell,body in child_tables(balanced_table(text,start)).items():
  names[spell]={}
  for field in FIELDS:
   match=re.search(r'\["'+re.escape(field)+r'"\]\s*=\s*\{',body)
   if match:names[spell][field]=string_entries(balanced_table(body,match.start()))
 catalog=json.loads(a.catalog.read_text(encoding='utf8')); changed=0
 for mount in catalog['mounts']:
  spell=mount['ids']['spellIDs'][0]
  for source in mount['sources']:
   for node in source['path']:
    for field,prefix in FIELDS.items():
     for locale in ('zhCN','enUS'):
      label=node.get('labels',{}).get(locale,'');match=re.fullmatch(re.escape(prefix)+r' #(\d+)',label)
      value=match and names.get(spell,{}).get(field,{}).get(int(match.group(1)))
      if value:node['labels'][locale]=value;changed+=1
 a.catalog.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n',encoding='utf8',newline='\n')
 print(f'imported {changed} client-resolved fact labels')
if __name__=='__main__':main()
