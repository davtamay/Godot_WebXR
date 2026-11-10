"""Compare exported resource contents, excluding the build-identity manifest.

Usage: python compare-thread-packs.py single.pck threaded.pck
"""
import hashlib
import json
import re
from pathlib import Path
import struct
import sys


def entries(path, raw=False):
    with Path(path).open('rb') as pack:
        def number(fmt):
            return struct.unpack('<' + fmt, pack.read(struct.calcsize('<' + fmt)))[0]
        if number('I') != 0x43504447:
            raise ValueError('Not a Godot pack')
        version = number('I')
        pack.read(12)
        flags = number('I')
        if flags & ~2:
            raise ValueError('Encrypted or sparse packs are not supported')
        base = number('Q')
        if version in (3, 4):
            pack.seek(number('Q'))
        elif version == 2:
            pack.read(64)
        else:
            raise ValueError(f'Unsupported pack version {version}')
        result = {}
        for _ in range(number('I')):
            name = pack.read(number('I')).rstrip(b'\0').decode()
            offset, size = number('Q'), number('Q')
            pack.read(16)
            file_flags = number('I')
            if file_flags:
                raise ValueError(f'Unsupported file flags for {name}: {file_flags}')
            position = pack.tell()
            pack.seek(base + offset)
            data = pack.read(size)
            if len(data) != size:
                raise ValueError(f'Truncated pack entry: {name}')
            result[name.removeprefix('res://')] = data if raw else hashlib.sha256(data).hexdigest()
            pack.seek(position)
        return result


def canonical(name, data):
    if name == '.godot/global_script_class_cache.cfg':
        text = re.sub(r'(:\s*)&"', r'\1"', data.decode().removeprefix('list='))
        return sorted(json.loads(text), key=lambda item: item['class'])
    if name == '.godot/uid_cache.bin':
        count = struct.unpack_from('<I', data)[0]
        position = 4
        rows = []
        for _ in range(count):
            uid, size = struct.unpack_from('<QI', data, position)
            position += 12
            rows.append((uid, data[position:position + size].decode()))
            position += size
        if position != len(data):
            raise ValueError('Unexpected UID cache length')
        return sorted(rows)
    return data


if __name__ == '__main__':
    left, right = [entries(path, raw=True) for path in sys.argv[1:3]]
    identity = {'xr_build_provenance.json'}
    missing = sorted(left.keys() ^ right.keys())
    changed = sorted(key for key in left.keys() & right.keys() if key not in identity and canonical(key, left[key]) != canonical(key, right[key]))
    reordered = sorted(key for key in left.keys() & right.keys() if key not in identity and left[key] != right[key] and key not in changed)
    print(json.dumps({'resource_count': len(left), 'missing': missing, 'changed': changed, 'metadata_order_only': reordered, 'excluded_build_identity': sorted(identity), 'passed': not missing and not changed}, indent=2))
    sys.exit(1 if missing or changed else 0)
