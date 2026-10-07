import unittest
from search_order import canonical_message_order


class SearchOrderTest(unittest.TestCase):
    def test_only_order_is_normalized(self):
        first = '<div data-message-id="1"><div>coffee</div></div>'
        second = '<div data-message-id="2"><div>private</div></div>'
        page = lambda body: '<!doctype html><html><div id="search-results">' + body + '</div></html>'
        expected = canonical_message_order(page(first + second))
        self.assertEqual(expected, canonical_message_order(page(second + first)))
        self.assertNotEqual(expected, canonical_message_order(page(first)))
        self.assertNotEqual(expected, canonical_message_order(page(second.replace('private', 'stale') + first)))
        with self.assertRaises(AssertionError):
            canonical_message_order(page(first + first))
        with self.assertRaises(AssertionError):
            canonical_message_order('<div data-message-id="1"><div>broken')


if __name__ == '__main__':
    unittest.main()
