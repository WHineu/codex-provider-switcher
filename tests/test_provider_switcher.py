#!/usr/bin/env python3
"""Offline tests for the generic Codex provider switcher."""

from __future__ import annotations

import importlib.util
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import tomllib
import unittest
from unittest import mock
import urllib.error
import urllib.request


ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"
FIXTURES = Path(__file__).resolve().parent / "fixtures"
SPEC = importlib.util.spec_from_file_location("provider_switcher", SRC / "provider_switcher.py")
assert SPEC and SPEC.loader
switcher = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = switcher
SPEC.loader.exec_module(switcher)


def free_port() -> int:
    with socket.socket() as value:
        value.bind(("127.0.0.1", 0))
        return value.getsockname()[1]


class ProviderSwitcherTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.config = self.root / "config.toml"
        self.adapters = self.root / "adapters.toml"
        self.state = self.root / "state"
        shutil.copy2(FIXTURES / "valid.toml", self.config)
        self.adapters.write_text("", encoding="utf-8")
        self.state_patch = mock.patch.dict(
            os.environ,
            {"CODEX_PROVIDER_SWITCHER_STATE_DIR": str(self.state)},
        )
        self.state_patch.start()

    def tearDown(self) -> None:
        self.state_patch.stop()
        self.temp.cleanup()

    def parsed(self) -> dict:
        with self.config.open("rb") as handle:
            return tomllib.load(handle)

    def test_discovers_arbitrary_providers(self) -> None:
        value = switcher.snapshot(self.config, self.adapters)
        self.assertEqual(value["current"], "provider_a")
        self.assertEqual([item["id"] for item in value["providers"]], ["provider_a", "provider_b"])

    def test_confirmation_guard_does_not_modify_config(self) -> None:
        before = self.config.read_bytes()
        with self.assertRaisesRegex(switcher.SwitcherError, "confirm-no-active-tasks"):
            switcher.switch_provider(self.config, self.adapters, "provider_b", False)
        self.assertEqual(self.config.read_bytes(), before)

    def test_confirmation_guard_runs_before_adapter_start(self) -> None:
        self.adapters.write_text(
            '[providers.provider_b]\ntype="http11_gateway"\nlisten_port=19877\nupstream_host="api.example.invalid"\n',
            encoding="utf-8",
        )
        with mock.patch.object(switcher, "start_adapter") as start:
            with self.assertRaisesRegex(switcher.SwitcherError, "confirm-no-active-tasks"):
                switcher.switch_provider(self.config, self.adapters, "provider_b", False)
        start.assert_not_called()

    def test_symbolic_link_config_is_rejected(self) -> None:
        link = self.root / "config-link.toml"
        link.symlink_to(self.config)
        before = self.config.read_bytes()
        with self.assertRaisesRegex(switcher.SwitcherError, "symbolic link"):
            switcher.switch_provider(link, self.adapters, "provider_b", True)
        self.assertEqual(self.config.read_bytes(), before)

    def test_switch_preserves_nested_provider_and_permissions(self) -> None:
        os.chmod(self.config, 0o600)
        value = switcher.switch_provider(self.config, self.adapters, "provider_b", True)
        payload = self.parsed()
        self.assertTrue(value["changed"])
        self.assertEqual(payload["model_provider"], "provider_b")
        self.assertEqual(payload["profiles"]["keep_this"]["model_provider"], "provider_a")
        self.assertEqual(self.config.stat().st_mode & 0o777, 0o600)

    def test_same_provider_is_idempotent(self) -> None:
        before = self.config.read_bytes()
        value = switcher.switch_provider(self.config, self.adapters, "provider_a", False)
        self.assertFalse(value["changed"])
        self.assertEqual(self.config.read_bytes(), before)

    def test_unknown_provider_is_rejected(self) -> None:
        before = self.config.read_bytes()
        with self.assertRaisesRegex(switcher.SwitcherError, "Unknown provider"):
            switcher.switch_provider(self.config, self.adapters, "not_configured", True)
        self.assertEqual(self.config.read_bytes(), before)

    def test_duplicate_root_assignment_is_rejected(self) -> None:
        shutil.copy2(FIXTURES / "duplicate-root.toml", self.config)
        before = self.config.read_bytes()
        with self.assertRaises(switcher.SwitcherError):
            switcher.switch_provider(self.config, self.adapters, "provider_b", True)
        self.assertEqual(self.config.read_bytes(), before)

    def test_failed_switch_does_not_stop_preexisting_target_adapter(self) -> None:
        self.adapters.write_text(
            '[providers.provider_b]\ntype="http11_gateway"\nlisten_port=19877\nupstream_host="api.example.invalid"\n',
            encoding="utf-8",
        )
        with (
            mock.patch.object(switcher, "start_adapter", return_value="already running"),
            mock.patch.object(switcher, "atomic_write", side_effect=[OSError("offline failure"), None]),
            mock.patch.object(switcher, "stop_adapter") as stop,
        ):
            with self.assertRaisesRegex(switcher.SwitcherError, "original configuration was restored"):
                switcher.switch_provider(self.config, self.adapters, "provider_b", True)
        stop.assert_not_called()

    def test_adapter_references_known_provider(self) -> None:
        self.adapters.write_text(
            '[providers.unknown]\ntype="http11_gateway"\nlisten_port=19877\nupstream_host="api.example.invalid"\n',
            encoding="utf-8",
        )
        with self.assertRaisesRegex(switcher.SwitcherError, "unknown provider"):
            switcher.snapshot(self.config, self.adapters)

    def test_adapter_start_health_and_stop(self) -> None:
        port = free_port()
        self.adapters.write_text(
            "\n".join([
                "[providers.provider_b]",
                'type = "http11_gateway"',
                f"listen_port = {port}",
                'upstream_host = "api.example.invalid"',
                'models_mode = "empty_codex_catalog"',
                'allowed_paths = ["/v1/models", "/v1/responses"]',
                "",
            ]),
            encoding="utf-8",
        )
        value = switcher.switch_provider(self.config, self.adapters, "provider_b", True)
        self.assertEqual(value["adapter"], "started")
        status = switcher.snapshot(self.config, self.adapters)
        row = next(item for item in status["providers"] if item["id"] == "provider_b")
        self.assertTrue(row["adapter_healthy"])
        back = switcher.switch_provider(self.config, self.adapters, "provider_a", True)
        self.assertEqual(back["current"], "provider_a")
        for _ in range(30):
            if switcher.health(switcher.adapters_from_config(self.adapters, switcher.providers_from_config(self.parsed()))["provider_b"]) is None:
                break
            time.sleep(0.1)
        self.assertIsNone(switcher.health(switcher.adapters_from_config(self.adapters, switcher.providers_from_config(self.parsed()))["provider_b"]))

    def test_cli_json_has_no_vendor_assumptions(self) -> None:
        result = subprocess.run(
            [
                sys.executable,
                str(SRC / "provider_switcher.py"),
                "--config", str(self.config),
                "--adapters", str(self.adapters),
                "--json", "list",
            ],
            text=True,
            capture_output=True,
            check=True,
            timeout=10,
            env={**os.environ, "CODEX_PROVIDER_SWITCHER_STATE_DIR": str(self.state)},
        )
        value = json.loads(result.stdout)
        self.assertEqual(value["current"], "provider_a")
        self.assertEqual(len(value["providers"]), 2)


class GatewayTests(unittest.TestCase):
    def setUp(self) -> None:
        self.port = free_port()
        self.instance = "offline-test-instance"
        self.process = subprocess.Popen(
            [
                sys.executable,
                str(SRC / "http11_gateway.py"),
                "--provider", "provider_test",
                "--instance-id", self.instance,
                "--listen-port", str(self.port),
                "--upstream-host", "api.example.invalid",
                "--allowed-path", "/v1/models",
                "--allowed-path", "/v1/responses",
                "--models-mode", "empty_codex_catalog",
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        for _ in range(40):
            try:
                with urllib.request.urlopen(f"http://127.0.0.1:{self.port}/healthz", timeout=0.2):
                    break
            except OSError:
                time.sleep(0.05)
        else:
            self.fail("gateway did not start")

    def tearDown(self) -> None:
        self.process.terminate()
        try:
            self.process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            self.process.kill()
            self.process.wait(timeout=3)

    def test_health_identifies_owned_instance(self) -> None:
        with urllib.request.urlopen(f"http://127.0.0.1:{self.port}/healthz", timeout=1) as response:
            value = json.load(response)
        self.assertEqual(value["provider"], "provider_test")
        self.assertEqual(value["instance_id"], self.instance)

    def test_local_model_catalog(self) -> None:
        with urllib.request.urlopen(f"http://127.0.0.1:{self.port}/v1/models", timeout=1) as response:
            value = json.load(response)
        self.assertEqual(value, {"models": []})

    def test_unsupported_path_is_rejected(self) -> None:
        with self.assertRaises(urllib.error.HTTPError) as context:
            urllib.request.urlopen(f"http://127.0.0.1:{self.port}/not-allowed", timeout=1)
        self.assertEqual(context.exception.code, 404)
        context.exception.close()


if __name__ == "__main__":
    unittest.main(verbosity=2)
