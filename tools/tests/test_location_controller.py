import importlib.util
from pathlib import Path
import tempfile
import unittest


MODULE_PATH = Path(__file__).resolve().parents[1] / "location_controller.py"
RUNTIME_TEST_DIR = Path(__file__).resolve().parents[2] / ".runtime" / "test-tmp"
RUNTIME_TEST_DIR.mkdir(parents=True, exist_ok=True)
SPEC = importlib.util.spec_from_file_location("location_controller", MODULE_PATH)
assert SPEC and SPEC.loader
controller = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(controller)


class LocationControllerTests(unittest.TestCase):
    def test_coordinate_validation(self):
        controller.validate_coordinate(31.23, 121.47)
        for latitude, longitude in [(91, 0), (0, 181), (float("nan"), 0)]:
            with self.assertRaises(controller.ControllerError):
                controller.validate_coordinate(latitude, longitude)

    def test_gpx_requires_two_points(self):
        with tempfile.TemporaryDirectory(dir=RUNTIME_TEST_DIR) as directory:
            path = Path(directory) / "one.gpx"
            path.write_text(
                '<?xml version="1.0"?><gpx xmlns="http://www.topografix.com/GPX/1/1">'
                '<wpt lat="31.23" lon="121.47"/></gpx>',
                encoding="utf-8",
            )
            with self.assertRaises(controller.ControllerError):
                controller.inspect_gpx(path)

    def test_gpx_accepts_namespaced_track_points(self):
        with tempfile.TemporaryDirectory(dir=RUNTIME_TEST_DIR) as directory:
            path = Path(directory) / "route.gpx"
            path.write_text(
                '<?xml version="1.0"?><gpx xmlns="http://www.topografix.com/GPX/1/1">'
                '<trk><trkseg><trkpt lat="31.23" lon="121.47"/>'
                '<trkpt lat="31.24" lon="121.48"/></trkseg></trk></gpx>',
                encoding="utf-8",
            )
            self.assertEqual(controller.inspect_gpx(path), 2)

    def test_gpx_rejects_xml_entities(self):
        with tempfile.TemporaryDirectory(dir=RUNTIME_TEST_DIR) as directory:
            path = Path(directory) / "entity.gpx"
            path.write_text(
                '<?xml version="1.0"?><!DOCTYPE gpx [<!ENTITY x "31.23">]>'
                '<gpx><trk><trkseg><trkpt lat="&x;" lon="121.47"/>'
                '<trkpt lat="31.24" lon="121.48"/></trkseg></trk></gpx>',
                encoding="utf-8",
            )
            with self.assertRaises(controller.ControllerError):
                controller.inspect_gpx(path)


if __name__ == "__main__":
    unittest.main()
