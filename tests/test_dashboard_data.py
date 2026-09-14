import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DASHBOARD = ROOT / "dashboard"
DATA = DASHBOARD / "data"


class DashboardDataTest(unittest.TestCase):
    def _load(self, name: str) -> dict:
        path = DATA / name
        self.assertTrue(path.exists(), f"{name} should exist")
        return json.loads(path.read_text(encoding="utf-8"))

    def test_static_dashboard_files_exist(self) -> None:
        for relative_path in ["index.html", "styles.css", "app.js"]:
            self.assertTrue((DASHBOARD / relative_path).exists(), f"{relative_path} should exist")

        app = (DASHBOARD / "app.js").read_text(encoding="utf-8")
        self.assertIn('role="progressbar"', app)
        self.assertNotIn("繚", app)

    def test_project_data_has_required_fields(self) -> None:
        data = self._load("projects.json")
        self.assertEqual(data["schemaVersion"], 1)
        self.assertIn("workspace", data)
        self.assertGreaterEqual(len(data["projects"]), 5)

        required = {"id", "name", "repo", "path", "role", "stage", "health", "focus", "stack", "commands", "links"}
        project_ids = set()
        for project in data["projects"]:
            self.assertTrue(required.issubset(project), project)
            project_ids.add(project["id"])

        self.assertIn("cardsense-web", project_ids)
        self.assertIn("cardsense-api", project_ids)
        self.assertIn("fleet-command", project_ids)

    def test_roadmap_data_has_three_horizons_and_items(self) -> None:
        data = self._load("roadmap.json")
        horizons = data["horizons"]
        self.assertEqual([horizon["id"] for horizon in horizons], ["0-30", "31-60", "61-90"])

        for horizon in horizons:
            self.assertIn(horizon["status"], {"active", "planned", "archived"})
            self.assertGreaterEqual(horizon["progress"], 0)
            self.assertLessEqual(horizon["progress"], 100)
            self.assertGreater(len(horizon["items"]), 0)
            for item in horizon["items"]:
                self.assertTrue({"workstream", "deliverable", "status"}.issubset(item), item)
                self.assertIn(item["status"], {"active", "next", "blocked", "done", "cancelled"})

    def test_checks_keep_open_work_separate_from_release_history(self) -> None:
        data = self._load("checks.json")
        self.assertIn(data["summary"]["status"], {"healthy", "watch", "blocked", "archived"})
        self.assertGreater(len(data["healthChecks"]), 0)
        self.assertGreater(len(data["actionQueue"]), 0)

        for check in data["healthChecks"]:
            self.assertTrue({"id", "label", "status", "lastRun", "evidence"}.issubset(check), check)

        action_ids = {action["id"] for action in data["actionQueue"]}
        self.assertIn("secret-rotation", action_ids)
        self.assertNotIn("calc-route-fixed", action_ids)

        for action in data["actionQueue"]:
            self.assertTrue({"id", "priority", "title", "owner", "status", "nextStep", "source"}.issubset(action), action)

    def test_main_dashboard_data_does_not_track_solved_repairs(self) -> None:
        forbidden = ["/calc", "channel=ALL", "invalid request 400", "CTA overlap fix", "P0/P1 repairs"]
        main_payloads = [
            json.dumps(self._load("roadmap.json"), ensure_ascii=False),
            json.dumps(self._load("checks.json"), ensure_ascii=False),
        ]

        for payload in main_payloads:
            for token in forbidden:
                self.assertNotIn(token, payload)

    def test_releases_include_evidence_but_do_not_drive_main_queue(self) -> None:
        data = self._load("releases.json")
        self.assertGreater(len(data["releases"]), 0)
        release = data["releases"][0]
        self.assertTrue({"id", "date", "title", "summary", "evidence", "prs", "verification"}.issubset(release), release)
        self.assertGreater(len(release["prs"]), 0)


if __name__ == "__main__":
    unittest.main()
