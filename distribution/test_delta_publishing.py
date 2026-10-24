"""Real exported UI/model resources; cross-release uploads and HTTP Range recovery.

Run under HiddenDesktop. Uses a reviewed base runtime, never live player data.
"""
import argparse
import copy
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path
from delta_transport import prepare, save, sha
from test_grouped_e2e import helper, json_file, wait_child
from build_groups import group_id

HERE = Path(__file__).resolve().parent

def main():
    p = argparse.ArgumentParser()
    p.add_argument('--base', type=Path, required=True)
    p.add_argument('--samples', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args()
    out = a.output.resolve()
    if out.drive.lower() != 'f:' or out.exists():
        raise ValueError('Fresh F: test directory required')
    out.mkdir(parents=True)
    blobs = out / 'blobs'; blobs.mkdir()
    server_root = out / 'server'; server_root.mkdir()
    base = json_file(a.base / 'AnomalyBureau-manifest-v3.json')
    assert base['version'] == '0.8.0'
    base_manifest = a.base / 'AnomalyBureau-manifest-v3.json'
    raw_base = json_file(Path(r'F:\诡异事务局\交付\AnomalyBureau-0.7.0-local-final\AnomalyBureau-manifest-v2.json'))
    old_files = {f['path']: f for f in raw_base['files']}
    targets = []
    previous = base_manifest
    records = copy.deepcopy(base['files'])
    reports = []
    for version, sample_version in [('0.8.1', '0.7.1'), ('0.8.2', '0.7.2')]:
        sample_root = a.samples / sample_version
        sample = json_file(sample_root / 'AnomalyBureau-manifest-v2.json')
        changes = {f['path']: f for f in sample['files'] if f['sha256'] != old_files[f['path']]['sha256']}
        # Keep the new updater script from the reviewed base; use real prior UI/model samples.
        records = [copy.deepcopy(changes.get(f['path'], f)) for f in records]
        old = json_file(previous)
        old_content = {f['sha256'] for f in old['files']}
        for f in records:
            if f['sha256'] not in old_content:
                with (sample_root / f['bundle']).open('rb') as stream:
                    stream.seek(f['offset']); data = stream.read(f['download_size'])
                blob = blobs / f['asset']; blob.write_bytes(data)
                assert sha(blob) == f['download_sha256']
        folder = server_root / ('v' + version); folder.mkdir()
        manifest = prepare(records, base['baseline'], version, previous, blobs, folder)
        plan = json_file(folder / 'publish-plan.json')
        assert plan['changed_contents'] == 1 and len(plan['assets']) == 3
        assert not list(folder.glob('AnomalyBureau-resources-*.bin'))
        reports.append(plan)
        previous = folder / 'AnomalyBureau-manifest-v3.json'
        targets.append((manifest, previous))
    zero_dir = server_root / 'v0.8.3'; zero_dir.mkdir()
    unchanged = prepare(copy.deepcopy(targets[-1][0]['files']), base['baseline'], '0.8.3', previous, blobs, zero_dir)
    zero_plan = json_file(zero_dir / 'publish-plan.json')
    assert zero_plan['changed_contents'] == 0 and len(zero_plan['assets']) == 2
    old_root = server_root / 'v0.8.0'; old_root.mkdir()
    for c in base['containers']:
        os.link(a.base / c['name'], old_root / c['name'])
    port_file = out / 'port.txt'; network = out / 'network.jsonl'
    with (out / 'server.log').open('w') as log:
        server = subprocess.Popen([sys.executable, str(HERE / 'test_range_server.py'), '--root', str(server_root), '--log', str(network), '--port-file', str(port_file)], stdout=log, stderr=log, creationflags=subprocess.CREATE_NO_WINDOW)
    deadline = time.monotonic() + 15
    while not port_file.exists():
        if time.monotonic() > deadline: raise RuntimeError('Local server did not start')
        time.sleep(.1)
    origin = 'http://127.0.0.1:' + port_file.read_text().strip()
    args = ['--headless', '--audio-driver', 'Dummy', '--max-fps', '60', '--quit-after', '900', '--', '--verify', '--distribution-test-exit-seconds=6']
    applied = []
    def seed(name):
        root = out / name
        shutil.copytree(a.base / 'Windows', root)
        player = root / '_玩家数据'; player.mkdir()
        (player / 'save_1.json').write_bytes(b'save sentinel')
        (player / 'settings.cfg').write_bytes(b'settings sentinel')
        return root
    def action(root, version, action, manifest, expected=0):
        status = out / f'{root.name}-{version}-{action}-{time.time_ns()}.json'
        extra = [origin + '/v' + version] if action == 'download' else (['-999', os.urandom(16).hex(), *args, '--data-dir=' + str(out / (root.name + '-data'))] if action == 'apply' else [])
        helper(root, action, manifest, status, *extra, expected=expected)
        return json_file(status) if status.exists() else {}
    try:
        root = seed('sandbox-连续 中文 空格')
        for (manifest, path), report in zip(targets, reports):
            version = manifest['version']
            planned = action(root, version, 'plan', path)
            patch = next(c for c in manifest['containers'] if c['version'] == version)
            assert planned['bytes'] == patch['size']
            if version == '0.8.1':
                for mode in ['interrupt', 'corrupt']:
                    (server_root / 'server-mode.txt').write_text(mode)
                    failed = action(root, version, 'download', path, expected=1)
                    assert failed['state'] == 'error'
                    assert json_file(root / '_运行文件/active.json')['version'] == '0.8.0'
                (server_root / 'server-mode.txt').unlink()
            downloaded = action(root, version, 'download', path)
            assert downloaded['total'] == patch['size']
            assert action(root, version, 'plan', path)['bytes'] == 0
            before = network.stat().st_size
            action(root, version, 'download', path)
            assert network.stat().st_size == before
            action(root, version, 'apply', path)
            journal = json_file(root / '_更新缓存/v2/transaction.json')
            assert journal['state'] == 'committed'
            wait_child(root)
            assert json_file(root / '_运行文件/active.json')['version'] == version
            assert (root / '_玩家数据/save_1.json').read_bytes() == b'save sentinel'
            assert (root / '_玩家数据/settings.cfg').read_bytes() == b'settings sentinel'
            applied.append(version)
        cross = seed('sandbox-跨版')
        m2, path2 = targets[-1]
        cross_bytes = action(cross, '0.8.2', 'plan', path2)['bytes']
        assert cross_bytes == sum(next(c for c in m['containers'] if c['version'] == m['version'])['size'] for m, _ in targets)
        action(cross, '0.8.2', 'download', path2)
        action(cross, '0.8.2', 'apply', path2); wait_child(cross)
        # A missing code/UI pack needs resources from two historical releases.
        code_files = [f for f in m2['files'] if f['group'] == 'code_ui']
        (cross / '_运行文件/packs' / ('code_ui-' + group_id(code_files) + '.zip')).unlink()
        repair = action(cross, '0.8.2', 'plan', path2)
        assert repair['bytes'] > 0
        action(cross, '0.8.2', 'download', path2)
        action(cross, '0.8.2', 'apply', path2); wait_child(cross)
        assert action(cross, '0.8.2', 'plan', path2)['bytes'] == 0
        assert json_file(cross / '_更新缓存/v2/transaction.json')['state'] == 'committed'
        entries = [json.loads(line) for line in network.read_text().splitlines()]
        assert any(e['path'].startswith('v0.8.1/') for e in entries)
        assert any(e['path'].startswith('v0.8.0/') for e in entries)
        save(out / 'result.json', dict(ok=True, samples=reports, unchanged_upload=zero_plan,
            consecutive=applied, cross_version_bytes=cross_bytes, repair_bytes=repair['bytes'],
            corruption_and_interruption_rejected=True, cache_reuse_zero_redownload=True,
            saves_preserved=True, real_exported_menu_health=True))
    finally:
        server.terminate(); server.wait(timeout=10)

if __name__ == '__main__':
    main()
