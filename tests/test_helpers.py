import unittest
from scripts.helpers import check_if_balanced

class TestHelper(unittest.TestCase):

    def test_check_if_balanced(self):
        self.assertEqual(check_if_balanced('{{}}'), True)

    def test_check_if_not_balanced(self):
        self.assertEqual(check_if_balanced('{{{}}}}'), False)

    def test_check_if_balanced_error(self):
        with self.assertRaises(TypeError):
            check_if_balanced(88)

if __name__ == '__main__':
    unittest.main()
