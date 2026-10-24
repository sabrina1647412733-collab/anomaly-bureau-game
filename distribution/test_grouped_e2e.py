"""Real UI/model samples, byte-accurate Range HTTP tests, real exported menu health.
All paths must be on F:. No editor windows, sound, live saves, or process killing.
"""
import argparse
import ctypes
import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys
import time
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('groups', HERE / 'build_groups.py')
groups = importlib.util.module_from_spec(spec)
spec.loader.exec_module(groups)
FLAGS = subprocess.CREATE_NO_WINDOW

def run(args, log, expected=0, timeout=180):
    with log.open('w', encoding='utf-8') as out:
        p = subprocess.Popen([str(a) for a in args], stdout=out, stderr=subprocess.STDOUT, creationflags=FLAGS)
        code = p.wait(timeout=timeout)
    if expected is not None and code != expected:
        raise RuntimeError(f'Process exit {code}, see {log}')
    return code

def json_file(p):
    # Windows can briefly deny opening the destination during atomic replacement.
    for attempt in range(60):
        try:
            return json.loads(p.read_text(encoding='utf-8-sig'))
        except (PermissionError, FileNotFoundError, json.JSONDecodeError):
            if attempt == 59:
                raise
            time.sleep(.025)

def helper(root, action, manifest, status, *args, expected=0):
    return run([root / 'AnomalyBureau.exe', '--group-' + action, root, manifest, status, *args],
               status.with_suffix('.process.log'), expected=expected, timeout=240)

def wait_child(root):
    j = json_file(root / '_更新缓存/v2/transaction.json')
    kernel = ctypes.windll.kernel32
    kernel.OpenProcess.restype = ctypes.c_void_p
    kernel.WaitForSingleObject.argtypes = [ctypes.c_void_p, ctypes.c_ulong]
    kernel.CloseHandle.argtypes = [ctypes.c_void_p]
    handle = kernel.OpenProcess(0x100000, False, int(j.get('child_pid', 0)))
    if handle:
        try:
            if kernel.WaitForSingleObject(handle, 40000) == 258:
                raise RuntimeError('Isolated child did not exit naturally')
        finally:
            kernel.CloseHandle(handle)

def service_probe(a, out, baseline, target_manifest, url):
    """Drive the production Godot panel/service through plan -> download -> handoff."""
    project = out / 'service-project'
    shutil.copytree(a.release / 'bootstrap-project', project, ignore=shutil.ignore_patterns('.godot'), dirs_exist_ok=True)
    shutil.copy2(HERE / 'updater/GroupedProbe.gd', project / 'probe.gd')
    with (project / 'project.godot').open('a', encoding='utf-8') as f:
        f.write('\n[autoload]\nDistributionProbe="*res://probe.gd"\n')
    root = out / 'sandbox-service'
    shutil.copytree(a.release / 'Windows', root, dirs_exist_ok=True)
    run([a.godot, '--headless', '--audio-driver', 'Dummy', '--path', project, '--export-release', 'Windows Desktop', root / 'AnomalyBureau.Game.exe'], out / 'service-export.log')
    # The test bootstrap includes only an extra acceptance autoload. All game
    # code and resources, and the fixed launcher, remain the production versions.
    native = groups.digest((''.join(groups.digest((root / name).read_bytes()) for name in ('AnomalyBureau.Game.exe', 'AnomalyBureau.Game.pck'))).encode('ascii'))
    local = dict(baseline, baseline=native)
    target = dict(target_manifest, baseline=native)
    groups.write_json(root / '_运行文件/active.json', local)
    manifest = out / '0.7.1/service-target.json'
    groups.write_json(manifest, target)
    config = out / 'service-config.json'
    restart = ['--headless', '--audio-driver', 'Dummy', '--log-file', str(out / 'service-new-menu.log'), '--', '--verify', '--distribution-test-exit-seconds=12', '--data-dir=' + str(out / 'service-data')]
    content = out / 'ui-content-config.json'
    groups.write_json(content, dict(version='0.7.1', model_x=1.0, ui_label='安装更新', result=str(out / 'ui-content-result.json')))
    restart.append('--distribution-content-check=' + str(content))
    groups.write_json(config, dict(manifest=str(manifest), sha256=groups.digest(manifest.read_bytes()), size=manifest.stat().st_size,
                                  url=url + '/0.7.1/service-target.json', restart_args=restart, result=str(out / 'service-plan.json')))
    run([root / 'AnomalyBureau.Game.exe', '--headless', '--audio-driver', 'Dummy', '--log-file', out / 'service-old-menu.log', '--', '--verify',
         '--distribution-test-exit-seconds=90', '--data-dir=' + str(out / 'service-data'), '--group-probe=' + str(config)], out / 'service-process.log', timeout=180)
    deadline = time.monotonic() + 180
    journal = root / '_更新缓存/v2/transaction.json'
    expected_manifest = groups.digest(manifest.read_bytes())
    while time.monotonic() < deadline:
        if journal.exists():
            transaction = json_file(journal)
            if transaction.get('new_manifest') != expected_manifest or groups.digest((root / '_运行文件/active.json').read_bytes()) != expected_manifest:
                time.sleep(.2)
                continue
            state = transaction['state']
            if state == 'committed':
                wait_child(root)
                assert json_file(out / 'service-plan.json')['primary_enabled']
                return
            if state == 'rolled_back':
                raise RuntimeError('Production service handed off but new game rolled back')
        time.sleep(.2)
    raise RuntimeError('Production service handoff did not commit')

def main():
    p = argparse.ArgumentParser()
    p.add_argument('--release', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--godot', type=Path, required=True)
    a = p.parse_args()
    out = a.output.resolve()
    if out.drive.lower() != 'f:':
        raise ValueError('F: output required')
    out.mkdir(parents=True, exist_ok=True)
    os.environ['TEMP'] = os.environ['TMP'] = str(out / 'temp')
    (out / 'temp').mkdir(exist_ok=True)
    runtime = a.release / 'Windows'
    source = a.release / 'export.zip'
    sample = out / 'ui-project'
    (sample / 'scripts').mkdir(parents=True, exist_ok=True)
    ui = (HERE.parent / 'scripts/update_panel.gd').read_text(encoding='utf-8')
    (sample / 'scripts/update_panel.gd').write_text(ui.replace('立即更新', '安装更新'), encoding='utf-8')
    (sample / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="UI sample"\n[debug]\nfile_logging/enable_file_logging=false\n')
    (sample / 'export_presets.cfg').write_text('[preset.0]\nname="Windows Desktop"\nplatform="Windows Desktop"\nexport_filter="all_resources"\ninclude_filter=""\nexclude_filter=""\nscript_export_mode=2\n[preset.0.options]\nbinary_format/architecture="x86_64"\n')
    ui_zip = out / 'ui-compiled.zip'
    run([a.godot, '--headless', '--audio-driver', 'Dummy', '--path', sample, '--export-pack', 'Windows Desktop', ui_zip], out / 'ui-export.log')
    model = out / 'shoe.scn'
    run([a.godot, '--headless', '--audio-driver', 'Dummy', '--path', HERE.parent, '-s', 'res://distribution/updater/sample_model.gd', '--', source, model, out / 'model-proof.json'], out / 'model-export.log')
    with zipfile.ZipFile(source) as z:
        target = re.search(r'path="res://([^"]+)"', z.read('assets/models/case1_props/shoe.glb.import').decode())[1]
    with zipfile.ZipFile(ui_zip) as z:
        ui_bytes = z.read('scripts/update_panel.gdc')
    variants = []
    for version, overrides in [('0.7.1', {'scripts/update_panel.gdc': ui_bytes}),
                               ('0.7.2', {'scripts/update_panel.gdc': ui_bytes, target: model.read_bytes()})]:
        dest = out / version
        dest.mkdir(exist_ok=True)
        changed_export = dest / 'export.zip'
        with zipfile.ZipFile(source) as old, zipfile.ZipFile(changed_export, 'w') as new:
            for name in old.namelist():
                # This is an intermediate export fixture, not a download artifact.
                new.writestr(name, overrides.get(name, old.read(name)), compress_type=zipfile.ZIP_STORED)
        local_runtime = dest / 'Windows'
        local_runtime.mkdir(exist_ok=True)
        for name in ('AnomalyBureau.Game.exe', 'AnomalyBureau.Game.pck'):
            shutil.copy2(runtime / name, local_runtime / name)
        shutil.copytree(runtime / '_运行文件/packs', local_runtime / '_运行文件/packs', dirs_exist_ok=True)
        manifest = groups.build(changed_export, local_runtime, dest, version, blob_cache=a.release / '资源下载')
        variants.append((dest, manifest))
    baseline = json_file(runtime / '_运行文件/active.json')
    report = []
    for index, (dest, m) in enumerate(variants):
        previous = baseline if index == 0 else variants[index - 1][1]
        previous_hashes = {f['sha256'] for f in previous['files']}
        changed = [f for f in m['files'] if f['sha256'] not in previous_hashes]
        assert len(changed) == 1, f'Expected one changed exported entry, got {len(changed)}'
        report.append(dict(version=m['version'], changed=[dict(path=f['path'], group=f['group'], asset=f['asset'],
                      bundle=f['bundle'], offset=f['offset'], bytes=f['download_size']) for f in changed],
                      download_bytes=sum(f['download_size'] for f in changed)))
    groups.write_json(out / 'actual-patch-sizes.json', report)
    root = out / 'sandbox-中文 有空格'
    if root.exists():
        raise ValueError('Use a fresh test output directory')
    shutil.copytree(runtime, root)
    data = root / '_玩家数据'
    data.mkdir()
    (data / 'save_1.json').write_bytes(b'player-save-sentinel')
    (data / 'settings.cfg').write_bytes(b'player-settings-sentinel')
    old_native = [groups.digest((root / name).read_bytes()) for name in ('AnomalyBureau.Game.exe', 'AnomalyBureau.Game.pck')]
    port_file, network_log = out / 'port.txt', out / 'network.jsonl'
    server = subprocess.Popen([sys.executable, str(HERE / 'test_range_server.py'), '--root', str(out), '--log', str(network_log), '--port-file', str(port_file)], creationflags=FLAGS)
    try:
        deadline = time.monotonic() + 10
        while not port_file.exists() and time.monotonic() < deadline:
            time.sleep(.1)
        url = 'http://127.0.0.1:' + port_file.read_text()
        restart = ['--headless', '--audio-driver', 'Dummy', '--log-file', str(out / 'updated-menu.log'), '--', '--verify',
                   '--distribution-test-exit-seconds=12', '--data-dir=' + str(out / 'isolated-menu-data')]
        for i, (dest, m) in enumerate(variants):
            mf = dest / 'AnomalyBureau-manifest-v2.json'
            status = out / f'plan-{i}.json'
            helper(root, 'plan', mf, status)
            assert json_file(status)['bytes'] == report[i]['download_bytes']
            if i == 0:
                # A truncated response and a full-length corrupt response must both fail,
                # then a normal retry succeeds without touching the active version.
                for mode in ('interrupt', 'corrupt'):
                    (out / 'server-mode.txt').write_text(mode)
                    helper(root, 'download', mf, out / (mode + '.json'), url + '/' + dest.name, expected=1)
                    assert json_file(root / '_运行文件/active.json')['version'] == '0.7.0'
                (out / 'server-mode.txt').unlink()
            else:
                (out / 'server-mode.txt').write_text('slow')
                status_cancel = out / 'cancel-download.json'
                cancelled = subprocess.Popen([str(root / 'AnomalyBureau.exe'), '--group-download', str(root), str(mf), str(status_cancel), url + '/' + dest.name], creationflags=FLAGS)
                time.sleep(.6)
                Path(str(status_cancel) + '.cancel').write_text('cancel')
                assert cancelled.wait(35) == 1
                assert '取消' in json_file(status_cancel)['message']
                assert json_file(root / '_运行文件/active.json')['version'] == '0.7.1'
                (out / 'server-mode.txt').unlink()
            helper(root, 'download', mf, out / f'download-{i}.json', url + '/' + dest.name)
            # A second download call must transfer zero payload bytes.
            before = network_log.read_text().count('\n')
            helper(root, 'download', mf, out / f'reuse-{i}.json', url + '/' + dest.name)
            assert json_file(out / f'reuse-{i}.json')['total'] == 0
            assert network_log.read_text().count('\n') == before
            helper(root, 'apply', mf, out / f'apply-{i}.json', os.getpid(), 'a' * 32, *restart)
            assert json_file(root / '_更新缓存/v2/transaction.json')['state'] == 'committed'
            wait_child(root)
            assert json_file(root / '_运行文件/active.json')['version'] == m['version']
        # Cross-version from 0.7.0 to 0.7.2; deleted intermediate code group is
        # rebuilt from its target blobs with no historical patch sequence required.
        root = out / 'sandbox-cross-version'
        shutil.copytree(runtime, root)
        data = root / '_玩家数据'
        data.mkdir()
        (data / 'save_1.json').write_bytes(b'player-save-sentinel')
        (data / 'settings.cfg').write_bytes(b'player-settings-sentinel')
        mf = variants[1][0] / 'AnomalyBureau-manifest-v2.json'
        helper(root, 'plan', mf, out / 'cross-plan.json')
        assert json_file(out / 'cross-plan.json')['bytes'] == sum(r['download_bytes'] for r in report)
        helper(root, 'download', mf, out / 'cross-download.json', url + '/0.7.2')
        helper(root, 'apply', mf, out / 'cross-apply.json', os.getpid(), 'b' * 32, *restart)
        wait_child(root)
        service_probe(a, out, baseline, variants[0][1], url)
        assert json_file(root / '_运行文件/active.json')['version'] == '0.7.2'
        assert (data / 'save_1.json').read_bytes() == b'player-save-sentinel'
        assert (data / 'settings.cfg').read_bytes() == b'player-settings-sentinel'
        assert old_native == [groups.digest((root / name).read_bytes()) for name in ('AnomalyBureau.Game.exe', 'AnomalyBureau.Game.pck')]
        # Remove exactly one real model entry from the current merged pack, then
        # repair this same version using only that resource's HTTP byte range.
        m = variants[1][1]
        model_group = [f for f in m['files'] if f['group'] == 'case1']
        pack = root / '_运行文件/packs' / ('case1-' + groups.group_id(model_group) + '.zip')
        repaired = pack.with_suffix('.repair')
        with zipfile.ZipFile(pack) as old, zipfile.ZipFile(repaired, 'w') as new:
            for name in old.namelist():
                if name != target:
                    groups.add(new, name, old.read(name))
        os.replace(repaired, pack)
        helper(root, 'plan', mf, out / 'repair-plan.json')
        assert json_file(out / 'repair-plan.json')['bytes'] == report[1]['download_bytes']
        helper(root, 'download', mf, out / 'repair-download.json', url + '/0.7.2')
        helper(root, 'apply', mf, out / 'repair-apply.json', os.getpid(), 'c' * 32, *restart)
        wait_child(root)
        normal = [json.loads(line) for line in network_log.read_text().splitlines() if not json.loads(line)['mode'] and json.loads(line)['path'].endswith('.bin')]
        groups.write_json(out / 'result.json', dict(ok=True, samples=report, successful_http_ranges=normal,
                          interrupted_and_corrupt_retries=True, download_cancel_keeps_old=True, same_version_model_repair=True, consecutive_and_cross_version=True,
                          production_panel_service_handoff=True, verified_reuse=True, saves_settings_unchanged=True, engine_bootstrap_unchanged=True))
        print(json.dumps(dict(ok=True, samples=report), ensure_ascii=True))
    finally:
        # Only our local HTTP fixture; never terminate any game process.
        server.terminate()
        server.wait(10)

if __name__ == '__main__':
    main()
