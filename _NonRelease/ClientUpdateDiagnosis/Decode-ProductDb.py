"""Read a copied protobuf database with a reference schema; never writes the database."""
import json
import re
import struct
import sys
from pathlib import Path

root = Path(sys.argv[1])
schema = (root / 'Reference-product_db.proto').read_text(encoding='utf-8')
messages = {}
for name, body in re.findall(r'message\s+(\w+)\s*\{(.*?)\}', schema, re.S):
    messages[name] = {int(number): (kind, field, bool(repeated)) for repeated, kind, field, number in
                      re.findall(r'(repeated\s+)?(\w+)\s+(\w+)\s*=\s*(\d+)\s*;', body)}

def varint(data, pos):
    value = shift = 0
    while pos < len(data) and shift < 70:
        byte = data[pos]
        pos += 1
        value |= (byte & 127) << shift
        if not byte & 128:
            return value, pos
        shift += 7
    raise ValueError('Invalid/truncated varint')

def decode(data, message):
    result = {}
    pos = 0
    while pos < len(data):
        tag, pos = varint(data, pos)
        number, wire = tag >> 3, tag & 7
        if number == 0:
            raise ValueError('Invalid field zero')
        if wire == 0:
            value, pos = varint(data, pos)
        elif wire in (1, 5):
            size = 8 if wire == 1 else 4
            value = data[pos:pos + size]
            if len(value) != size:
                raise ValueError('Truncated fixed value')
            pos += size
        elif wire == 2:
            length, pos = varint(data, pos)
            value = data[pos:pos + length]
            if len(value) != length:
                raise ValueError('Truncated field')
            pos += length
        else:
            raise ValueError(f'Unsupported wire type {wire}')
        kind, field, repeated = messages[message].get(number, ('unknown', f'unknown_{number}', True))
        if kind in messages:
            value = decode(value, kind)
        elif kind == 'string':
            value = value.decode('utf-8')
        elif kind == 'bool':
            value = bool(value)
        elif kind == 'double':
            value = struct.unpack('<d', value)[0]
        elif isinstance(value, bytes):
            value = {'wire': wire, 'hex': value.hex()}
        if repeated:
            result.setdefault(field, []).append(value)
        else:
            result[field] = value
    return result

decoded = decode((root / 'product.db').read_bytes(), 'ProductDb')
(root / 'Decoded-product.json').write_text(json.dumps(decoded, indent=2, ensure_ascii=False), encoding='utf-8')
for product in decoded.get('product_installs', []):
    if product.get('uid') in ('wow_classic', 'wow_cn_beta'):
        print(json.dumps(product, indent=2, ensure_ascii=False))
