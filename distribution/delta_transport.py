"""Cross-release transport: a complete snapshot referencing immutable old assets."""
import copy
import hashlib
import json
import re
from pathlib import Path

VERSION = re.compile(r'\d+\.\d+\.\d+')
BUNDLE = re.compile(r'AnomalyBureau-(?:resources-(?:base|code_ui|maps|case1|case2|characters_audio)|patch-[a-f0-9]{64})\.bin')

def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()

def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')

def publication(manifest, output, mode, changed_contents=0):
    assets = [output / 'AnomalyBureau-manifest-v3.json']
    assets += [output / c['name'] for c in manifest['containers'] if c['version'] == manifest['version']]
    setup = output / f"AnomalyBureau-Setup-{manifest['version']}.exe"
    if setup.is_file():
        assets.append(setup)
        if mode == 'incremental':
            mode = 'complete'
    sums = output / 'SHA256SUMS.txt'
    sums.write_text(''.join(f'{sha(p)}  {p.name}\n' for p in assets), encoding='utf-8')
    assets.append(sums)
    plan = dict(version=manifest['version'], mode=mode,
        assets=[dict(name=p.name, size=p.stat().st_size, sha256=sha(p)) for p in assets],
        dependencies=[c for c in manifest['containers'] if c['version'] != manifest['version']],
        upload_bytes=sum(p.stat().st_size for p in assets), changed_contents=changed_contents)
    save(output / 'publish-plan.json', plan)
    return plan

def base(manifest_path, runtime, output):
    manifest = json.loads(manifest_path.read_text(encoding='utf-8-sig'))
    manifest['transport'] = 3
    for f in manifest['files']:
        f['source_version'] = manifest['version']
    manifest['containers'] = [dict(version=manifest['version'], name=name,
        size=(output / name).stat().st_size, sha256=sha(output / name))
        for name in sorted({f['bundle'] for f in manifest['files']})]
    save(output / 'AnomalyBureau-manifest-v3.json', manifest)
    save(runtime / '_运行文件' / 'active.json', manifest)
    publication(manifest, output, 'base')
    return manifest

def prepare(records, baseline, version, previous_path, blobs, output):
    previous = json.loads(previous_path.read_text(encoding='utf-8-sig'))
    if previous.get('protocol') != 2 or previous.get('transport', 0) not in (0, 3) or previous['baseline'] != baseline:
        raise ValueError('Previous manifest has an incompatible baseline/transport')
    numbers = lambda v: tuple(map(int, v.split('.')))
    if not VERSION.fullmatch(version) or not VERSION.fullmatch(previous['version']) or numbers(version) <= numbers(previous['version']):
        raise ValueError('Incremental version must be newer than the previous manifest')
    old = {f['sha256']: f for f in previous['files']}
    containers = {(c['version'], c['name']): copy.deepcopy(c) for c in previous.get('containers', [])}
    if previous.get('transport', 0) == 0:
        for name in {f['bundle'] for f in previous['files']}:
            if not BUNDLE.fullmatch(name):
                raise ValueError('Invalid previous container name')
            path = previous_path.parent / name
            containers[(previous['version'], name)] = dict(version=previous['version'], name=name, size=path.stat().st_size, sha256=sha(path))
    fields = ('asset', 'download_size', 'download_sha256', 'bundle', 'offset')
    novel = {}
    for f in records:
        if f['sha256'] in old:
            prior = old[f['sha256']]
            if prior['size'] != f['size']:
                raise ValueError('Conflicting content lengths')
            f.update({k: prior[k] for k in fields})
            f['source_version'] = prior.get('source_version', previous['version'])
        else:
            novel.setdefault(f['sha256'], f)
    new_container = None
    if novel:
        pending = output / 'patch.pending'
        offsets = {}
        with pending.open('xb') as target:
            for content, f in sorted(novel.items()):
                blob = blobs / f['asset']
                if blob.stat().st_size != f['download_size'] or sha(blob) != f['download_sha256']:
                    raise ValueError('Changed resource transport checksum mismatch')
                offsets[content] = target.tell()
                with blob.open('rb') as source:
                    while chunk := source.read(1024 * 1024):
                        target.write(chunk)
        name = 'AnomalyBureau-patch-' + sha(pending) + '.bin'
        new_container = output / name
        pending.rename(new_container)
        if new_container.stat().st_size >= 2**31:
            raise ValueError('Patch exceeds the asset limit; create a new base release')
        containers[(version, name)] = dict(version=version, name=name, size=new_container.stat().st_size, sha256=sha(new_container))
        for f in records:
            if f['sha256'] in novel:
                f.update(bundle=name, offset=offsets[f['sha256']], source_version=version)
    used = {(f['source_version'], f['bundle']) for f in records}
    manifest = dict(protocol=2, transport=3, version=version, baseline=baseline, files=records,
                    containers=[containers[key] for key in sorted(used)])
    for c in manifest['containers']:
        if not VERSION.fullmatch(c['version']) or not BUNDLE.fullmatch(c['name']) or not 0 < c['size'] < 2**31 or not re.fullmatch('[a-f0-9]{64}', c['sha256']):
            raise ValueError('Invalid referenced container')
    for f in records:
        c = containers[(f['source_version'], f['bundle'])]
        if f['offset'] < 0 or f['download_size'] <= 0 or f['offset'] + f['download_size'] > c['size']:
            raise ValueError('Invalid resource range')
    save(output / 'AnomalyBureau-manifest-v3.json', manifest)
    publication(manifest, output, 'incremental', len(novel))
    return manifest

if __name__ == '__main__':
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--runtime', type=Path)
    p.add_argument('--base-manifest', type=Path)
    a = p.parse_args()
    if a.base_manifest:
        base(a.base_manifest, a.runtime, a.output)
    else:
        manifest = json.loads((a.output / 'AnomalyBureau-manifest-v3.json').read_text(encoding='utf-8'))
        old = json.loads((a.output / 'publish-plan.json').read_text(encoding='utf-8'))
        publication(manifest, a.output, old['mode'], old.get('changed_contents', 0))
