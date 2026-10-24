"""Close the actual exported game normally during a slow download, then retry."""
import argparse
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path
import test_grouped_e2e as test

p = argparse.ArgumentParser()
p.add_argument('--release', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
p.add_argument('--godot', type=Path, required=True)
a = p.parse_args()
out = a.output.resolve()
if out.drive.lower() != 'f:':
    raise ValueError('F: tests required')
os.environ['TEMP'] = os.environ['TMP'] = str(out / 'temp')
root, project = out / 'sandbox-exit-download', out / 'exit-project'
shutil.copytree(a.release / 'Windows', root)
shutil.copytree(out / 'service-project', project, ignore=shutil.ignore_patterns('.godot'))
shutil.copy2(test.HERE / 'updater/GroupedProbe.gd', project / 'probe.gd')
test.run([a.godot, '--headless', '--audio-driver', 'Dummy', '--path', project, '--export-release', 'Windows Desktop', root / 'AnomalyBureau.Game.exe'], out / 'exit-export.log')
baseline = test.json_file(a.release / 'Windows/_运行文件/active.json')
native = test.groups.digest((''.join(test.groups.digest((root / n).read_bytes()) for n in ('AnomalyBureau.Game.exe', 'AnomalyBureau.Game.pck'))).encode('ascii'))
test.groups.write_json(root / '_运行文件/active.json', dict(baseline, baseline=native))
target = test.json_file(out / '0.7.2/AnomalyBureau-manifest-v2.json')
sample_sizes = test.json_file(out / 'actual-patch-sizes.json')
ui_bytes = int(sample_sizes[0]['download_bytes'])
model_bytes = int(sample_sizes[1]['download_bytes'])
target = dict(target, baseline=native, files=sorted(target['files'], key=lambda f: 0 if f['path'] == 'scripts/update_panel.gdc' else 1))
manifest = out / '0.7.2/exit-target.json'
test.groups.write_json(manifest, target)
data = root / '_玩家数据'
data.mkdir()
(data / 'save_1.json').write_bytes(b'exit-save-sentinel')
(data / 'settings.cfg').write_bytes(b'exit-settings-sentinel')
port_file = out / 'exit-port.txt'
server = subprocess.Popen([sys.executable, str(test.HERE / 'test_range_server.py'), '--root', str(out), '--log', str(out / 'exit-network.jsonl'), '--port-file', str(port_file)], creationflags=test.FLAGS)
try:
    while not port_file.exists():
        time.sleep(.1)
    url = 'http://127.0.0.1:' + port_file.read_text()
    restart = ['--headless', '--audio-driver', 'Dummy', '--log-file', str(out / 'exit-retry-menu.log'), '--', '--verify', '--distribution-test-exit-seconds=12', '--data-dir=' + str(out / 'exit-data')]
    config = out / 'exit-config.json'
    test.groups.write_json(config, dict(version='0.7.2', manifest=str(manifest), sha256=test.groups.digest(manifest.read_bytes()), size=manifest.stat().st_size,
        url=url + '/0.7.2/exit-target.json', restart_args=restart, result=str(out / 'exit-plan.json'), exit_during_download=True,
        exit_after_bytes=ui_bytes, exit_result=str(out / 'exit-proof.json')))
    (out / 'server-mode.txt').write_text('slow')
    test.run([root / 'AnomalyBureau.Game.exe', '--headless', '--audio-driver', 'Dummy', '--log-file', out / 'exit-old-menu.log', '--', '--verify',
              '--distribution-test-exit-seconds=90', '--data-dir=' + str(out / 'exit-data'), '--group-probe=' + str(config)], out / 'exit-process.log')
    assert test.json_file(out / 'exit-proof.json')['normal_tree_quit']
    deadline = time.monotonic() + 40
    cancelled = False
    while time.monotonic() < deadline:
        for path in (root / '_更新缓存/v2').glob('status-*.json'):
            value = test.json_file(path)
            if value.get('state') == 'error' and '取消' in value.get('message', ''):
                cancelled = True
        if cancelled:
            break
        time.sleep(.2)
    assert cancelled
    (out / 'server-mode.txt').unlink()
    assert test.json_file(root / '_运行文件/active.json')['version'] == '0.7.0'
    test.helper(root, 'plan', manifest, out / 'exit-retry-plan.json')
    assert test.json_file(out / 'exit-retry-plan.json')['bytes'] == model_bytes
    test.helper(root, 'download', manifest, out / 'exit-retry-download.json', url + '/0.7.2')
    test.helper(root, 'apply', manifest, out / 'exit-retry-apply.json', os.getpid(), 'e' * 32, *restart)
    test.wait_child(root)
    assert test.json_file(root / '_更新缓存/v2/transaction.json')['state'] == 'committed'
    assert (data / 'save_1.json').read_bytes() == b'exit-save-sentinel'
    assert (data / 'settings.cfg').read_bytes() == b'exit-settings-sentinel'
    test.groups.write_json(out / 'exit-result.json', dict(ok=True, normal_quit_during_download=True, old_version_preserved=True,
        completed_ui_blob_reused=True, retry_bytes=model_bytes, retry_real_menu_committed=True, player_data_unchanged=True))
    print('RESULT actual game exit during download and cached retry passed')
finally:
    if (out / 'server-mode.txt').exists():
        (out / 'server-mode.txt').unlink()
    server.terminate()
    server.wait(10)
