import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FLAGS = ("KEEP_SIGNED_APKS_STOCK", "ENABLE_SCOPED_PLATFORM_APK_REBUILDS")


class BuildDefaultsTest(unittest.TestCase):
    def test_native_essi85_defaults_match_container(self) -> None:
        container = (ROOT / "scripts/build_in_container.sh").read_text(encoding="utf-8")
        native = (ROOT / "scripts/make_rom.sh").read_text(encoding="utf-8")
        for flag in FLAGS:
            in_container = re.findall(
                re.escape(f'{flag}=${{{flag}:-') + r"(\w+)\}", container
            )
            # The first export in make_rom.sh is the essi85 branch.
            in_native = re.findall(
                re.escape(f'export {flag}="${{{flag}:-') + r'(\w+)\}"', native
            )
            self.assertTrue(in_container, f"{flag} missing in build_in_container.sh")
            self.assertTrue(in_native, f"{flag} missing in make_rom.sh")
            self.assertEqual(in_container[0], in_native[0], flag)


if __name__ == "__main__":
    unittest.main()
