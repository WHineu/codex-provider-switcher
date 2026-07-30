#!/usr/bin/env python3
"""Switch between configured Codex providers with optional local adapters."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import stat
import subprocess
import sys
import tempfile
import time
import tomllib
import urllib.error
import urllib.request
import uuid


ROOT_PROVIDER_RE = re.compile(r"^(\s*)model_provider\s*=\s*([^#\r\n]+?)(\s*(?:#.*)?(?:\r?\n)?)$")
PROVIDER_ID_RE = re.compile(r"^[A-Za-z0-9_.-]+$")
ADAPTER_TYPE = "http11_gateway"


class SwitcherError(RuntimeError):
    """A user-actionable switcher failure."""


@dataclass(frozen=True)
class Provider:
    provider_id: str
    name: str
    base_url: str


@dataclass(frozen=True)
class Adapter:
    provider_id: str
    listen_port: int
    upstream_host: str
    upstream_port: int
    allowed_paths: tuple[str, ...]
    models_mode: str


def default_config_path() -> Path:
    return Path.home() / ".codex" / "config.toml"


def default_adapters_path() -> Path:
    return Path.home() / ".config" / "codex-provider-switcher" / "adapters.toml"


def default_state_dir() -> Path:
    override = os.environ.get("CODEX_PROVIDER_SWITCHER_STATE_DIR")
    if override:
        return Path(override)
    if sys.platform == "darwin":
        return Path.home() / "Library" / "Application Support" / "Codex Provider Switcher" / "state"
    xdg_state = os.environ.get("XDG_STATE_HOME")
    return Path(xdg_state) / "codex-provider-switcher" if xdg_state else Path.home() / ".local" / "state" / "codex-provider-switcher"


def load_toml(path: Path, *, required: bool = True) -> dict:
    if not path.exists():
        if required:
            raise SwitcherError(f"File not found: {path}")
        return {}
    if not path.is_file():
        raise SwitcherError(f"Not a regular file: {path}")
    try:
        with path.open("rb") as handle:
            value = tomllib.load(handle)
    except (OSError, tomllib.TOMLDecodeError) as exc:
        raise SwitcherError(f"Cannot parse TOML file {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise SwitcherError(f"TOML root must be a table: {path}")
    return value


def providers_from_config(config: dict) -> dict[str, Provider]:
    raw = config.get("model_providers")
    if not isinstance(raw, dict) or not raw:
        raise SwitcherError("No [model_providers.*] tables were found")
    result: dict[str, Provider] = {}
    for provider_id, details in raw.items():
        if not isinstance(provider_id, str) or not PROVIDER_ID_RE.fullmatch(provider_id):
            raise SwitcherError(f"Unsupported provider identifier: {provider_id!r}")
        if not isinstance(details, dict):
            raise SwitcherError(f"Provider {provider_id!r} must be a TOML table")
        name = details.get("name")
        base_url = details.get("base_url")
        result[provider_id] = Provider(
            provider_id=provider_id,
            name=name if isinstance(name, str) and name else provider_id,
            base_url=base_url if isinstance(base_url, str) else "",
        )
    return result


def current_provider(config: dict, providers: dict[str, Provider]) -> str:
    current = config.get("model_provider")
    if not isinstance(current, str) or not current:
        raise SwitcherError("Top-level model_provider is missing or invalid")
    if current not in providers:
        raise SwitcherError(f"Current provider {current!r} has no [model_providers.{current}] table")
    return current


def parse_adapter(provider_id: str, raw: object) -> Adapter:
    if not isinstance(raw, dict):
        raise SwitcherError(f"Adapter for {provider_id!r} must be a TOML table")
    adapter_type = raw.get("type")
    if adapter_type != ADAPTER_TYPE:
        raise SwitcherError(f"Adapter for {provider_id!r} has unsupported type {adapter_type!r}")
    port = raw.get("listen_port")
    upstream_host = raw.get("upstream_host")
    upstream_port = raw.get("upstream_port", 443)
    allowed_paths = raw.get("allowed_paths", ["/v1/models", "/v1/responses"])
    models_mode = raw.get("models_mode", "proxy")
    if not isinstance(port, int) or isinstance(port, bool) or not 1024 <= port <= 65535:
        raise SwitcherError(f"Adapter for {provider_id!r} requires listen_port between 1024 and 65535")
    if not isinstance(upstream_host, str) or not re.fullmatch(r"[A-Za-z0-9.-]+", upstream_host):
        raise SwitcherError(f"Adapter for {provider_id!r} has an invalid upstream_host")
    if not isinstance(upstream_port, int) or isinstance(upstream_port, bool) or not 1 <= upstream_port <= 65535:
        raise SwitcherError(f"Adapter for {provider_id!r} has an invalid upstream_port")
    if not isinstance(allowed_paths, list) or not allowed_paths:
        raise SwitcherError(f"Adapter for {provider_id!r} requires allowed_paths")
    normalized: list[str] = []
    for path in allowed_paths:
        if not isinstance(path, str) or not path.startswith("/") or "?" in path or "#" in path:
            raise SwitcherError(f"Adapter for {provider_id!r} has an invalid allowed path")
        normalized.append(path)
    if models_mode not in {"proxy", "empty_codex_catalog"}:
        raise SwitcherError(f"Adapter for {provider_id!r} has an invalid models_mode")
    return Adapter(provider_id, port, upstream_host, upstream_port, tuple(normalized), models_mode)


def adapters_from_config(path: Path, providers: dict[str, Provider]) -> dict[str, Adapter]:
    payload = load_toml(path, required=False)
    raw_providers = payload.get("providers", {})
    if not isinstance(raw_providers, dict):
        raise SwitcherError("adapters.toml [providers] must be a table")
    result: dict[str, Adapter] = {}
    used_ports: set[int] = set()
    for provider_id, raw in raw_providers.items():
        if provider_id not in providers:
            raise SwitcherError(f"Adapter references unknown provider {provider_id!r}")
        adapter = parse_adapter(provider_id, raw)
        if adapter.listen_port in used_ports:
            raise SwitcherError(f"Multiple adapters use local port {adapter.listen_port}")
        used_ports.add(adapter.listen_port)
        result[provider_id] = adapter
    return result


def ensure_private_dir(path: Path) -> Path:
    path.mkdir(parents=True, exist_ok=True, mode=0o700)
    info = path.stat()
    if info.st_uid != os.getuid():
        raise SwitcherError(f"State directory is not owned by the current user: {path}")
    if stat.S_IMODE(info.st_mode) & 0o077:
        os.chmod(path, 0o700)
    return path


def state_path(state_dir: Path, provider_id: str) -> Path:
    digest = hashlib.sha256(provider_id.encode("utf-8")).hexdigest()[:16]
    return state_dir / f"adapter-{digest}.json"


def safe_write_json(path: Path, value: dict) -> None:
    if path.is_symlink():
        raise SwitcherError(f"Refusing to replace symbolic link: {path}")
    fd, tmp_name = tempfile.mkstemp(prefix=path.name + ".", dir=path.parent)
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(value, handle, separators=(",", ":"))
            handle.write("\n")
        os.replace(tmp_name, path)
    except Exception:
        try:
            os.unlink(tmp_name)
        except FileNotFoundError:
            pass
        raise


def read_state(path: Path) -> dict | None:
    if not path.exists():
        return None
    if path.is_symlink() or path.stat().st_uid != os.getuid():
        raise SwitcherError(f"Unsafe adapter state file: {path}")
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise SwitcherError(f"Cannot read adapter state {path}: {exc}") from exc
    return value if isinstance(value, dict) else None


def health(adapter: Adapter, timeout: float = 1.5) -> dict | None:
    url = f"http://127.0.0.1:{adapter.listen_port}/healthz"
    try:
        with urllib.request.urlopen(url, timeout=timeout) as response:
            value = json.load(response)
    except (OSError, urllib.error.URLError, json.JSONDecodeError):
        return None
    return value if isinstance(value, dict) else None


def health_matches(value: dict | None, adapter: Adapter, instance_id: str | None = None) -> bool:
    if not value:
        return False
    matches = (
        value.get("status") == "ok"
        and value.get("provider") == adapter.provider_id
        and value.get("upstream") == f"{adapter.upstream_host}:{adapter.upstream_port}"
    )
    return matches and (instance_id is None or value.get("instance_id") == instance_id)


def gateway_script() -> Path:
    path = Path(__file__).resolve().with_name("http11_gateway.py")
    if not path.is_file():
        raise SwitcherError(f"Bundled gateway is missing: {path}")
    return path


def start_adapter(adapter: Adapter, state_dir: Path) -> str:
    ensure_private_dir(state_dir)
    path = state_path(state_dir, adapter.provider_id)
    existing = read_state(path)
    if existing and health_matches(health(adapter), adapter, existing.get("instance_id")):
        return "already running"
    occupied = health(adapter)
    if occupied is not None:
        raise SwitcherError(f"Local port {adapter.listen_port} is occupied by an unexpected service")
    if existing:
        path.unlink(missing_ok=True)

    instance_id = uuid.uuid4().hex
    log_path = state_dir / (path.stem + ".log")
    flags = os.O_WRONLY | os.O_CREAT | os.O_APPEND
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    log_fd = os.open(log_path, flags, 0o600)
    args = [
        sys.executable,
        str(gateway_script()),
        "--provider", adapter.provider_id,
        "--instance-id", instance_id,
        "--listen-port", str(adapter.listen_port),
        "--upstream-host", adapter.upstream_host,
        "--upstream-port", str(adapter.upstream_port),
        "--models-mode", adapter.models_mode,
    ]
    for allowed_path in adapter.allowed_paths:
        args.extend(["--allowed-path", allowed_path])
    null_fd = os.open(os.devnull, os.O_RDONLY)
    try:
        process_id = os.posix_spawn(
            sys.executable,
            args,
            os.environ,
            file_actions=[
                (os.POSIX_SPAWN_DUP2, null_fd, 0),
                (os.POSIX_SPAWN_DUP2, log_fd, 1),
                (os.POSIX_SPAWN_DUP2, log_fd, 2),
            ],
            setsid=True,
        )
    finally:
        os.close(null_fd)
        os.close(log_fd)
    safe_write_json(path, {
        "provider": adapter.provider_id,
        "pid": process_id,
        "instance_id": instance_id,
        "listen_port": adapter.listen_port,
        "upstream": f"{adapter.upstream_host}:{adapter.upstream_port}",
        "gateway_script": str(gateway_script()),
    })
    for _ in range(40):
        if health_matches(health(adapter, 0.4), adapter, instance_id):
            return "started"
        try:
            finished, _status = os.waitpid(process_id, os.WNOHANG)
        except ChildProcessError:
            finished = 0
        if finished == process_id:
            break
        time.sleep(0.1)
    try:
        os.kill(process_id, signal.SIGTERM)
    except ProcessLookupError:
        pass
    path.unlink(missing_ok=True)
    raise SwitcherError(f"Adapter for {adapter.provider_id!r} did not pass its health check; log: {log_path}")


def stop_adapter(adapter: Adapter, state_dir: Path) -> str:
    path = state_path(state_dir, adapter.provider_id)
    state = read_state(path)
    if not state:
        return "not owned"
    pid = state.get("pid")
    instance_id = state.get("instance_id")
    if not isinstance(pid, int) or not isinstance(instance_id, str):
        raise SwitcherError(f"Adapter state is incomplete: {path}")
    value = health(adapter)
    if not health_matches(value, adapter, instance_id):
        raise SwitcherError("Adapter identity check failed; refusing to stop the recorded PID")
    if value.get("pid") != pid:
        raise SwitcherError("Adapter PID does not match the owned gateway instance; refusing to stop it")
    try:
        os.kill(pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    for _ in range(30):
        try:
            os.kill(pid, 0)
        except ProcessLookupError:
            break
        time.sleep(0.1)
    try:
        os.waitpid(pid, os.WNOHANG)
    except ChildProcessError:
        pass
    path.unlink(missing_ok=True)
    return "stopped"


def replace_root_provider(text: str, target: str) -> str:
    lines = text.splitlines(keepends=True)
    found = 0
    in_table = False
    output: list[str] = []
    for line in lines:
        if re.match(r"^\s*\[", line):
            in_table = True
        match = ROOT_PROVIDER_RE.match(line) if not in_table else None
        if match:
            found += 1
            output.append(f'{match.group(1)}model_provider = "{target}"{match.group(3)}')
        else:
            output.append(line)
    if found != 1:
        raise SwitcherError(f"Top-level model_provider must appear exactly once; found {found}")
    return "".join(output)


def atomic_write(path: Path, text: str, mode: int) -> None:
    fd, tmp_name = tempfile.mkstemp(prefix=path.name + ".switch.", dir=path.parent)
    try:
        os.fchmod(fd, mode)
        with os.fdopen(fd, "w", encoding="utf-8", newline="") as handle:
            handle.write(text)
            handle.flush()
            os.fsync(handle.fileno())
        load_toml(Path(tmp_name))
        os.replace(tmp_name, path)
    except Exception:
        try:
            os.unlink(tmp_name)
        except FileNotFoundError:
            pass
        raise


def switch_provider(config_path: Path, adapters_path: Path, target: str, confirmed: bool) -> dict:
    config_path = config_path.expanduser()
    if config_path.is_symlink():
        raise SwitcherError(f"Refusing to modify symbolic link: {config_path}")
    config_path = config_path.resolve()
    adapters_path = adapters_path.expanduser().resolve()
    lock_path = config_path.with_suffix(config_path.suffix + ".switcher.lock")
    lock_fd = os.open(lock_path, os.O_RDWR | os.O_CREAT, 0o600)
    try:
        with os.fdopen(lock_fd, "w") as lock_handle:
            fcntl.flock(lock_handle, fcntl.LOCK_EX)
            config = load_toml(config_path)
            providers = providers_from_config(config)
            current = current_provider(config, providers)
            if target not in providers:
                raise SwitcherError(f"Unknown provider {target!r}; use the list command")
            adapters = adapters_from_config(adapters_path, providers)
            state_dir = default_state_dir()
            adapter_status = None
            if current == target:
                if target in adapters:
                    adapter_status = start_adapter(adapters[target], state_dir)
                return {"changed": False, "current": current, "adapter": adapter_status}
            if not confirmed:
                raise SwitcherError("Switching requires --confirm-no-active-tasks")
            if target in adapters:
                adapter_status = start_adapter(adapters[target], state_dir)
            original = config_path.read_text(encoding="utf-8")
            mode = stat.S_IMODE(config_path.stat().st_mode)
            updated = replace_root_provider(original, target)
            try:
                atomic_write(config_path, updated, mode)
                verified = load_toml(config_path)
                if current_provider(verified, providers_from_config(verified)) != target:
                    raise SwitcherError("Post-write provider verification failed")
            except Exception as exc:
                atomic_write(config_path, original, mode)
                if target in adapters and adapter_status == "started":
                    stop_adapter(adapters[target], state_dir)
                raise SwitcherError(f"Switch failed and the original configuration was restored: {exc}") from exc
            warning = None
            if current in adapters:
                try:
                    stop_adapter(adapters[current], state_dir)
                except SwitcherError as exc:
                    warning = str(exc)
            return {
                "changed": True,
                "previous": current,
                "current": target,
                "adapter": adapter_status,
                "warning": warning,
            }
    finally:
        # The lock file is intentionally retained to avoid unlink races.
        pass


def snapshot(config_path: Path, adapters_path: Path) -> dict:
    config = load_toml(config_path.expanduser())
    providers = providers_from_config(config)
    current = current_provider(config, providers)
    adapters = adapters_from_config(adapters_path.expanduser(), providers)
    rows = []
    for provider_id in sorted(providers):
        provider = providers[provider_id]
        adapter = adapters.get(provider_id)
        rows.append({
            "id": provider_id,
            "name": provider.name,
            "base_url": provider.base_url,
            "current": provider_id == current,
            "adapter": ADAPTER_TYPE if adapter else None,
            "adapter_healthy": health_matches(health(adapter), adapter) if adapter else None,
        })
    return {"current": current, "providers": rows}


def emit(value: dict, as_json: bool) -> None:
    if as_json:
        print(json.dumps(value, ensure_ascii=False, separators=(",", ":")))
        return
    if "providers" in value:
        print(f"Current provider: {value['current']}")
        for row in value["providers"]:
            marker = "*" if row["current"] else " "
            adapter = ""
            if row["adapter"]:
                adapter = " [adapter: healthy]" if row["adapter_healthy"] else " [adapter: stopped]"
            print(f"{marker} {row['id']} - {row['name']}{adapter}")
    elif value.get("changed"):
        print(f"Switched {value['previous']} -> {value['current']}")
        if value.get("warning"):
            print(f"Warning: {value['warning']}", file=sys.stderr)
    else:
        print(f"Provider already active: {value['current']}")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=default_config_path())
    parser.add_argument("--adapters", type=Path, default=default_adapters_path())
    parser.add_argument("--json", action="store_true")
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("list")
    subparsers.add_parser("status")
    switch = subparsers.add_parser("switch")
    switch.add_argument("provider")
    switch.add_argument("--confirm-no-active-tasks", action="store_true")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    try:
        if args.command in {"list", "status"}:
            emit(snapshot(args.config, args.adapters), args.json)
        else:
            value = switch_provider(args.config, args.adapters, args.provider, args.confirm_no_active_tasks)
            emit(value, args.json)
    except SwitcherError as exc:
        if args.json:
            print(json.dumps({"error": str(exc)}, ensure_ascii=False, separators=(",", ":")))
        else:
            print(f"Error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
