import json
import re
import unittest
from pathlib import Path


LOCK_PATH = Path(__file__).resolve().parents[1] / "workspace" / "skills.lock.json"
SHA_RE = re.compile(r"^[0-9a-f]{40}$")


class SkillsLockTest(unittest.TestCase):
    def setUp(self) -> None:
        self.lock = json.loads(LOCK_PATH.read_text(encoding="utf-8"))

    def test_lock_version_is_one(self) -> None:
        self.assertEqual(self.lock["version"], 1)

    def test_each_skill_has_required_fields(self) -> None:
        required = {"id", "cloneUrl", "target", "host", "role", "ref"}
        for skill in self.lock["skills"]:
            self.assertTrue(required.issubset(skill), skill)

    def test_each_ref_has_40_char_sha(self) -> None:
        for skill in self.lock["skills"]:
            sha = skill["ref"]["sha"]
            self.assertTrue(SHA_RE.match(sha), f"{skill['id']} sha invalid: {sha!r}")

    def test_three_known_skills_present(self) -> None:
        ids = {skill["id"] for skill in self.lock["skills"]}
        self.assertEqual(ids, {"superpowers", "gstack", "ui-ux-pro-max"})


if __name__ == "__main__":
    unittest.main()
