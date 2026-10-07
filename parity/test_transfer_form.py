import unittest
from transfer_form import canonical_transfer_form


class TransferFormTest(unittest.TestCase):
    def test_only_the_closing_tag_is_permitted(self):
        before = '<form data-controller="auto-submit" action="/session/transfers/example"><input name="_method" value="put">'
        after = '\n<footer id="footer"></footer>'
        frozen = before + after
        current = before + "</form>" + after
        self.assertEqual(canonical_transfer_form(frozen, False), canonical_transfer_form(current, True))
        changed = current.replace("example", "wrong")
        self.assertNotEqual(canonical_transfer_form(frozen, False), canonical_transfer_form(changed, True))

    def test_incomplete_or_extra_forms_fail(self):
        page = '<form data-controller="auto-submit" action="/session/transfers/example"><input name="_method" value="put"><footer id="footer"></footer>'
        for invalid in [page, page + "</form></form>", page + "<form></form>", page.replace('value="put"', 'value="patch"')]:
            with self.assertRaises(AssertionError):
                canonical_transfer_form(invalid, True)


if __name__ == "__main__":
    unittest.main()
