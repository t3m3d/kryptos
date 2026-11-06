#!/usr/bin/env python3
"""KryptOS: WidgetShadowEffect is a no-op stub in this image.

The live ISO's Qt build has no QtQuick.Effects (RectangularShadow/MultiEffect),
so the effect exists only to keep Panel.qml's cornerRadius hook working.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EFFECT = ROOT / "quickshell" / "components" / "WidgetShadowEffect.qml"
PANEL_CHROME = ROOT / "quickshell" / "components" / "Panel.qml"


class WidgetShadowTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.effect = EFFECT.read_text(encoding="utf-8")
        cls.chrome = PANEL_CHROME.read_text(encoding="utf-8")

    def test_no_qt_effects_import(self):
        self.assertNotIn("QtQuick.Effects", self.effect)
        self.assertNotIn("RectangularShadow", self.effect)
        self.assertNotIn("MultiEffect", self.effect)

    def test_panel_hook_unchanged(self):
        self.assertIn("WidgetShadowEffect {", self.chrome)
        self.assertIn("cornerRadius: panel.freeR", self.chrome)

    def test_corner_radius_property_kept(self):
        self.assertIn("required property real cornerRadius", self.effect)


if __name__ == "__main__":
    unittest.main()
