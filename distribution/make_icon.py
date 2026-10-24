"""Format conversion of the approved artwork; no generative redesign."""
import argparse
from pathlib import Path
from PIL import Image

if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--source', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args()
    image = Image.open(a.source).convert('RGBA')
    a.output.parent.mkdir(parents=True, exist_ok=True)
    image.save(a.output, format='ICO', sizes=[(s, s) for s in (16, 24, 32, 48, 64, 128, 256)])
