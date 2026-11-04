import json
import os
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, quote, urlparse

DIR = os.path.dirname(os.path.abspath(__file__))
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 47219
HOME = os.path.realpath(os.path.expanduser("~"))
# Only these Host headers are answered, which blocks DNS-rebinding pages from reading PDFs.
HOSTS = {f"127.0.0.1:{PORT}", f"localhost:{PORT}"}


def pdf_path(qs):
    raw = qs.get("pdf", [""])[0]
    p = os.path.realpath(raw)
    if raw and p.lower().endswith(".pdf") and p.startswith(HOME + os.sep) and os.path.isfile(p):
        return p
    return None


class Handler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def send(self, code, body=b"", ctype="text/plain", extra=None, head=False):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        if not head:
            self.wfile.write(body)

    def route(self, head):
        if self.headers.get("Host") not in HOSTS:
            return self.send(403, b"forbidden", head=head)
        url = urlparse(self.path)
        qs = parse_qs(url.query)
        if url.path == "/ping":
            return self.send(200, b"ok", head=head)
        p = pdf_path(qs)
        if p is None:
            return self.send(404, b"not found", head=head)
        if url.path == "/pdf":
            st = os.stat(p)
            tag = f'"{st.st_mtime_ns}-{st.st_size}"'
            body = b"" if head else open(p, "rb").read()
            return self.send(200, body, "application/pdf", {"ETag": tag}, head)
        if url.path == "/view":
            src = "/pdf?pdf=" + quote(p)
            with open(os.path.join(DIR, "head.html"), "rb") as f:
                top = f.read()
            with open(os.path.join(DIR, "tail.html"), "rb") as f:
                bottom = f.read()
            mid = (
                "</script>\n<script>window.__pdfviewSrc=%s;document.title=%s</script>\n"
                % (json.dumps(src), json.dumps(os.path.basename(p)))
            ).encode()
            return self.send(200, top + mid + bottom, "text/html; charset=utf-8", head=head)
        return self.send(404, b"not found", head=head)

    def do_GET(self):
        self.route(False)

    def do_HEAD(self):
        self.route(True)


if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
