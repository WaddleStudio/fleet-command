import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
BOOTSTRAP_PS1 = REPO_ROOT / "bootstrap" / "bootstrap.ps1"
BOOTSTRAP_SH = REPO_ROOT / "bootstrap" / "bootstrap.sh"


def _has_pwsh() -> bool:
    return shutil.which("pwsh") is not None or shutil.which("powershell") is not None


def _has_bash() -> bool:
    return shutil.which("bash") is not None


def _run_ps(args: list[str], cwd: Path) -> subprocess.CompletedProcess:
    pwsh = shutil.which("pwsh") or shutil.which("powershell")
    return subprocess.run(
        [pwsh, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(BOOTSTRAP_PS1), *args],
        cwd=str(cwd),
        capture_output=True,
        text=True,
    )


def _run_sh(args: list[str], cwd: Path) -> subprocess.CompletedProcess:
    bash = shutil.which("bash")
    return subprocess.run(
        [bash, str(BOOTSTRAP_SH), *args],
        cwd=str(cwd),
        capture_output=True,
        text=True,
    )


class BootstrapDryRunTest(unittest.TestCase):
    @unittest.skipUnless(_has_pwsh(), "PowerShell not on PATH")
    def test_ps1_dry_run_lists_intended_repo_clones_and_skill_clones(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            workspace = Path(tmp)
            fc = workspace / "fleet-command"
            shutil.copytree(REPO_ROOT, fc, ignore=shutil.ignore_patterns(".git", ".worktrees", ".uv-cache"))

            result = _run_ps(["--dry-run", "--workspace", str(workspace), "--verbose"], cwd=fc)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("cardsense-api", result.stdout)
            self.assertIn("superpowers", result.stdout)
            self.assertIn("dry-run", result.stdout.lower())

    @unittest.skipUnless(_has_bash(), "bash not on PATH")
    def test_sh_dry_run_lists_intended_repo_clones_and_skill_clones(self) -> None:
        if shutil.which("jq") is None:
            self.skipTest("jq required for bootstrap.sh")
        with tempfile.TemporaryDirectory() as tmp:
            workspace = Path(tmp)
            fc = workspace / "fleet-command"
            shutil.copytree(REPO_ROOT, fc, ignore=shutil.ignore_patterns(".git", ".worktrees", ".uv-cache"))
            result = _run_sh(["--dry-run", "--workspace", str(workspace), "--verbose"], cwd=fc)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("cardsense-api", result.stdout)
            self.assertIn("superpowers", result.stdout)
            self.assertIn("dry-run", result.stdout.lower())


if __name__ == "__main__":
    unittest.main()
