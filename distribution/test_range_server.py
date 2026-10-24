"""Local release fixture with real Range reads and controllable failure modes."""
import argparse
import json
import re
import threading
import time
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from pathlib import Path
from urllib.parse import unquote

p = argparse.ArgumentParser()
p.add_argument('--root', type=Path, required=True)
p.add_argument('--log', type=Path, required=True)
p.add_argument('--port-file', type=Path, required=True)
a = p.parse_args()
root = a.root.resolve()
lock = threading.Lock()

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_args):
        pass

    def do_GET(self):
        name = unquote(self.path.split('?', 1)[0]).lstrip('/')
        path = (root / name).resolve()
        if not path.is_relative_to(root) or not path.is_file():
            self.send_error(404)
            return
        size = path.stat().st_size
        match = re.fullmatch(r'bytes=(\d+)-(\d+)', self.headers.get('Range', ''))
        start, end = (int(match[1]), int(match[2])) if match else (0, size - 1)
        if start < 0 or end >= size or end < start:
            self.send_error(416)
            return
        mode_file = root / 'server-mode.txt'
        mode = mode_file.read_text().strip() if mode_file.exists() else ''
        length = end - start + 1
        self.send_response(206 if match else 200)
        self.send_header('Content-Length', str(length))
        if match:
            self.send_header('Content-Range', f'bytes {start}-{end}/{size}')
        self.end_headers()
        sent = 0
        try:
            with path.open('rb') as source:
                source.seek(start)
                while sent < length:
                    data = source.read(min(4096, length - sent))
                    if mode == 'corrupt' and sent == 0:
                        data = bytes([data[0] ^ 1]) + data[1:]
                    self.wfile.write(data)
                    self.wfile.flush()
                    sent += len(data)
                    if mode == 'interrupt':
                        self.close_connection = True
                        break
                    if mode == 'slow':
                        time.sleep(0.15)
        except (BrokenPipeError, ConnectionResetError):
            pass
        with lock:
            with a.log.open('a', encoding='utf-8') as log:
                log.write(json.dumps(dict(path=name, start=start, end=end, expected=length, sent=sent, mode=mode)) + '\n')

server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
a.port_file.write_text(str(server.server_port))
server.serve_forever()
