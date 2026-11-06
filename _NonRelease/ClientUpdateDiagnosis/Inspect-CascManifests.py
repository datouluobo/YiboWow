"""Read-only local CASC metadata inspection. Outputs go to the diagnosis folder."""
from pathlib import Path
import hashlib
import json
import zlib

root = Path(__file__).resolve().parent
review = root / 'DatabaseReview-20261023-1604'
game = Path(r'C:\Program Files (x86)\World of Warcraft')
index = {}
for p in sorted((game / 'Data/data').glob('*.idx')):
    b = p.read_bytes()
    assert int.from_bytes(b[8:10], 'little') == 7
    length = int.from_bytes(b[32:36], 'little')
    assert length % 18 == 0
    for at in range(40, 40 + length, 18):
        addr = int.from_bytes(b[at+9:at+14], 'big')
        index[b[at:at+9]] = (addr >> 30, addr & ((1 << 30)-1), int.from_bytes(b[at+14:at+18], 'little'))

def read_blob(ekey):
    hit = index.get(bytes.fromhex(ekey)[:9])
    if hit is None:
        raise KeyError('No main-index entry for ' + ekey)
    archive, offset, size = hit
    with (game / f'Data/data/data.{archive:03}').open('rb') as f:
        f.seek(offset + 30)
        b = f.read(size - 30)
    assert b[:4] == b'BLTE'
    header = int.from_bytes(b[4:8], 'big')
    chunks = []
    if header == 0:
        chunks = [b[8:]]
    else:
        count = int.from_bytes(b[9:12], 'big')
        at = header
        for i in range(count):
            length = int.from_bytes(b[12+i*24:16+i*24], 'big')
            chunk = b[at:at+length]
            assert len(chunk) == length
            assert hashlib.md5(chunk).digest() == b[20+i*24:36+i*24]
            chunks.append(chunk)
            at += length
    result = []
    for chunk in chunks:
        if chunk[:1] == b'Z':
            result.append(zlib.decompress(chunk[1:]))
        elif chunk[:1] == b'N':
            result.append(chunk[1:])
        else:
            raise ValueError('Unsupported BLTE chunk ' + repr(chunk[:1]))
    return b''.join(result)

def config(uid):
    return dict(line.split(' = ', 1) for line in (review / f'BuildConfig-{uid}.txt').read_text().splitlines() if ' = ' in line)

def extract(uid, name):
    keys = config(uid)[name].split()
    b = read_blob(keys[1])
    assert hashlib.md5(b).hexdigest() == keys[0]
    (review / f'{name.capitalize()}-{uid}.bin').write_bytes(b)
    return b

def download_report(uid):
    b = extract(uid, 'download')
    assert b[:2] == b'DL'
    version, keylen, checksum = b[2:5]
    count = int.from_bytes(b[5:9], 'big')
    tags_count = int.from_bytes(b[9:11], 'big')
    flags = b[11] if version >= 2 else 0
    at = 16 if version >= 3 else 12 if version >= 2 else 11
    entry_size = keylen + 5 + 1 + (4 if checksum else 0) + flags
    entries_at = at
    at += count * entry_size
    tag_groups = {}
    tag_names = []
    for _ in range(tags_count):
        end = b.index(0, at)
        name = b[at:end].decode()
        kind = int.from_bytes(b[end+1:end+3], 'big')
        at = end + 3
        mask = b[at:at + (count+7)//8]
        at += (count+7)//8
        tag_names.append((name, kind))
        if name in ('Windows', 'x86_64', 'CN', 'zhCN', 'speech', 'text'):
            if kind in tag_groups:
                tag_groups[kind] = bytes(a | c for a,c in zip(tag_groups[kind], mask))
            else:
                tag_groups[kind] = mask
    assert at == len(b)
    summary = {}
    missing = []
    for i in range(count):
        if not all(mask[i//8] & (0x80 >> (i%8)) for mask in tag_groups.values()):
            continue
        at = entries_at + i * entry_size
        key = b[at:at+keylen]
        priority = b[at+keylen+5]
        key_priority = str(priority)
        stat = summary.setdefault(key_priority, {'selected': 0, 'missingMainIndex': 0})
        stat['selected'] += 1
        if key[:9] not in index:
            stat['missingMainIndex'] += 1
            if priority == 0:
                missing.append(key.hex())
    report = dict(uid=uid, version=version, count=count, tags=tag_names, priorities=summary, priority0MissingKeys=missing,
                  limitation='Main-table index lookup only; appended records and dynamic residency rules not interpreted. Tag matching is an approximation of the Agent query.')
    (review / f'DownloadReport-{uid}.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps({k: report[k] for k in ('uid','version','count','priorities')}, indent=2))

if __name__ == '__main__':
    for uid in ('wow_classic', 'wow_cn_beta'):
        download_report(uid)
    extract('wow_classic', 'encoding')
