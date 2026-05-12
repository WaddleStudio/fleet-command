import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
TEARDOWN_PS1 = REPO_ROOT / "bootstrap" / "teardown.ps1"
TEARDOWN_SH = REPO_ROOT / "bootstrap" / "teardown.sh"


def _has_pwsh() -> bool:
    return shutil.which("pwsh") is not None or shutil.which("powershell") is not None


def _has_bash() -> bool:
    return shutil.which("bash") is not None


def _make_workspace_with_artifacts(tmp: str) -> Path:
    ws = Path(tmp)
    fc = ws / "fleet-command"
    shutil.copytree(REPO_ROOT, fc, ignore=shutil.ignore_patterns(".git", ".worktrees", ".uv-cache"))
    (ws / "cardsense-api").mkdir()
    (ws / ".claude").mkdir()
    (ws / ".uv-cache").mkdir()
    return ws


class TeardownDryRunTest(unittest.TestCase):
    @unittest.skipUnless(_has_pwsh(), "PowerShell not on PATH")
    def test_ps1_dry_run_lists_artifacts_without_deleting(self) -> None:
        pwsh = shutil.which("pwsh") or shutil.which("powershell")
        with tempfile.TemporaryDirectory() as tmp:
            ws = _make_workspace_with_artifacts(tmp)
            result = subprocess.run(
                [pwsh, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(TEARDOWN_PS1),
                 "--workspace", str(ws)],
                capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn(".uv-cache", result.stdout)
            self.assertIn("cardsense-api", result.stdout)
            self.assertIn("dry-run", result.stdout.lower())
            self.assertTrue((ws / "cardsense-api").exists())
            self.assertTrue((ws / ".uv-cache").exists())

    @unittest.skipUnless(_has_pwsh(), "PowerShell not on PATH")
    def test_ps1_refuses_home_directory(self) -> None:
        pwsh = shutil.which("pwsh") or shutil.which("powershell")
        result = subprocess.run(
            [pwsh, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(TEARDOWN_PS1),
             "--workspace", str(Path.home())],
            capture_output=True, text=True,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("HOME", result.stderr + result.stdout)

    @unittest.skipUnless(_has_bash(), "bash not on PATH")
    def test_sh_dry_run_lists_artifacts_without_deleting(self) -> None:
        if shutil.which("jq") is None:
            self.skipTest("jq required")
        bash = shutil.which("bash")
        with tempfile.TemporaryDirectory() as tmp:
            ws = _make_workspace_with_artifacts(tmp)
            result = subprocess.run(
                [bash, str(TEARDOWN_SH), "--workspace", str(ws)],
                capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn(".uv-cache", result.stdout)
            self.assertIn("dry-run", result.stdout.lower())
            self.assertTrue((ws / "cardsense-api").exists())


if __name__ == "__main__":
    unittest.main()
