"""Package only the reviewed install manifest, never a played folder's data/cache."""
import argparse
import hashlib
import json
import zipfile
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('--runtime', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
a = p.parse_args()
layout = json.loads((a.runtime / 'layout.json').read_text(encoding='utf-8'))
with zipfile.ZipFile(a.output, 'x', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as z:
    z.write(a.runtime / 'layout.json', 'layout.json')
    for item in layout['files']:
        name = item['path']
        if '..' in Path(name).parts or Path(name).is_absolute() or name.startswith(('_玩家数据/', '_更新缓存/', '_开发者数据/')):
            raise ValueError('Unsafe portable path')
        path = a.runtime / name
        with path.open('rb') as stream:
            if hashlib.file_digest(stream, 'sha256').hexdigest() != item['sha256']:
                raise ValueError('Changed install file: ' + name)
        z.write(path, name)
