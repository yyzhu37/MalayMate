#!/usr/bin/env python3
import argparse
import csv
import hashlib
import json
import re
from pathlib import Path


GENERATED_AT = "2026-05-28T00:00:00Z"
DEFAULT_LICENSE = "Open access; verify source-specific terms before redistribution"
DEFAULT_ATTRIBUTION = "MalayMate local content builder"


def slug(value):
    cleaned = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")
    return cleaned or "item"


def hash_suffix(value, length=10):
    return hashlib.sha256(value.encode("utf-8")).hexdigest()[:length]


def source(
    field,
    source_name,
    source_url,
    license=DEFAULT_LICENSE,
    attribution=DEFAULT_ATTRIBUTION,
    review_status="needs-review",
):
    return {
        "field": field,
        "sourceName": source_name,
        "sourceUrl": source_url,
        "license": license,
        "attribution": attribution,
        "retrievedAt": GENERATED_AT,
        "reviewStatus": review_status,
    }


def read_frequency(path):
    rows = []
    seen_terms = set()
    with Path(path).open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        for row in reader:
            term = row.get("term", "").strip()
            if not term:
                continue
            if term in seen_terms:
                raise ValueError(f"Duplicate frequency term '{term}'")
            seen_terms.add(term)
            rows.append({"term": term, "count": int(row.get("count", "0") or 0)})
    return rows


def read_dictionary(path):
    entries = {}
    with Path(path).open("r", encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, start=1):
            line = line.strip()
            if not line:
                continue
            payload = json.loads(line)
            term = (payload.get("term") or payload.get("word") or "").strip()
            if not term:
                raise ValueError(f"Dictionary row {line_number} must include term or word")
            syllables = payload.get("syllables", [])
            if isinstance(syllables, str):
                syllables = [part.strip() for part in syllables.split(",") if part.strip()]
            entries[term] = {
                "term": term,
                "partOfSpeech": payload.get("partOfSpeech") or payload.get("pos", ""),
                "chineseMeaning": (payload.get("chineseMeaning") or payload.get("zh", "")).strip(),
                "pronunciationNotes": payload.get("pronunciationNotes", ""),
                "syllables": syllables,
                "sourceUrl": payload.get("sourceUrl", ""),
                "sourceName": payload.get("sourceName", "MalayMate sample dictionary"),
                "license": payload.get("license", DEFAULT_LICENSE),
                "attribution": payload.get("attribution", DEFAULT_ATTRIBUTION),
                "reviewStatus": payload.get("reviewStatus", "needs-review"),
            }
    return entries


def read_sentences(path):
    sentences = {}
    with Path(path).open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        for row in reader:
            term = row.get("term", "").strip()
            malay = row.get("malay", "").strip()
            chinese = row.get("chinese", "").strip()
            if not term or not malay:
                continue
            sentences.setdefault(term, []).append(
                {
                    "malay": malay,
                    "chinese": chinese,
                    "sourceUrl": row.get("sourceUrl", "").strip(),
                    "sourceName": row.get("sourceName", "MalayMate sample sentences"),
                    "license": row.get("license", DEFAULT_LICENSE),
                    "attribution": row.get("attribution", DEFAULT_ATTRIBUTION),
                    "reviewStatus": row.get("reviewStatus", "needs-review"),
                }
            )
    return sentences


def fallback_example(term):
    return {
        "malay": f"Saya belajar perkataan {term}.",
        "chinese": f"我学习 {term} 这个词。",
        "sourceUrl": "local-template://malaymate/fallback-example",
        "sourceName": "MalayMate local fallback template",
        "license": "CC0-1.0",
        "attribution": "MalayMate generated fallback example",
        "reviewStatus": "needs-review",
    }


def build_examples(term, rows):
    examples = []
    for example_index, row in enumerate((rows or [fallback_example(term)])[:2], start=1):
        example_hash = hash_suffix(f"{term}\0{row['malay']}")
        examples.append(
            {
                "id": f"open-frequency-starter-example-{slug(term)}-{example_index}-{example_hash}",
                "malay": row["malay"],
                "chinese": row.get("chinese", ""),
                "sourceRefs": [
                    source(
                        "example",
                        row.get("sourceName", "MalayMate sample sentences"),
                        row.get("sourceUrl", ""),
                        row.get("license", DEFAULT_LICENSE),
                        row.get("attribution", DEFAULT_ATTRIBUTION),
                        row.get("reviewStatus", "needs-review"),
                    )
                ],
            }
        )
    return examples


def validate_unique_ids(payload):
    seen = set()
    for deck in payload.get("decks", []):
        deck_id = deck.get("id")
        if deck_id in seen:
            raise ValueError(f"Duplicate generated id: {deck_id}")
        seen.add(deck_id)
        for word in deck.get("words", []):
            word_id = word.get("id")
            if word_id in seen:
                raise ValueError(f"Duplicate generated id: {word_id}")
            seen.add(word_id)
            for example in word.get("examples", []):
                example_id = example.get("id")
                if example_id in seen:
                    raise ValueError(f"Duplicate generated id: {example_id}")
                seen.add(example_id)


def build_deck(frequency, dictionary, sentences, limit=None):
    if limit is not None and limit <= 0:
        raise ValueError("limit must be a positive integer")

    frequency_rows = read_frequency(frequency)
    dictionary_entries = read_dictionary(dictionary)
    sentence_rows = read_sentences(sentences)
    sorted_rows = sorted(frequency_rows, key=lambda row: row["count"], reverse=True)
    selected_rows = sorted_rows[:limit] if limit is not None else sorted_rows

    words = []
    for row in selected_rows:
        term = row["term"]
        entry = dictionary_entries.get(term)
        if entry is None:
            raise ValueError(f"Missing dictionary row for term '{term}'")
        if not entry.get("chineseMeaning"):
            raise ValueError(f"Missing dictionary meaning for term '{term}'")
        source_url = entry.get("sourceUrl", "")
        words.append(
            {
                "id": f"open-frequency-starter-word-{slug(term)}-{hash_suffix(term)}",
                "term": term,
                "languageCode": "ms",
                "chineseMeaning": entry.get("chineseMeaning", ""),
                "partOfSpeech": entry.get("partOfSpeech", ""),
                "pronunciationNotes": entry.get("pronunciationNotes", ""),
                "syllables": entry.get("syllables", []),
                "examples": build_examples(term, sentence_rows.get(term, [])),
                "sourceRefs": [
                    source(
                        "term",
                        entry.get("sourceName", "MalayMate sample dictionary"),
                        source_url,
                        entry.get("license", DEFAULT_LICENSE),
                        entry.get("attribution", DEFAULT_ATTRIBUTION),
                        entry.get("reviewStatus", "needs-review"),
                    ),
                    source(
                        "frequency",
                        "MalayMate sample frequency list",
                        "local-file://content/raw/sample_frequency.tsv",
                        DEFAULT_LICENSE,
                        DEFAULT_ATTRIBUTION,
                        "needs-review",
                    ),
                ],
            }
        )

    payload = {
        "version": 1,
        "generatedAt": GENERATED_AT,
        "decks": [
            {
                "id": "starter-local-open-access",
                "name": "Starter Local Open-Access",
                "description": "Locally built Malay starter deck from open-access source files.",
                "isStarter": True,
                "words": words,
            }
        ],
    }
    validate_unique_ids(payload)
    return payload


def main(argv=None):
    parser = argparse.ArgumentParser(description="Build a MalayMate starter deck JSON file.")
    parser.add_argument("--frequency", required=True)
    parser.add_argument("--dictionary", required=True)
    parser.add_argument("--sentences", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--limit", type=int, default=None)
    args = parser.parse_args(argv)

    payload = build_deck(args.frequency, args.dictionary, args.sentences, args.limit)
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
