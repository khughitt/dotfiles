"""Exercise the CLI and durable state with a fake DDC device; never touch hardware."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


TOOL = Path(__file__).resolve().parents[1] / "bin/display-dim"
# EDID base block from ddcutil's documented Acer detect example.
EDID = """00 ff ff ff ff ff ff 00 04 72 00 00 cf 12 60 74
2e 11 01 03 80 34 20 78 2a ef 95 a3 54 4c 9b 26
0f 50 54 a5 4b 00 81 80 81 00 81 0f 95 00 95 0f
a9 40 b3 00 01 01 28 3c 80 a0 70 b0 23 40 30 20
36 00 06 44 21 00 00 1a 00 00 00 fd 00 38 4c 1e
52 11 00 0a 20 20 20 20 20 20 00 00 00 fc 00 41
63 65 72 20 58 32 34 33 57 0a 20 20 00 00 00 ff
00 4c 41 47 30 34 30 30 36 34 33 31 30 0a 00 68"""
DETECT = "Display 1\n   I2C bus: /dev/i2c-7\n   EDID hex dump:\n" + "\n".join(
    f"      +{i * 16:04x}   {row}   ascii" for i, row in enumerate(EDID.splitlines())
)
FAKE = '''#!/usr/bin/env python3
import json, os, pathlib, sys
p = pathlib.Path(os.environ["DEVICE"])
d = json.loads(p.read_text())
a = sys.argv[1:]
if "detect" in a:
    print(d["detect"])
elif "--edid" not in a or a[a.index("--edid") + 1] != d["edid"]:
    sys.exit(1)
elif "getvcp" in a:
    if d.get("reject_read"):
        print("VCP 10 ERR")
        sys.exit(1)
    print(d.get("get_output", f'VCP 10 C {d["current"]} {d["max"]}'))
elif "setvcp" in a:
    if d.get("reject_write"):
        sys.exit(1)
    if not list(pathlib.Path(os.environ["XDG_STATE_HOME"]).glob("display-dim/*.json")):
        sys.exit("brightness write without recovery record")
    d["current"] = int(a[a.index("setvcp") + 2])
    if d.get("fail_readback"):
        d["reject_read"] = True
    p.write_text(json.dumps(d))
    if d.get("fail_after_write"):
        sys.exit(1)
else:
    sys.exit(2)
'''


class DisplayDimTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.base = Path(temp.name)
        fake = self.base / "ddcutil"
        fake.write_text(FAKE)
        fake.chmod(0o755)
        self.device = self.base / "device.json"
        self.device.write_text(json.dumps({"detect": DETECT, "edid": "".join(EDID.split()),
                                           "current": 73, "max": 200}))
        self.env = {**os.environ, "PATH": str(self.base) + os.pathsep + os.environ["PATH"],
                    "DEVICE": str(self.device), "XDG_STATE_HOME": str(self.base / "state")}

    def run_tool(self, *args, code=0):
        result = subprocess.run([sys.executable, str(TOOL), *args], env=self.env,
                                text=True, capture_output=True, timeout=5)
        self.assertEqual(result.returncode, code, result.stdout + result.stderr)
        return result

    def change(self, **changes):
        device = json.loads(self.device.read_text())
        device.update(changes)
        self.device.write_text(json.dumps(device))

    def records(self):
        return list((self.base / "state/display-dim").glob("*.json"))

    def brightness(self):
        return json.loads(self.device.read_text())["current"]

    def test_repeated_set_preserves_original_and_restore_survives_renumbering(self):
        self.run_tool("set", "0.25")
        self.assertEqual(self.brightness(), 50)
        record = self.records()[0].read_bytes()
        self.run_tool("set", "0.15")
        self.assertEqual(self.brightness(), 30)
        self.assertEqual(self.records()[0].read_bytes(), record)
        self.change(detect=DETECT.replace("Display 1", "Display 4"))
        self.assertIn("restore-needed", self.run_tool("status").stdout)
        self.run_tool("restore")
        self.assertEqual(self.brightness(), 73)
        self.assertEqual(self.records(), [])
        self.env["PATH"] = str(self.base / "missing")
        self.assertIn("no saved", self.run_tool("restore").stdout.lower())
        self.run_tool("status")

    def test_default_and_rounding_use_device_maximum(self):
        self.change(max=102)
        self.run_tool("set")
        self.assertEqual(self.brightness(), 26)

    def test_invalid_display_before_valid_display_is_not_selected(self):
        invalid = DETECT.replace("Display 1", "Invalid display").replace("04 72", "04 73")
        self.change(detect=invalid + "\n" + DETECT)
        self.run_tool("set")
        self.assertEqual(self.brightness(), 50)

    def test_no_ddc_display_leaves_no_record(self):
        self.change(detect=DETECT.replace("Display 1", "Invalid display"))
        self.run_tool("set", code=3)
        self.assertEqual(self.records(), [])

    def test_concurrent_set_keeps_first_original(self):
        processes = [subprocess.Popen([sys.executable, str(TOOL), "set", value],
                                     env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                     for value in ("0.25", "0.15")]
        for process in processes:
            stdout, stderr = process.communicate(timeout=5)
            self.assertEqual(process.returncode, 0, stdout + stderr)
        self.run_tool("restore")
        self.assertEqual(self.brightness(), 73)

    def test_rejected_ddc_leaves_no_new_record(self):
        for changes in ({"reject_read": True}, {"reject_read": False, "reject_write": True},
                        {"reject_write": False, "get_output": "VCP 10 SNC x00 x32"}):
            with self.subTest(changes=changes):
                self.change(**changes)
                self.run_tool("set", "0.25", code=3)
                self.assertEqual(self.records(), [])
                self.assertEqual(self.brightness(), 73)

    def test_failed_restore_retains_record_and_wrong_display_is_not_written(self):
        self.run_tool("set", "0.25")
        self.change(edid="11" * 128)
        self.run_tool("restore", code=3)
        self.assertEqual(self.brightness(), 50)
        self.assertEqual(len(self.records()), 1)
        self.change(edid="".join(EDID.split()), reject_write=True)
        self.run_tool("restore", code=3)
        self.assertEqual(len(self.records()), 1)
        self.change(reject_write=False)
        self.run_tool("restore")
        self.assertEqual(self.brightness(), 73)

    def test_uncertain_write_keeps_recovery_record(self):
        self.change(fail_after_write=True)
        self.run_tool("set", "0.25", code=3)
        self.assertEqual(self.brightness(), 50)
        self.assertEqual(len(self.records()), 1)
        self.change(fail_after_write=False)
        self.run_tool("restore")
        self.assertEqual(self.brightness(), 73)

    def test_failed_readback_after_failed_write_keeps_recovery_record(self):
        self.change(fail_after_write=True, fail_readback=True)
        self.run_tool("set", "0.25", code=3)
        self.assertEqual(self.brightness(), 50)
        self.assertEqual(len(self.records()), 1)
        self.change(fail_after_write=False, fail_readback=False, reject_read=False)
        self.run_tool("restore")
        self.assertEqual(self.brightness(), 73)

    def test_invalid_fraction_and_ambiguous_detection_do_not_dim(self):
        for fraction in ("-0.1", "1.1", "nan", "inf", "bad"):
            with self.subTest(fraction=fraction):
                self.run_tool("set", fraction, code=2)
                self.assertEqual(self.records(), [])
        self.change(detect=DETECT + "\n" + DETECT.replace("Display 1", "Display 2"))
        self.run_tool("set", code=2)
        self.assertEqual(self.records(), [])
        self.assertEqual(self.brightness(), 73)

    def test_corrupt_record_is_reported_and_never_overwritten(self):
        self.run_tool("set")
        record = self.records()[0]
        record.write_text("{}")
        for command in ("status", "restore", "set"):
            self.run_tool(command, code=2)
            self.assertEqual(record.read_text(), "{}")
        self.assertEqual(self.brightness(), 50)
