#!/usr/bin/env python3
"""
Self-contained local HTTP test server and runner for euLibCurl & euLibCurlAsync.

Usage (from the repository root):
    python tests/run_tests.py
"""

import http.server
import os
import re
import shutil
import subprocess
import sys
import threading
import time
import urllib.parse


class LocalTestHandler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, format, *args):
        pass

    def _send_bytes(self, code, data, content_type="text/plain; charset=utf-8", extra_headers=None):
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        if extra_headers:
            for k, v in extra_headers.items():
                self.send_header(k, v)
        self.end_headers()
        if self.command != "HEAD":
            try:
                self.wfile.write(data)
            except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError, OSError):
                pass

    def _handle_echo(self):
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length) if length > 0 else b""
        lines = [f"METHOD={self.command}", f"PATH={self.path}"]
        for k, v in self.headers.items():
            lines.append(f"{k}: {v}")
        lines.append("BODY=" + body.decode("utf-8", errors="replace"))
        self._send_bytes(
            200,
            ("\n".join(lines)).encode("utf-8"),
            extra_headers={"X-Server-Header": "euLibCurl-8.15"},
        )

    def do_HEAD(self):
        self._handle_echo()

    def do_POST(self):
        if self.path.startswith("/multipart"):
            length = int(self.headers.get("Content-Length", "0"))
            body = self.rfile.read(length) if length > 0 else b""
            self._send_bytes(200, body, "text/plain")
        else:
            self._handle_echo()

    def do_PUT(self):
        self._handle_echo()

    def do_PATCH(self):
        self._handle_echo()

    def do_DELETE(self):
        self._handle_echo()

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        qs = urllib.parse.parse_qs(parsed.query)

        if parsed.path == "/slow":
            total = 30000
            chunk = b"X" * 3000
            self.send_response(200)
            self.send_header("Content-Type", "application/octet-stream")
            self.send_header("Content-Length", str(total))
            self.end_headers()
            try:
                for _ in range(10):
                    self.wfile.write(chunk)
                    self.wfile.flush()
                    time.sleep(0.03)
            except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError, OSError):
                pass
        elif parsed.path == "/delay":
            ms = int(qs.get("ms", ["100"])[0])
            time.sleep(ms / 1000.0)
            self._send_bytes(200, f"delayed {ms}ms".encode("utf-8"))
        elif parsed.path == "/file":
            self._send_bytes(200, b"B" * 16384, "application/octet-stream")
        elif parsed.path == "/empty":
            self._send_bytes(200, b"", "text/plain")
        elif parsed.path == "/range":
            full = (b"A" * 8192) + (b"C" * 8192)
            rng = self.headers.get("Range", "")
            if rng.startswith("bytes="):
                spec = rng[6:].split(",")[0]
                start_s, end_s = spec.split("-")
                start = int(start_s) if start_s else 0
                end = int(end_s) if end_s else len(full) - 1
                part = full[start:end + 1]
                self._send_bytes(
                    206,
                    part,
                    "application/octet-stream",
                    {"Content-Range": f"bytes {start}-{end}/{len(full)}"},
                )
            else:
                self._send_bytes(200, full, "application/octet-stream")
        elif parsed.path == "/redirect":
            self.send_response(302)
            self.send_header("Location", "/echo")
            self.send_header("Content-Length", "0")
            self.end_headers()
        else:
            self._handle_echo()


class QuietThreadingHTTPServer(http.server.ThreadingHTTPServer):
    def handle_error(self, request, client_address):
        # Expected client-aborted sockets during cancel/timeout/on_chunk tests
        pass


def find_eui():
    exe = shutil.which("eui") or shutil.which("eui.exe")
    if exe:
        return exe
    for candidate in (r"C:\Euphoria\bin\eui.exe", "/usr/local/bin/eui", "/usr/bin/eui"):
        if os.path.exists(candidate):
            return candidate
    raise RuntimeError("OpenEuphoria interpreter 'eui' not found in PATH.")


def parse_summary(log_path):
    if not os.path.exists(log_path):
        return None
    text = open(log_path, "r", encoding="utf-8", errors="replace").read()
    m = re.search(r'"summary",\s*(\d+),\s*(\d+),\s*(\d+)', text)
    if not m:
        return None
    return int(m.group(1)), int(m.group(2)), int(m.group(3))


def main():
    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    eui = find_eui()
    log_path = os.path.join(repo_root, "unittest.log")

    server = QuietThreadingHTTPServer(("127.0.0.1", 0), LocalTestHandler)
    port = server.server_address[1]
    threading.Thread(target=server.serve_forever, daemon=True).start()
    base_url = f"http://127.0.0.1:{port}"
    print(f"Local test server listening at {base_url}")

    suites = [
        (os.path.join("tests", "t_eulibcurl.e"), [base_url]),
        (os.path.join("tests", "t_eulibcurl_async.e"), [base_url]),
    ]

    overall_rc = 0
    total_all = 0
    failed_all = 0

    for test_file, extra in suites:
        if os.path.exists(log_path):
            os.remove(log_path)
        cmd = [eui, test_file, "-log"] + extra
        print(f"\n==> Running {test_file} ...")
        res = subprocess.run(cmd, cwd=repo_root, capture_output=True, text=True)
        summary = parse_summary(log_path)
        if summary:
            total, failed, passed = summary
            total_all += total
            failed_all += failed
            print(f"    Result: {passed}/{total} passed, {failed} failed (exit={res.returncode})")
        else:
            print(f"    Result: exit={res.returncode} (no unittest.log summary found)")
        if res.stdout.strip():
            print(res.stdout.strip())
        if res.stderr.strip():
            print("    STDERR:", res.stderr.strip())
        if res.returncode != 0 or (summary and summary[1] != 0):
            overall_rc = 1

    if os.path.exists(log_path):
        os.remove(log_path)
    server.shutdown()

    print(f"\n=== Overall: {total_all - failed_all}/{total_all} passed, {failed_all} failed ===")
    sys.exit(overall_rc)


if __name__ == "__main__":
    main()
