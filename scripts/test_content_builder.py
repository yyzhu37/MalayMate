import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from build_starter_deck import build_deck


class ContentBuilderTests(unittest.TestCase):
    def test_build_deck_merges_dictionary_and_sentences(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            frequency_path = tmp_path / "frequency.tsv"
            dictionary_path = tmp_path / "dictionary.jsonl"
            sentences_path = tmp_path / "sentences.tsv"

            frequency_path.write_text("term\tcount\nmakan\t100\n", encoding="utf-8")
            dictionary_path.write_text(
                json.dumps(
                    {
                        "term": "makan",
                        "pos": "verb",
                        "zh": "吃；进食",
                        "syllables": ["ma", "kan"],
                        "sourceUrl": "https://example.org/dictionary/makan",
                    },
                    ensure_ascii=False,
                )
                + "\n",
                encoding="utf-8",
            )
            sentences_path.write_text(
                "term\tmalay\tchinese\tsourceUrl\n"
                "makan\tSaya makan nasi.\t我吃米饭。\thttps://example.org/sentences/1\n",
                encoding="utf-8",
            )

            payload = build_deck(
                frequency_path,
                dictionary_path,
                sentences_path,
                limit=2,
            )

        self.assertEqual(payload["version"], 1)
        first_word = payload["decks"][0]["words"][0]
        self.assertEqual(first_word["term"], "makan")
        self.assertEqual(first_word["chineseMeaning"], "吃；进食")
        self.assertEqual(first_word["examples"][0]["malay"], "Saya makan nasi.")


if __name__ == "__main__":
    unittest.main()
