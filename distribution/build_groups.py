"""Split a real Windows export, preserving import/remap dependencies exactly once.

Transport is one compressed immutable blob per distinct resource content. The
runtime uses six merged ZIP packs, never thousands of mounted patch overlays.
"""
import argparse
import hashlib
import json
import re
import zipfile
from collections import Counter
from pathlib import Path

GROUPS = ('base', 'code_ui', 'maps', 'case1', 'case2', 'characters_audio')

def digest(data):
    return hashlib.sha256(data).hexdigest()

def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')

def add(z, name, data):
    item = zipfile.ZipInfo(name, (2000, 1, 1, 0, 0, 0))
    item.compress_type = zipfile.ZIP_DEFLATED
    z.writestr(item, data, compresslevel=6)

def group_for(path):
    p = path.lower()
    if p.startswith(('scripts/', 'assets/ui/')) or p.startswith('scenes/main.'):
        return 'code_ui'
    if 'case2' in p or 'huaian' in p:
        return 'case2'
    if p.startswith(('assets/audio/', 'assets/models/chars/', 'assets/town/xuyan/')):
        return 'characters_audio'
    if 'case1' in p or 'laundry' in p or p.startswith('scenes/'):
        return 'case1'
    if p.startswith('assets/town/'):
        return 'maps'
    return 'base'

def group_id(files):
    return digest('\n'.join(f"{f['path']}\t{f['sha256']}\t{f['size']}" for f in sorted(files, key=lambda f: f['path'])).encode())

def build(export_zip, runtime, output, version, blob_cache=None, previous_manifest=None):
    if not re.fullmatch(r'\d+\.\d+\.\d+', version):
        raise ValueError('Version must be X.Y.Z')
    blobs = blob_cache or output / '资源下载'
    blobs.mkdir(parents=True, exist_ok=True)
    packs = runtime / '_运行文件' / 'packs'
    packs.mkdir(parents=True, exist_ok=True)
    ownership = {}
    with zipfile.ZipFile(export_zip) as source:
        names = source.namelist()
        if len(set(names)) != len(names):
            raise ValueError('Duplicate exported paths')
        # Godot .import and .remap describe the actual generated destinations.
        for name in names:
            if name.endswith(('.import', '.remap')):
                for target in re.findall(r'"res://([^"\n]+)"', source.read(name).decode('utf-8', errors='strict')):
                    if target in names:
                        previous = ownership.get(target)
                        owner = group_for(name)
                        ownership[target] = owner if previous in (None, owner) else 'base'
        records = []
        for name in sorted(names):
            # Bootstrap owns settings; never replace them after engine initialization.
            if name == 'project.binary':
                continue
            if name.startswith('/') or '\\' in name or any(p in ('..', '.') for p in name.split('/')):
                raise ValueError('Unsafe exported path: ' + name)
            data = source.read(name)
            sha = digest(data)
            asset = 'r-' + sha + '.zip'
            blob = blobs / asset
            if not blob.exists():
                with zipfile.ZipFile(blob, 'w') as transport:
                    add(transport, 'data', data)
            records.append(dict(path=name, group=ownership.get(name, group_for(name)), size=len(data), sha256=sha,
                                asset=asset, download_size=blob.stat().st_size, download_sha256=digest(blob.read_bytes())))
        for group in GROUPS:
            files = [f for f in records if f['group'] == group]
            if not files:
                continue
            dest = packs / (group + '-' + group_id(files) + '.zip')
            if not dest.exists():
                with zipfile.ZipFile(dest, 'w') as pack:
                    for f in files:
                        add(pack, f['path'], source.read(f['path']))
    # Six publishable transport containers. Resource-sized HTTP Range reads avoid
    # GitHub's release asset-count limit without downloading unchanged entries.
    baseline = digest((''.join(digest((runtime / name).read_bytes()) for name in ('AnomalyBureau.Game.exe', 'AnomalyBureau.Game.pck'))).encode('ascii'))
    if previous_manifest:
        from delta_transport import prepare
        manifest = prepare(records, baseline, version, previous_manifest, blobs, output)
        write_json(runtime / '_运行文件' / 'active.json', manifest)
        return manifest
    locations = {}
    for group in GROUPS:
        bundle = 'AnomalyBureau-resources-' + group + '.bin'
        with (output / bundle).open('wb') as transport:
            for f in records:
                if f['group'] != group or f['sha256'] in locations:
                    continue
                locations[f['sha256']] = (bundle, transport.tell())
                transport.write((blobs / f['asset']).read_bytes())
    for f in records:
        f['bundle'], f['offset'] = locations[f['sha256']]
    baseline = digest((''.join(digest((runtime / name).read_bytes()) for name in ('AnomalyBureau.Game.exe', 'AnomalyBureau.Game.pck'))).encode('ascii'))
    manifest = dict(protocol=2, version=version, baseline=baseline, files=records)
    write_json(output / 'AnomalyBureau-manifest-v2.json', manifest)
    write_json(runtime / '_运行文件' / 'active.json', manifest)
    write_json(output / 'group-report.json', dict(
        entries=len(records), unique_contents=len({f['sha256'] for f in records}),
        groups={g: dict(entries=sum(f['group'] == g for f in records), bytes=sum(f['size'] for f in records if f['group'] == g)) for g in GROUPS},
        transport_bytes=sum(p.stat().st_size for p in blobs.glob('*.zip')),
        source_export=str(export_zip), import_destination_owners=len(ownership)))
    return manifest

if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--export', dest='export_zip', type=Path, required=True)
    p.add_argument('--runtime', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--version', required=True)
    p.add_argument('--previous-manifest', type=Path)
    a = p.parse_args()
    build(a.export_zip, a.runtime, a.output, a.version, previous_manifest=a.previous_manifest)
