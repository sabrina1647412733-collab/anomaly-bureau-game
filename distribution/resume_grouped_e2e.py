"""Resume the service/repair checks after a failed acceptance fixture, preserving
the previously recorded network/cancel/consecutive/cross-version evidence."""
import argparse
import importlib.util
import json
import os
import subprocess
import sys
import time
import zipfile
from pathlib import Path
import test_grouped_e2e as test

p = argparse.ArgumentParser()
p.add_argument('--release', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
p.add_argument('--godot', type=Path, required=True)
a = p.parse_args()
out = a.output.resolve()
if out.drive.lower() != 'f:':
    raise ValueError('F: output required')
os.environ['TEMP'] = os.environ['TMP'] = str(out / 'temp')
baseline = test.json_file(a.release / 'Windows/_运行文件/active.json')
m = test.json_file(out / '0.7.2/AnomalyBureau-manifest-v2.json')
report = test.json_file(out / 'actual-patch-sizes.json')
for name in ('sandbox-中文 有空格', 'sandbox-cross-version'):
    assert test.json_file(out / name / '_更新缓存/v2/transaction.json')['state'] == 'committed'
for i in (0, 1):
    assert test.json_file(out / f'reuse-{i}.json')['total'] == 0
assert '取消' in test.json_file(out / 'cancel-download.json')['message']
for name in ('interrupt', 'corrupt'):
    assert test.json_file(out / (name + '.json'))['state'] == 'error'
port_file = out / 'resume-port.txt'
if port_file.exists():
    port_file.unlink()
network_log = out / 'network.jsonl'
server = subprocess.Popen([sys.executable, str(test.HERE / 'test_range_server.py'), '--root', str(out), '--log', str(network_log), '--port-file', str(port_file)], creationflags=test.FLAGS)
try:
    deadline = time.monotonic() + 10
    while not port_file.exists() and time.monotonic() < deadline:
        time.sleep(.1)
    url = 'http://127.0.0.1:' + port_file.read_text()
    test.service_probe(a, out, baseline, test.json_file(out / '0.7.1/AnomalyBureau-manifest-v2.json'), url)
    assert test.json_file(out / 'service-plan.json')['exported_github_live']
    assert test.json_file(out / 'ui-content-result.json')['ok']
    # Also load the real modified model in the exported game, using the same
    # acceptance bootstrap with its own explicitly matched baseline.
    service_root = out / 'sandbox-service'
    target_model = dict(m, baseline=test.json_file(service_root / '_运行文件/active.json')['baseline'])
    target_file = out / 'service-model-target.json'
    test.groups.write_json(target_file, target_model)
    test.helper(service_root, 'download', target_file, out / 'service-model-download.json', url + '/0.7.2')
    content = out / 'model-content-config.json'
    test.groups.write_json(content, dict(version='0.7.2', model_x=1.02, ui_label='安装更新', result=str(out / 'model-content-result.json')))
    model_args = ['--headless', '--audio-driver', 'Dummy', '--log-file', str(out / 'service-model-menu.log'), '--', '--verify', '--distribution-test-exit-seconds=12', '--data-dir=' + str(out / 'service-model-data'), '--distribution-content-check=' + str(content)]
    test.helper(service_root, 'apply', target_file, out / 'service-model-apply.json', os.getpid(), 'd' * 32, *model_args)
    test.wait_child(service_root)
    assert test.json_file(out / 'model-content-result.json')['ok']
    root = out / 'sandbox-cross-version'
    # Use the final optimized launcher for the repair acceptance.
    import shutil
    shutil.copy2(a.release / 'Windows/AnomalyBureau.exe', root / 'AnomalyBureau.exe')
    target = report[1]['changed'][0]['path']
    files = [f for f in m['files'] if f['group'] == 'case1']
    pack = root / '_运行文件/packs' / ('case1-' + test.groups.group_id(files) + '.zip')
    repaired = pack.with_suffix('.repair')
    with zipfile.ZipFile(pack) as old, zipfile.ZipFile(repaired, 'w') as new:
        for name in old.namelist():
            if name != target:
                test.groups.add(new, name, old.read(name))
    os.replace(repaired, pack)
    mf = out / '0.7.2/AnomalyBureau-manifest-v2.json'
    test.helper(root, 'plan', mf, out / 'repair-plan.json')
    assert test.json_file(out / 'repair-plan.json')['bytes'] == report[1]['download_bytes']
    test.helper(root, 'download', mf, out / 'repair-download.json', url + '/0.7.2')
    restart = ['--headless', '--audio-driver', 'Dummy', '--log-file', str(out / 'repair-menu.log'), '--', '--verify', '--distribution-test-exit-seconds=12', '--data-dir=' + str(out / 'repair-menu-data')]
    test.helper(root, 'apply', mf, out / 'repair-apply.json', os.getpid(), 'c' * 32, *restart)
    test.wait_child(root)
    assert test.json_file(root / '_更新缓存/v2/transaction.json')['state'] == 'committed'
    assert (root / '_玩家数据/save_1.json').read_bytes() == b'player-save-sentinel'
    assert (root / '_玩家数据/settings.cfg').read_bytes() == b'player-settings-sentinel'
    normal = [json.loads(line) for line in network_log.read_text().splitlines() if not json.loads(line)['mode'] and json.loads(line)['path'].endswith('.bin')]
    test.groups.write_json(out / 'result.json', dict(ok=True, samples=report, successful_http_ranges=normal,
        interrupted_and_corrupt_retries=True, download_cancel_keeps_old=True, same_version_model_repair=True,
        consecutive_and_cross_version=True, production_panel_service_handoff=True, exported_github_live=True,
        verified_reuse=True, saves_settings_unchanged=True, loaded_ui_and_model_verified=True, continued_after_probe_fixture_fix=True))
    print('RESULT real grouped UI/model/download/service/repair acceptance passed')
finally:
    server.terminate()
    server.wait(10)
