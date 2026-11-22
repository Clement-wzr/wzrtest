#!/usr/bin/env python3
"""EVERGREEN local preview server.

Camera access and ES modules generally require a secure context. localhost is a
secure context, so this server is enough. Everything runs locally.
"""
from __future__ import annotations

import http.server
import os
import sys
import threading
import webbrowser
from pathlib import Path

ROOT = Path(__file__).resolve().parent
os.chdir(ROOT)


class Handler(http.server.SimpleHTTPRequestHandler):
    # Make sure the browser receives correct module and WebAssembly MIME types
    # even when the local Python installation has a minimal mimetypes table.
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".js": "application/javascript",
        ".mjs": "application/javascript",
        ".wasm": "application/wasm",
        ".task": "application/octet-stream",
        ".json": "application/json",
        ".html": "text/html; charset=utf-8",
        ".css": "text/css; charset=utf-8",
    }

    def end_headers(self) -> None:
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        super().end_headers()

    def log_message(self, format: str, *args) -> None:
        sys.stdout.write(f"  {format % args}\n")
        sys.stdout.flush()


def main() -> None:
    preferred = 8000
    httpd = None
    for port in range(preferred, preferred + 12):
        try:
            httpd = http.server.ThreadingHTTPServer(("127.0.0.1", port), Handler)
            break
        except OSError:
            continue

    if httpd is None:
        print("无法启动本地服务器：8000–8011 端口似乎都被占用了。")
        input("按 Enter 退出…")
        return

    port = httpd.server_address[1]
    url = f"http://127.0.0.1:{port}/"
    print()
    print("  EVERGREEN · 手势粒子圣诞树")
    print("  ------------------------------------------")
    print(f"  本地地址: {url}")
    print("  摄像头画面仅在本机处理，不会上传。")
    print("  关闭此窗口即可停止服务器。")
    print()
    print("  提示：在页面右上角点击「开启手势」，首次载入手势引擎约需几秒。")
    print()

    if os.environ.get("EVERGREEN_NO_BROWSER") != "1":
        threading.Timer(0.7, lambda: webbrowser.open(url)).start()
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n服务器已停止。")
    finally:
        httpd.server_close()


if __name__ == "__main__":
    main()
