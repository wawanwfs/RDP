"""Safe, network-free tests for coordinate mapping and tailnet-only policy."""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).with_name("wfs-macos-controller.py")
spec = importlib.util.spec_from_file_location("wfs_macos_controller", ROOT)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class ControllerTests(unittest.TestCase):
    def test_tailnet_only(self):
        self.assertEqual(mod.validate_tailnet_ip("100.119.106.10"), "100.119.106.10")
        for value in ("127.0.0.1", "8.8.8.8", "192.168.0.10", "198.18.0.1", "example.com", "fe80::1"):
            with self.subTest(ip=value), self.assertRaises(ValueError):
                mod.validate_tailnet_ip(value)

    def test_display_scaling(self):
        self.assertEqual(mod.display_factor(1024, 768), 2)
        self.assertEqual(mod.display_factor(512, 384), 1)
        self.assertEqual(mod.display_factor(3840, 2160), 5)
        with self.assertRaises(ValueError):
            mod.display_factor(0, 512)

    def test_click_mapping_same_geometry(self):
        # Image 1024x768 shown at 512x384 maps image pixel (200,100)
        # back to Apple VNC framebuffer at (200,100).
        self.assertEqual(mod.map_click(100, 50, 2, 1024, 768, 1024, 768), (200, 100))
        self.assertEqual(mod.map_click(-50, 9999, 2, 1024, 768, 1024, 768), (0, 767))

    def test_click_mapping_retina_scaling(self):
        # Preview PNG may be half the pixel dimensions of RFB framebuffer.
        self.assertEqual(mod.map_click(100, 50, 2, 1024, 768, 2048, 1536), (400, 200))

    def test_invalid_geometry(self):
        with self.assertRaises(ValueError):
            mod.map_click(10, 20, 0, 1024, 768, 1024, 768)


if __name__ == "__main__":
    unittest.main()
