"""The host inventory is a contract: every setting carries every field, in one order,
so a reader can find the restoration steps of any entry in the same place.

Current contract: docs/host-configuration.md; template and source index below.
"""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parent.parent
TEMPLATE = ROOT / "hosts" / "inventory-entry.md"
FIELD = re.compile(r"^- \*\*([^*]+):\*\*", re.MULTILINE)
SECTION = re.compile(r"^### (.+)$", re.MULTILINE)


def fields_of(text):
    return FIELD.findall(text)


def sections_of(text):
    """(title, body) for each `### ` section of the settings part of an inventory."""
    settings = text.split("\n## Settings\n", 1)[1]
    titles = SECTION.findall(settings)
    bodies = SECTION.split(settings)[2::2]
    return list(zip(titles, bodies))


class TemplateTests(unittest.TestCase):
    def test_template_fields_are_the_spec_fields_in_order(self):
        self.assertEqual(fields_of(TEMPLATE.read_text()), [
            "Scope", "Observed", "Installed path", "Effective value", "Inspect",
            "Mechanism", "Winning source", "Purpose", "Confidence",
            "Package owner", "Tracked source", "Installed matches source",
            "Persistence", "Previous value", "Vendor default", "Restore", "Validation"])


class InventoryTests(unittest.TestCase):
    """Every inventory under hosts/ follows the template."""

    def inventories(self):
        return sorted((ROOT / "hosts").glob("*/inventory.md"))

    def test_there_is_at_least_one_inventory(self):
        self.assertTrue(self.inventories())

    def test_every_section_has_every_field_in_template_order(self):
        expected = fields_of(TEMPLATE.read_text())
        for path in self.inventories():
            for title, body in sections_of(path.read_text()):
                with self.subTest(inventory=path.name, setting=title):
                    self.assertEqual(fields_of(body), expected)

    def test_no_template_placeholder_survives(self):
        for path in self.inventories():
            with self.subTest(inventory=path.name):
                self.assertNotRegex(path.read_text(), r"<[a-z][a-z -]+>", "angle-bracket placeholder left in")

    def test_every_section_has_a_settings_heading_to_sit_under(self):
        for path in self.inventories():
            with self.subTest(inventory=path.name):
                self.assertIn("\n## Settings\n", path.read_text())


def source_rows(text):
    """Read the current Source/Settings table, refusing missing or malformed rows."""
    marker = "\n## Source index\n"
    if marker not in text:
        raise ValueError("inventory has no Source index")
    table = text.split(marker, 1)[1].split("\n## ", 1)[0]
    lines = [line.strip() for line in table.splitlines() if line.strip()]
    if len(lines) < 3 or lines[0] != "| Source | Settings |":
        raise ValueError("source index requires its header and nonempty mappings")
    if not re.fullmatch(r"\|\s*:?-{3,}:?\s*\|\s*:?-{3,}:?\s*\|", lines[1]):
        raise ValueError("source index has a malformed separator")
    rows = []
    for line in lines[2:]:
        if not line.startswith("|") or not line.endswith("|"):
            raise ValueError("source index has a malformed row")
        cells = [cell.strip() for cell in line[1:-1].split("|")]
        if len(cells) != 2 or not cells[0]:
            raise ValueError("source index requires a source and settings")
        names = [name.strip() for name in cells[1].split("→")]
        if not all(names):
            raise ValueError("source index has an empty setting name")
        rows.append((cells[0], names))
    return rows


class SourceIndexTests(unittest.TestCase):
    """Current inventories must cover settings in both directions without candidates.md."""

    def check_index(self, text):
        titles = {title for title, _ in sections_of(text)}
        self.assertTrue(titles, "inventory has no settings")
        rows = source_rows(text)
        self.assertTrue(rows, "source index is empty")
        named = set()
        for source, settings in rows:
            self.assertTrue(settings, f"{source}: source names no settings")
            self.assertLessEqual(set(settings), titles, f"{source}: source names missing settings")
            named.update(settings)
        self.assertEqual(titles - named, set(), "settings have no source")

    def text(self, rows, settings=("A", "B")):
        return ("# Inventory\n\n## Source index\n\n| Source | Settings |\n"
                "| --- | --- |\n" + rows + "\n## Settings\n\n"
                + "\n".join("### " + name + "\n" for name in settings))

    def test_every_inventory_has_two_way_source_coverage(self):
        inventories = sorted((ROOT / "hosts").glob("*/inventory.md"))
        self.assertTrue(inventories, "no host inventories discovered")
        for path in inventories:
            with self.subTest(inventory=str(path.relative_to(ROOT))):
                self.check_index(path.read_text())

    def test_many_to_many_mappings(self):
        text = self.text("| /one | A → B |\n| /two | A |\n")
        self.assertEqual(source_rows(text), [("/one", ["A", "B"]), ("/two", ["A"])])
        self.check_index(text)

    def test_empty_or_malformed_source_rows_are_rejected(self):
        for rows in ("", "| | A |", "| /one | |", "| /one | A → |",
                     "| /one | → A |", "| /one | A | extra |", "not a row"):
            with self.subTest(rows=rows), self.assertRaises(ValueError):
                source_rows(self.text(rows))
        with self.assertRaises(ValueError):
            source_rows("# Inventory\n\n## Settings\n")

    def test_settings_cannot_be_empty(self):
        with self.assertRaisesRegex(AssertionError, "no settings"):
            self.check_index(self.text("| /one | A |", settings=()))

    def test_dangling_mapping_is_rejected(self):
        with self.assertRaisesRegex(AssertionError, "missing settings"):
            self.check_index(self.text("| /one | A → missing |"))

    def test_unmapped_setting_is_rejected(self):
        with self.assertRaisesRegex(AssertionError, "no source"):
            self.check_index(self.text("| /one | A |"))
