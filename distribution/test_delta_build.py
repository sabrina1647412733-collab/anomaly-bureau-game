"""Small export fixtures exercise the complete grouping -> delta -> consolidation path."""
import argparse
import copy
import json
import zipfile
from pathlib import Path
from build_groups import build
from delta_transport import base

p = argparse.ArgumentParser()
p.add_argument('--output', type=Path, required=True)
a = p.parse_args()
out = a.output.resolve()
if out.drive.lower() != 'f:' or out.exists():
    raise ValueError('Fresh F: output required')
out.mkdir(parents=True)
previous = None
rows = []
for version, ui, model in [('1.0.0', b'UI A', b'Model A'), ('1.0.1', b'UI B', b'Model A'), ('1.0.2', b'UI B', b'Model B'), ('1.0.3', b'UI B', b'Model B')]:
    folder = out / version; folder.mkdir()
    runtime = folder / 'Windows'; runtime.mkdir()
    (runtime / 'AnomalyBureau.Game.exe').write_bytes(b'fixed-engine')
    (runtime / 'AnomalyBureau.Game.pck').write_bytes(b'fixed-bootstrap')
    export = folder / 'export.zip'
    with zipfile.ZipFile(export, 'w') as archive:
        archive.writestr('scripts/ui.gdc', ui)
        archive.writestr('assets/models/model.scn', model)
        archive.writestr('assets/shared.bin', b'unchanged shared data')
        archive.writestr('assets/shared-alias.bin', b'unchanged shared data')
    manifest = build(export, runtime, folder, version, previous_manifest=previous)
    if previous is None:
        manifest = base(folder / 'AnomalyBureau-manifest-v2.json', runtime, folder)
    plan = json.loads((folder / 'publish-plan.json').read_text())
    if previous is not None:
        assert not list(folder.glob('AnomalyBureau-resources-*.bin'))
        assert plan['changed_contents'] == (0 if version == '1.0.3' else 1)
        assert len(plan['assets']) == (2 if version == '1.0.3' else 3)
    previous = folder / 'AnomalyBureau-manifest-v3.json'
    rows.append(manifest)
# UI remains referenced from 1.0.1, model from 1.0.2, shared data from 1.0.0.
sources = {f['path']: f['source_version'] for f in rows[-1]['files']}
assert sources['scripts/ui.gdc'] == '1.0.1'
assert sources['assets/models/model.scn'] == '1.0.2'
assert sources['assets/shared.bin'] == sources['assets/shared-alias.bin'] == '1.0.0'
# A fresh consolidated base removes all historical remote references.
folder = out / '2.0.0'; folder.mkdir()
runtime = folder / 'Windows'; runtime.mkdir()
for name in ('AnomalyBureau.Game.exe', 'AnomalyBureau.Game.pck'):
    (runtime / name).write_bytes((out / '1.0.3/Windows' / name).read_bytes())
build(out / '1.0.3/export.zip', runtime, folder, '2.0.0')
compact = base(folder / 'AnomalyBureau-manifest-v2.json', runtime, folder)
assert all(f['source_version'] == '2.0.0' for f in compact['files'])
assert json.loads((folder / 'publish-plan.json').read_text())['dependencies'] == []
(out / 'result.json').write_text(json.dumps(dict(ok=True, changed_only=True, unchanged_no_patch=True, historical_references=True, duplicate_content_reused=True, consolidation_removes_history=True)))
print('PASS complete grouping/delta pipeline, aliases, no-change publish, consolidation')
