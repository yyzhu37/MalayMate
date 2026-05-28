import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from build_starter_deck import build_deck, main, read_dictionary
from extract_kaikki_dictionary import extract_entries, normalize_entry


class ContentBuilderTests(unittest.TestCase):
    def write_inputs(
        self,
        tmp_path,
        frequency_rows,
        dictionary_rows,
        sentence_rows=None,
    ):
        tmp_path.mkdir(parents=True, exist_ok=True)
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

    def test_multiple_dictionary_files_keep_first_entry_as_override(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            first = tmp_path / "first.jsonl"
            second = tmp_path / "second.jsonl"
            first.write_text(json.dumps({"term": "makan", "zh": "吃"}, ensure_ascii=False) + "\n", encoding="utf-8")
            second.write_text(json.dumps({"term": "makan", "zh": "to eat"}, ensure_ascii=False) + "\n", encoding="utf-8")

            entries = read_dictionary([first, second])

        self.assertEqual(entries["makan"]["chineseMeaning"], "吃")

    def test_extracts_kaikki_entry_to_builder_dictionary_row(self):
        payload = {
            "word": "rumah",
            "lang_code": "ms",
            "pos": "noun",
            "sounds": [
                {"ipa": "/rumah/"},
                {"mp3_url": "https://upload.wikimedia.org/rumah.mp3"},
            ],
            "hyphenations": [{"parts": ["ru", "mah"]}],
            "senses": [
                {
                    "glosses": ["house; home"],
                    "examples": [{"text": "rumah besar"}],
                }
            ],
        }

        row = normalize_entry(payload)

        self.assertEqual(row["term"], "rumah")
        self.assertEqual(row["pos"], "noun")
        self.assertEqual(row["zh"], "英文释义：house; home")
        self.assertEqual(row["pronunciationNotes"], "/rumah/")
        self.assertEqual(row["audioURL"], "https://upload.wikimedia.org/rumah.mp3")
        self.assertEqual(row["audioFormat"], "mp3")
        self.assertEqual(row["syllables"], ["ru", "mah"])
        self.assertEqual(row["examples"], ["rumah besar"])
        self.assertEqual(row["sourceName"], "Kaikki/Wiktionary")

    def test_build_deck_uses_dynamic_deck_name_and_preserves_audio_metadata(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            frequency_path, dictionary_path, sentences_path = self.write_inputs(
                tmp_path,
                [("makan", 100), ("minum", 90)],
                [
                    {
                        "term": "makan",
                        "zh": "吃",
                        "audioURL": "https://upload.wikimedia.org/makan.mp3",
                        "audioFormat": "mp3",
                    },
                    {"term": "minum", "zh": "喝"},
                ],
            )

            payload = build_deck(frequency_path, dictionary_path, sentences_path)

        deck = payload["decks"][0]
        self.assertEqual(deck["name"], "Open Dictionary Malay 2")
        self.assertTrue(deck["description"].startswith("2 frequency-ranked"))
        source_ref = deck["words"][0]["sourceRefs"][0]
        self.assertEqual(source_ref["audioURL"], "https://upload.wikimedia.org/makan.mp3")
        self.assertEqual(source_ref["audioFormat"], "mp3")

    def test_build_deck_uses_dictionary_examples_before_template_fallback(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            frequency_path, dictionary_path, sentences_path = self.write_inputs(
                tmp_path,
                [("rumah", 100)],
                [
                    {
                        "term": "rumah",
                        "zh": "房子",
                        "examples": ["rumah besar"],
                        "sourceName": "Kaikki/Wiktionary",
                        "sourceUrl": "https://en.wiktionary.org/wiki/rumah#Malay",
                    }
                ],
            )

            payload = build_deck(frequency_path, dictionary_path, sentences_path)

        example = payload["decks"][0]["words"][0]["examples"][0]
        self.assertEqual(example["malay"], "rumah besar")
        self.assertEqual(example["sourceRefs"][0]["sourceName"], "Kaikki/Wiktionary")

    def test_extract_entries_filters_non_lemma_rows_and_limits_output(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            source = tmp_path / "kaikki.jsonl"
            frequency = tmp_path / "frequency.txt"
            source.write_text(
                "\n".join(
                    [
                        json.dumps({"word": "Rumah", "lang_code": "ms", "pos": "name", "senses": [{"glosses": ["a name"]}]}),
                        json.dumps({"word": "rumah", "lang_code": "ms", "pos": "noun", "senses": [{"glosses": ["house"]}]}),
                        json.dumps({"word": "makan", "lang_code": "ms", "pos": "verb", "senses": [{"glosses": ["to eat"]}]}),
                        json.dumps({"word": "jalan raya", "lang_code": "ms", "pos": "noun", "senses": [{"glosses": ["road"]}]}),
                    ]
                )
                + "\n",
                encoding="utf-8",
            )
            frequency.write_text("makan 100\nrumah 90\n", encoding="utf-8")

            rows = extract_entries(source, limit=1, excluded_terms={"makan"}, frequency_path=frequency)

        self.assertEqual([row["term"] for row in rows], ["rumah"])

    def test_extract_entries_uses_frequency_order_when_available(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            source = tmp_path / "kaikki.jsonl"
            frequency = tmp_path / "frequency.txt"
            source.write_text(
                "\n".join(
                    [
                        json.dumps({"word": "api", "lang_code": "ms", "pos": "noun", "senses": [{"glosses": ["fire"]}]}),
                        json.dumps({"word": "rumah", "lang_code": "ms", "pos": "noun", "senses": [{"glosses": ["house"]}]}),
                    ]
                )
                + "\n",
                encoding="utf-8",
            )
            frequency.write_text("rumah 200\napi 100\n", encoding="utf-8")

            rows = extract_entries(source, limit=2, frequency_path=frequency)

        self.assertEqual([row["term"] for row in rows], ["rumah", "api"])
        self.assertEqual([row["_selectionCount"] for row in rows], [200, 100])

    def test_kaikki_normalizer_skips_abbreviations_and_pronunciation_spellings(self):
        abbreviation = {
            "word": "aq",
            "lang_code": "ms",
            "pos": "pron",
            "senses": [{"glosses": ["abbreviation of aku"]}],
        }
        pronunciation_spelling = {
            "word": "ape",
            "lang_code": "ms",
            "pos": "pron",
            "senses": [{"glosses": ["pronunciation spelling of apa"]}],
        }

        self.assertIsNone(normalize_entry(abbreviation))
        self.assertIsNone(normalize_entry(pronunciation_spelling))

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

    def test_word_ids_are_stable_when_frequency_order_changes(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            dictionary_rows = [
                {"term": "makan", "zh": "吃"},
                {"term": "minum", "zh": "喝"},
                {"term": "belajar", "zh": "学习"},
            ]
            first_frequency, first_dictionary, first_sentences = self.write_inputs(
                tmp_path / "first",
                [("makan", 100), ("minum", 90), ("belajar", 80)],
                dictionary_rows,
            )
            second_frequency, second_dictionary, second_sentences = self.write_inputs(
                tmp_path / "second",
                [("belajar", 500), ("minum", 90), ("makan", 10)],
                dictionary_rows,
            )

            first_payload = build_deck(first_frequency, first_dictionary, first_sentences)
            second_payload = build_deck(second_frequency, second_dictionary, second_sentences)

        first_ids = {word["term"]: word["id"] for word in first_payload["decks"][0]["words"]}
        second_ids = {word["term"]: word["id"] for word in second_payload["decks"][0]["words"]}
        self.assertEqual(first_ids["makan"], second_ids["makan"])

    def test_rejects_duplicate_frequency_terms(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            frequency_path, dictionary_path, sentences_path = self.write_inputs(
                tmp_path,
                [("makan", 100), ("makan", 90)],
                [{"term": "makan", "zh": "吃"}],
            )

            with self.assertRaisesRegex(ValueError, "Duplicate frequency term 'makan'"):
                build_deck(frequency_path, dictionary_path, sentences_path)

    def test_rejects_whitespace_only_dictionary_meaning(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            frequency_path, dictionary_path, sentences_path = self.write_inputs(
                tmp_path,
                [("makan", 100)],
                [{"term": "makan", "zh": "   "}],
            )

            with self.assertRaisesRegex(ValueError, "Missing dictionary meaning for term 'makan'"):
                build_deck(frequency_path, dictionary_path, sentences_path)

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
