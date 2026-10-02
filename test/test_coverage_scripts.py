import importlib.util
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent.parent / "scripts"


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, SCRIPTS / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


ratchet = load("coverage_ratchet", "coverage-ratchet.py")
diffcov = load("diff_coverage", "diff-coverage.py")

LCOV = "SF:src/a.js\nDA:1,1\nDA:2,0\nLF:4\nLH:3\nend_of_record\nSF:src/b.js\nLF:6\nLH:3\nend_of_record\n"
COBERTURA = '<?xml version="1.0"?><coverage line-rate="0.5" lines-valid="10" lines-covered="7"></coverage>'


class RatchetTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.path = Path(self.dir.name)

    def tearDown(self):
        self.dir.cleanup()

    def write(self, name, text):
        (self.path / name).write_text(text)
        return str(self.path / name)

    def test_lcov_total(self):
        self.assertAlmostEqual(ratchet.total_percent(self.write("lcov.info", LCOV)), 60.0)

    def test_cobertura_prefers_line_counts(self):
        self.assertAlmostEqual(ratchet.total_percent(self.write("c.xml", COBERTURA)), 70.0)

    def test_missing_baseline_passes(self):
        report = self.write("lcov.info", LCOV)
        self.assertEqual(ratchet.main([report, "--baseline", str(self.path / "none")]), 0)

    def test_drop_below_baseline_fails(self):
        report = self.write("lcov.info", LCOV)
        baseline = self.write("base", "75.00\n")
        self.assertEqual(ratchet.main([report, "--baseline", baseline]), 1)

    def test_update_raises_baseline_only_upward(self):
        report = self.write("lcov.info", LCOV)
        baseline = self.write("base", "50.00\n")
        self.assertEqual(ratchet.main([report, "--baseline", baseline, "--update"]), 0)
        self.assertEqual(Path(baseline).read_text().strip(), "60.00")

    def test_unreadable_report_exits_2(self):
        self.assertEqual(ratchet.main([self.write("bad.info", "nothing")]), 2)


class DiffCoverageTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.repo = Path(self.dir.name)
        self.git("init", "-q")
        self.git("config", "user.email", "t@example.com")
        self.git("config", "user.name", "Test")
        (self.repo / "src").mkdir()
        (self.repo / "src/a.js").write_text("one\ntwo\n")
        self.git("add", "-A")
        self.git("commit", "-qm", "base")
        self.base = self.git("rev-parse", "HEAD").strip()
        (self.repo / "src/a.js").write_text("one\ntwo\nthree\nfour\n")
        self.git("commit", "-qam", "change")
        self.cwd = os.getcwd()
        os.chdir(self.repo)

    def tearDown(self):
        os.chdir(self.cwd)
        self.dir.cleanup()

    def git(self, *args):
        return subprocess.run(["git", *args], cwd=self.repo, check=True, capture_output=True, text=True).stdout

    def report(self, hits3, hits4):
        path = self.repo / "lcov.info"
        path.write_text(f"SF:{self.repo}/src/a.js\nDA:1,1\nDA:3,{hits3}\nDA:4,{hits4}\nend_of_record\n")
        return str(path)

    def test_changed_lines_detected(self):
        self.assertEqual(diffcov.changed_lines(self.base, "HEAD"), {"src/a.js": {3, 4}})

    def test_passes_when_changed_lines_covered(self):
        self.assertEqual(diffcov.main([self.report(1, 2), self.base]), 0)

    def test_fails_below_threshold(self):
        self.assertEqual(diffcov.main([self.report(1, 0), self.base, "--fail-under", "80"]), 1)

    def test_threshold_is_inclusive(self):
        self.assertEqual(diffcov.main([self.report(1, 0), self.base, "--fail-under", "50"]), 0)

    def test_cobertura_relative_paths(self):
        path = self.repo / "coverage.xml"
        path.write_text(
            '<coverage><packages><package><classes><class filename="src/a.js"><lines>'
            '<line number="3" hits="0"/><line number="4" hits="0"/></lines></class></classes></package>'
            "</packages></coverage>"
        )
        self.assertEqual(diffcov.main([str(path), self.base]), 1)

    def test_no_instrumented_changes_passes(self):
        path = self.repo / "lcov.info"
        path.write_text("SF:other.js\nDA:1,0\nend_of_record\n")
        self.assertEqual(diffcov.main([str(path), self.base]), 0)


if __name__ == "__main__":
    unittest.main()
