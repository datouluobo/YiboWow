# -*- coding: utf-8 -*-
"""审计辅助：join mounts.json / mount-inventory.json / catalog md，输出工作清单。"""
import json, re, csv, sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

ROOT = r'E:\Development\YiboWow\YiboMountSource\_NonRelease\Data'
cat = json.load(open(ROOT + r'\mounts.json', encoding='utf-8'))
inv = json.load(open(ROOT + r'\mount-inventory.json', encoding='utf-8'))

inv_by_spell = {}
for m in inv['mounts']:
    inv_by_spell[m['spellID']] = m

def path_zh(src):
    out = []
    for n in src.get('path', []):
        lab = n.get('labels', {})
        out.append(lab.get('zhCN') or lab.get('enUS') or '')
    return ' > '.join(x for x in out if x)

rows = []
for m in cat['mounts']:
    for sp in m['ids']['spellIDs']:
        ps = None
        for s in m['sources']:
            if s['sourceID'] == m.get('primarySourceID'):
                ps = s
        if ps is None and m['sources']:
            ps = m['sources'][0]
        iv = inv_by_spell.get(sp, {})
        rows.append({
            'spellID': sp,
            'key': m['mountKey'],
            'status': m['status'],
            'enUS': m['identity']['names'].get('enUS'),
            'zhCN': m['identity']['names'].get('zhCN'),
            'srcType': ps['type'] if ps else '',
            'avail': ps['availability'] if ps else '',
            'path': path_zh(ps) if ps else '',
            'price': (ps.get('requirements', {}).get('price') or {}).get('zhCN') if ps else '',
            'notes': (ps.get('requirements', {}).get('notes') or {}).get('zhCN') if ps else '',
            'nSources': len(m['sources']),
            'factions': '/'.join(m.get('restrictions', {}).get('factions', [])),
            'classes': '/'.join(m.get('restrictions', {}).get('classes', [])),
            'itemIDs': '/'.join(map(str, m['ids'].get('itemIDs', []))),
            'clientSourceType': iv.get('sourceType'),
            'clientSourceText': iv.get('sourceText', ''),
            'clientFaction': iv.get('faction'),
            'inInventory': sp in inv_by_spell,
        })

rows.sort(key=lambda r: r['spellID'])
print('catalog spell rows:', len(rows))
print('inventory spells:', len(inv_by_spell))
extra = [r['spellID'] for r in rows if not r['inInventory']]
print('catalog spells not in inventory:', extra)
miss = [s for s in inv_by_spell if all(r['spellID'] != s for r in rows)]
print('inventory spells not in catalog:', miss)

# dump full worklist tsv
with open(ROOT + r'\..\..\_audit_worklist.tsv', 'w', encoding='utf-8') as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0].keys()), delimiter='\t', lineterminator='\n')
    w.writeheader()
    for r in rows:
        w.writerow(r)

# client sourceType=10 (store) records
print('\n== client sourceType=10 (游戏商城) ==')
for r in rows:
    if r['clientSourceType'] == 10:
        print(r['spellID'], r['zhCN'], '| md:', r['srcType'], r['avail'], '|', r['path'])

# candidate / unknown / 待核实 groups
from collections import Counter
print('\n== status ==', Counter(r['status'] for r in rows))
print('== srcType ==', Counter(r['srcType'] for r in rows))
print('== avail ==', Counter(r['avail'] for r in rows))

print('\n== availability=unknown ==', sum(1 for r in rows if r['avail']=='unknown'))
print('== 待核实 type ==', sum(1 for r in rows if r['srcType']=='unverified'))
