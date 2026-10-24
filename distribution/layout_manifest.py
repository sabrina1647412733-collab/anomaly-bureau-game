import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()
# An explicit install-only tree, never add player data or update caches.
allowed = ['AnomalyBureau.exe', 'AnomalyBureau.Game.exe', 'AnomalyBureau.Game.pck', 'AnomalyBureau.ico',
           '开始游玩说明.txt', '兼容模式启动.bat', '自动更新说明.txt', 'Godot-LICENSE.txt', 'Godot-COPYRIGHT.txt',
           'NotoSansSC-LICENSE.txt', 'credits.txt', 'CC-BY-4.0.txt', 'CC0-1.0.txt', '_运行文件/active.json']
allowed += [p.relative_to(root).as_posix() for p in (root / '_运行文件/packs').glob('*.zip')]
files = []
for name in sorted(allowed):
    p = root / name
    files.append(dict(path=name, size=p.stat().st_size, sha256=hashlib.file_digest(p.open('rb'), 'sha256').hexdigest()))
(root / 'layout.json').write_text(json.dumps(dict(protocol=1, files=files), ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
