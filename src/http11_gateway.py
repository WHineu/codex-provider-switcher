#!/usr/bin/env python3
"""Loopback-only HTTPS upstream adapter for Codex Responses API providers."""

from __future__ import annotations

import argparse
import http.client
import json
import os
import ssl
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit


MAX_REQUEST_BYTES = 32 * 1024 * 1024
CONNECT_TIMEOUT_SECONDS = 20
STREAM_TIMEOUT_SECONDS = 600
STREAM_CHUNK_BYTES = 16 * 1024
HOP_BY_HOP_HEADERS = {
    "connection", "keep-alive", "proxy-authenticate", "proxy-authorization",
    "te", "trailer", "transfer-encoding", "upgrade",
}


def event(name: str, **fields: object) -> None:
    print(json.dumps({"event": name, **fields}, separators=(",", ":")), flush=True)


class Server(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "CodexProviderAdapter/0.1"
    sys_version = ""

    def log_message(self, _format: str, *_args: object) -> None:
        return

    @property
    def settings(self) -> argparse.Namespace:
        return self.server.settings  # type: ignore[attr-defined]

    def do_GET(self) -> None:  # noqa: N802
        path = urlsplit(self.path).path
        if path == "/healthz":
            self.send_json(200, {
                "status": "ok",
                "provider": self.settings.provider,
                "instance_id": self.settings.instance_id,
                "pid": os.getpid(),
                "upstream": f"{self.settings.upstream_host}:{self.settings.upstream_port}",
            })
            return
        if path == "/v1/models" and self.settings.models_mode == "empty_codex_catalog":
            self.send_json(200, {"models": []})
            return
        self.forward()

    def do_POST(self) -> None:  # noqa: N802
        self.forward()

    def do_PUT(self) -> None:  # noqa: N802
        self.send_json(405, {"error": "method_not_allowed"})

    def do_DELETE(self) -> None:  # noqa: N802
        self.send_json(405, {"error": "method_not_allowed"})

    def send_json(self, status: int, value: dict) -> None:
        body = json.dumps(value, separators=(",", ":")).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(body)
        self.close_connection = True

    def read_body(self) -> bytes | None:
        if self.headers.get("Transfer-Encoding"):
            self.send_json(501, {"error": "chunked_request_not_supported"})
            return None
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            self.send_json(400, {"error": "invalid_content_length"})
            return None
        if length < 0 or length > MAX_REQUEST_BYTES:
            self.send_json(413, {"error": "request_too_large"})
            return None
        return self.rfile.read(length) if length else b""

    def upstream_headers(self) -> dict[str, str]:
        result: dict[str, str] = {}
        for name, value in self.headers.items():
            lowered = name.lower()
            if lowered in HOP_BY_HOP_HEADERS or lowered in {"host", "content-length", "accept-encoding"}:
                continue
            result[name] = value
        result["Host"] = self.settings.upstream_host
        result["Accept-Encoding"] = "identity"
        result["Connection"] = "close"
        return result

    def forward(self) -> None:
        path = urlsplit(self.path).path
        if path not in self.settings.allowed_path:
            self.send_json(404, {"error": "unsupported_path"})
            return
        if self.command not in {"GET", "POST"}:
            self.send_json(405, {"error": "method_not_allowed"})
            return
        body = self.read_body()
        if body is None:
            return

        started = time.monotonic()
        upstream = http.client.HTTPSConnection(
            self.settings.upstream_host,
            self.settings.upstream_port,
            timeout=CONNECT_TIMEOUT_SECONDS,
            context=ssl.create_default_context(),
        )
        response_started = False
        status = 0
        forwarded = 0
        try:
            upstream.request(self.command, self.path, body=body or None, headers=self.upstream_headers())
            response = upstream.getresponse()
            status = response.status
            if upstream.sock:
                upstream.sock.settimeout(STREAM_TIMEOUT_SECONDS)
            self.send_response(response.status, response.reason)
            for name, value in response.getheaders():
                lowered = name.lower()
                if lowered in HOP_BY_HOP_HEADERS or lowered in {"content-length", "server", "date"}:
                    continue
                self.send_header(name, value)
            self.send_header("Transfer-Encoding", "chunked")
            self.send_header("Connection", "close")
            self.send_header("Via", "1.1 codex-provider-adapter")
            self.end_headers()
            response_started = True
            read_available = getattr(response, "read1", response.read)
            while True:
                chunk = read_available(STREAM_CHUNK_BYTES)
                if not chunk:
                    break
                self.wfile.write(f"{len(chunk):X}\r\n".encode("ascii"))
                self.wfile.write(chunk)
                self.wfile.write(b"\r\n")
                self.wfile.flush()
                forwarded += len(chunk)
            self.wfile.write(b"0\r\n\r\n")
            self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError):
            event("client_disconnected", method=self.command, path=path, upstream_status=status or None)
        except Exception as exc:
            event("gateway_error", method=self.command, path=path, error_type=type(exc).__name__)
            if not response_started:
                self.send_json(502, {"error": "upstream_connection_failed"})
        finally:
            upstream.close()
            self.close_connection = True
            event(
                "request_complete",
                method=self.command,
                path=path,
                status=status or None,
                response_bytes=forwarded,
                elapsed_ms=round((time.monotonic() - started) * 1000),
            )


def parser() -> argparse.ArgumentParser:
    value = argparse.ArgumentParser(description=__doc__)
    value.add_argument("--provider", required=True)
    value.add_argument("--instance-id", required=True)
    value.add_argument("--listen-port", required=True, type=int)
    value.add_argument("--upstream-host", required=True)
    value.add_argument("--upstream-port", type=int, default=443)
    value.add_argument("--allowed-path", action="append", required=True)
    value.add_argument("--models-mode", choices=("proxy", "empty_codex_catalog"), default="proxy")
    return value


def main() -> int:
    settings = parser().parse_args()
    if not 1024 <= settings.listen_port <= 65535:
        print("listen port must be between 1024 and 65535", file=sys.stderr)
        return 2
    server = Server(("127.0.0.1", settings.listen_port), Handler)
    server.settings = settings  # type: ignore[attr-defined]
    event(
        "adapter_started",
        provider=settings.provider,
        listen=f"127.0.0.1:{settings.listen_port}",
        upstream=f"{settings.upstream_host}:{settings.upstream_port}",
    )
    try:
        server.serve_forever(poll_interval=0.25)
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
        event("adapter_stopped", provider=settings.provider)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
