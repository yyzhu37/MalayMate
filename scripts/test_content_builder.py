import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from build_starter_deck import build_deck, main


class ContentBuilderTests(unittest.TestCase):
    def write_inputs(
        self,
        tmp_path,
        frequency_rows,
        dictionary_rows,
        sentence_rows=None,
    ):
        frequency_path = tmp_path / "frequency.tsv"
        dictionary_path = tmp_path / "dictionary.jsonl"
        sentences_path = tmp_path / "sentences.tsv"

        frequency_lines = ["term\tcount"]
        frequency_lines.extend(f"{term}\t{count}" for term, count in frequency_rows)
        frequency_path.write_text("\n".join(frequency_lines) + "\n", encoding="utf-8")

        dictionary_path.write_text(
            "".join(json.dumps(row, ensure_ascii=False) + "\n" for row in dictionary_rows),
            encoding="utf-8",
        )

        sentence_lines = ["term\tmalay\tchinese\tsourceUrl"]
        for row in sentence_rows or []:
            sentence_lines.append(
                "\t".join(
                    [
                        row["term"],
                        row["malay"],
                        row.get("chinese", ""),
                        row.get("sourceUrl", ""),
                    ]
                )
            )
        sentences_path.write_text("\n".join(sentence_lines) + "\n", encoding="utf-8")

        return frequency_path, dictionary_path, sentences_path

    def test_build_deck_merges_dictionary_and_sentences(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            frequency_path, dictionary_path, sentences_path = self.write_inputs(
                tmp_path,
                [("makan", 100)],
                [
                    {
                        "term": "makan",
                        "pos": "verb",
                        "zh": "吃；进食",
                        "syllables": ["ma", "kan"],
                        "sourceUrl": "https://example.org/dictionary/makan",
                    }
                ],
                [
                    {
                        "term": "makan",
                        "malay": "Saya makan nasi.",
                        "chinese": "我吃米饭。",
                        "sourceUrl": "https://example.org/sentences/1",
                    }
                ],
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

    def test_missing_dictionary_row_fails_fast(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            frequency_path, dictionary_path, sentences_path = self.write_inputs(
                tmp_path,
                [("makan", 100)],
                [],
            )

            with self.assertRaisesRegex(ValueError, "Missing dictionary row for term 'makan'"):
                build_deck(frequency_path, dictionary_path, sentences_path)

    def test_sorts_by_count_before_applying_limit(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            frequency_path, dictionary_path, sentences_path = self.write_inputs(
                tmp_path,
                [("belajar", 80), ("makan", 100), ("minum", 90)],
                [
                    {"term": "makan", "zh": "吃"},
                    {"term": "minum", "zh": "喝"},
                    {"term": "belajar", "zh": "学习"},
                ],
            )

            payload = build_deck(frequency_path, dictionary_path, sentences_path, limit=2)

        terms = [word["term"] for word in payload["decks"][0]["words"]]
        self.assertEqual(terms, ["makan", "minum"])

    def test_dictionary_accepts_word_key(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            frequency_path, dictionary_path, sentences_path = self.write_inputs(
                tmp_path,
                [("makan", 100)],
                [{"word": "makan", "zh": "吃"}],
            )

            payload = build_deck(frequency_path, dictionary_path, sentences_path)

        self.assertEqual(payload["decks"][0]["words"][0]["chineseMeaning"], "吃")

    def test_generated_ids_are_unique_and_prefixed(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            frequency_path, dictionary_path, sentences_path = self.write_inputs(
                tmp_path,
                [("makan!", 100), ("makan?", 90)],
                [
                    {"term": "makan!", "zh": "吃"},
                    {"term": "makan?", "zh": "吃吗"},
                ],
                [
                    {"term": "makan!", "malay": "Saya makan nasi."},
                    {"term": "makan?", "malay": "Awak makan nasi?"},
                ],
            )

            payload = build_deck(frequency_path, dictionary_path, sentences_path)

        ids = []
        for word in payload["decks"][0]["words"]:
            self.assertTrue(word["id"].startswith("open-frequency-starter-word-"))
            ids.append(word["id"])
            for example in word["examples"]:
                self.assertTrue(example["id"].startswith("open-frequency-starter-example-"))
                ids.append(example["id"])
        self.assertEqual(len(ids), len(set(ids)))

    def test_fallback_example_is_used_when_sentence_is_missing(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            frequency_path, dictionary_path, sentences_path = self.write_inputs(
                tmp_path,
                [("makan", 100)],
                [{"term": "makan", "zh": "吃"}],
            )

            payload = build_deck(frequency_path, dictionary_path, sentences_path)

        example = payload["decks"][0]["words"][0]["examples"][0]
        self.assertEqual(example["malay"], "Saya belajar perkataan makan.")
        self.assertEqual(example["sourceRefs"][0]["sourceUrl"], "local-template://malaymate/fallback-example")

    def test_cli_writes_output_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            frequency_path, dictionary_path, sentences_path = self.write_inputs(
                tmp_path,
                [("makan", 100)],
                [{"term": "makan", "zh": "吃"}],
            )
            output_path = tmp_path / "generated" / "starter_deck.json"

            main(
                [
                    "--frequency",
                    str(frequency_path),
                    "--dictionary",
                    str(dictionary_path),
                    "--sentences",
                    str(sentences_path),
                    "--output",
                    str(output_path),
                    "--limit",
                    "1",
                ]
            )

            payload = json.loads(output_path.read_text(encoding="utf-8"))

        self.assertEqual(payload["generatedAt"], "2026-05-28T00:00:00Z")
        self.assertEqual(payload["decks"][0]["words"][0]["term"], "makan")

    def test_rejects_non_positive_limit(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            frequency_path, dictionary_path, sentences_path = self.write_inputs(
                tmp_path,
                [("makan", 100)],
                [{"term": "makan", "zh": "吃"}],
            )

            with self.assertRaisesRegex(ValueError, "limit must be a positive integer"):
                build_deck(frequency_path, dictionary_path, sentences_path, limit=0)


if __name__ == "__main__":
    unittest.main()
