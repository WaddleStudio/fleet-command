import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT_PS1 = REPO_ROOT / "scripts" / "update-skill-lock.ps1"
SCRIPT_SH = REPO_ROOT / "scripts" / "update-skill-lock.sh"


def _has_pwsh() -> bool:
    return shutil.which("pwsh") is not None or shutil.which("powershell") is not None


def _has_bash() -> bool:
    return shutil.which("bash") is not None


class UpdateSkillLockTest(unittest.TestCase):
    @unittest.skipUnless(_has_pwsh(), "PowerShell not on PATH")
    def test_ps1_prints_diff_and_does_not_write_when_no_change(self) -> None:
        pwsh = shutil.which("pwsh") or shutil.which("powershell")
        lock = json.loads((REPO_ROOT / "workspace" / "skills.lock.json").read_text(encoding="utf-8"))
        sha = next(s["ref"]["sha"] for s in lock["skills"] if s["id"] == "ui-ux-pro-max")
        result = subprocess.run(
            [pwsh, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(SCRIPT_PS1),
             "--tool", "ui-ux-pro-max", "--to", sha, "--dry-run"],
            cwd=str(REPO_ROOT), capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("ui-ux-pro-max", result.stdout)

    @unittest.skipUnless(_has_bash(), "bash not on PATH")
    def test_sh_no_change_when_to_matches_current_sha(self) -> None:
        if shutil.which("jq") is None:
            self.skipTest("jq required")
        bash = shutil.which("bash")
        lock = json.loads((REPO_ROOT / "workspace" / "skills.lock.json").read_text(encoding="utf-8"))
        sha = next(s["ref"]["sha"] for s in lock["skills"] if s["id"] == "ui-ux-pro-max")
        result = subprocess.run(
            [bash, str(SCRIPT_SH), "--tool", "ui-ux-pro-max", "--to", sha, "--dry-run"],
            cwd=str(REPO_ROOT), capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("no change", result.stdout.lower())


if __name__ == "__main__":
    unittest.main()
