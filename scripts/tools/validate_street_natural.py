"""Geometry/route-contract checks for the 2026-10-24 street polish.

No image scores or claims about realism: these checks prove the grass is rooted
to the authored surfaces, new plant meshes are valid, and old routes/colliders
have not changed. Godot frame/physical route review is a separate acceptance.
Usage: python validate_street_natural.py PROJECT REPORT_DIRECTORY BEFORE_DIRECTORY
"""
import hashlib
import json
import math
import struct
import sys
from collections import Counter
from pathlib import Path


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def glb(path):
    content = path.read_bytes()
    magic, version, size = struct.unpack_from('<4sII', content)
    assert magic == b'glTF' and version == 2 and size == len(content), str(path)
    json_size, json_type = struct.unpack_from('<II', content, 12)
    assert json_type == 0x4e4f534a
    doc = json.loads(content[20:20 + json_size].decode('utf8'))
    return doc, content


def main():
    root, output, before = map(Path, sys.argv[1:4])
    folder = root / 'assets/town/renewal'
    current = read(folder / 'street_manifest.json')
    old = read(before / 'street_manifest.json')
    hero = read(folder / 'hero_props/hero_props_manifest.json')
    old_hero = read(before / 'hero_props_manifest.json')
    plan = read(root / '_tools/street_surface_plan.json')
    checks = []

    def check(ok, label):
        checks.append({'label': label, 'passed': bool(ok)})

    for name in ['collision', 'river_bed', 'graded_collision_indices',
                 'graded_collision_triangles', 'road_grade', 'props', 'shop_recesses']:
        check(current.get(name) == old.get(name), 'Existing route/physical contract preserved: ' + name)
    check(hero['props'] == old_hero['props'], 'All four hero collider declarations are unchanged')
    check(hero['npc_swept_corridors'] == old_hero['npc_swept_corridors'], 'Both NPC swept foot corridors remain unchanged')
    check(len(hero['small_weeds']) == 17, 'All 17 authored foreground plant anchors remain')
    check([p['seed'] for p in hero['small_weeds']] == [p['seed'] for p in old_hero['small_weeds']],
          'Foreground plant identity/placement anchors retained')
    check(len(hero['wall_joint_plants']) == 4, 'Four old broad upright bundles replaced as well')
    check(len(hero['fallen_leaves']) == 11, 'Exactly 11 foreground dead leaves, rather than a litter field')
    check(hero['counts']['triangles'] < 60000, 'Foreground meshes stay below the original 60k triangle budget')
    check(hero['counts']['material_batches'] == 20, 'Foreground material batch budget remains 20')
    check(hero['validation']['zero_area_polygons'] == 0, 'No degenerate foreground polygons')
    check(len(current['chunks']) == len(old['chunks']) == 92, 'Whole town remains in 92 spatial chunks')
    check(current['counts']['buildings'] == old['counts']['buildings'] == 414, '414 ordinary buildings retain their existing sites')
    check(current['counts']['poles'] == old['counts']['poles'] == 62, '62 existing utility poles retained')
    check(current['counts']['trees'] == old['counts']['trees'] == 129, '129 existing trees retained')
    check(current['counts']['grass_tufts'] < old['counts']['grass_tufts'] * .60,
          'Global vegetation is sparser than the old uniform placement')
    species = Counter(p['species'] for p in current['vegetation'])
    check(len(species) == 3, 'Three distinct ground plant forms are exported')
    check(all(not p['collision'] for p in current['vegetation']), 'Ground plants never add collision')
    check(all(p['height_limit_m'] < .17 for p in current['vegetation']), 'All global wall-joint plants remain below 17 cm')
    check(all(math.isclose(p['root'][1], .0355 if p['surface'] == 'paving' else -.0235)
              for p in current['vegetation']), 'Roots use the actual paving/bare-ground render plane')
    check(len(current['recessed_frontages']) > 350, 'Real sealed front window recesses replace pasted-on glazing across ordinary housing')
    check(all(math.isclose(p['depth_m'], .18) for p in current['recessed_frontages']), 'All new window recesses use the established 18 cm depth')
    totals = Counter()
    by_kind = Counter()
    colour_accessors = 0
    plant_positions = []
    files = current['chunks'] + hero['chunks']
    for uri in files:
        path = root / uri.removeprefix('res://')
        doc, raw = glb(path)
        totals['bytes'] += len(raw)
        for mesh in doc.get('meshes', []):
            name = mesh.get('name', '').split('.')[0]
            for prim in mesh['primitives']:
                position = doc['accessors'][prim['attributes']['POSITION']]
                totals['vertices'] += position['count']
                count = doc['accessors'][prim['indices']]['count']
                check(count % 3 == 0, 'Exported triangle indices valid: ' + path.name + '/' + name)
                totals['triangles'] += count // 3
                if name in ['verge_green', 'grass']:
                    by_kind[name] += count // 3
                    check('COLOR_0' in prim['attributes'], 'Plant vertex colours survive export: ' + path.name)
                    colour_accessors += 'COLOR_0' in prim['attributes']
                    check(all(math.isfinite(v) for v in position['min'] + position['max']),
                          'Finite plant bounds: ' + path.name)
                    plant_positions.append({'file': path.name, 'minimum': position['min'], 'maximum': position['max']})
    check(by_kind['grass'] == 0, 'Old single triangle grass and spike-pot material is no longer exported')
    check(by_kind['verge_green'] > 0, 'Bent foliage is present in actual runtime GLBs')
    sources = []
    for name in ['huichao_street_v2.blend', 'street_hero_props_v1.blend']:
        path = root / 'source_art' / name
        check(path.stat().st_size < 100 * 1024 * 1024, 'Editable compressed source fits GitHub per-file limit: ' + name)
        sources.append({'file': name, 'bytes': path.stat().st_size,
                        'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    result = {'passed': sum(c['passed'] for c in checks), 'failed': sum(not c['passed'] for c in checks),
              'checks': checks, 'species': dict(species), 'geometry': dict(totals),
              'plant_triangles': dict(by_kind), 'plant_colour_accessors': colour_accessors,
              'plant_bounds': plant_positions, 'source_blends': sources,
              'limits': 'Static/source contract checks. Not Godot screenshot review, physical player route, frame timing or human realism acceptance.'}
    output.mkdir(parents=True, exist_ok=True)
    (output / 'static_geometry_validation.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf8')
    print(json.dumps({k: result[k] for k in ['passed', 'failed', 'species', 'geometry', 'plant_triangles']}, ensure_ascii=False))
    return 1 if result['failed'] else 0


if __name__ == '__main__':
    raise SystemExit(main())
