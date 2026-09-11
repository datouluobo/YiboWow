#!/usr/bin/env python3
"""Fetch only player-facing Mount-item source facts into a resumable cache."""
from __future__ import annotations
import argparse, html, json, re, time
from pathlib import Path
from urllib.request import Request, urlopen

SOURCE_RE = re.compile(r'whtt-extra whtt-([a-z]+)">([^<]+)<', re.I)
TAG_RE = re.compile(r"<[^>]+>")
def get(url):
    req=Request(url,headers={
        "User-Agent":"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/131.0 Safari/537.36",
        "Accept":"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language":"en-US,en;q=0.9",
    })
    with urlopen(req,timeout=30) as r:return r.read().decode("utf-8","replace")
def source(html_text):
    found=[]
    for kind,value in SOURCE_RE.findall(html_text):
        value=html.unescape(TAG_RE.sub("",value)).strip()
        if value: found.append({"kind":kind,"text":value})
    return found
def main():
 p=argparse.ArgumentParser();p.add_argument("--inventory",type=Path,required=True);p.add_argument("--catalog",type=Path,required=True);p.add_argument("--output",type=Path,required=True);p.add_argument("--limit",type=int);p.add_argument("--delay",type=float,default=.4);a=p.parse_args()
 old=json.loads(a.output.read_text(encoding="utf8")) if a.output.exists() else {"schemaVersion":1,"mounts":{}}
 item_by_spell={s:r["ids"].get("itemIDs",[]) for r in json.loads(a.catalog.read_text(encoding="utf8"))["mounts"] for s in r["ids"]["spellIDs"]}
 for m in json.loads(a.inventory.read_text(encoding="utf8"))["mounts"]:
  item_ids=item_by_spell.get(m["spellID"],[])
  if not item_ids: continue
  spell=str(m["spellID"])
  if spell in old["mounts"]: continue
  if a.limit is not None and len(old["mounts"])>=a.limit: break
  item=item_ids[0]
  record={"itemID":item,"spellID":m["spellID"],"enUS":[],"zhCN":[]}
  for locale,key in (("","enUS"),("cn/","zhCN")):
   try: record[key]=source(get(f"https://www.wowhead.com/mop-classic/{locale}item={item}"))
   except Exception as e: record["error"]=str(e)
   time.sleep(a.delay)
  old["mounts"][spell]=record
  a.output.write_text(json.dumps(old,ensure_ascii=False,indent=2)+"\n",encoding="utf8",newline="\n")
  print(f"cached spell {spell} item {item}")
if __name__=="__main__":main()
