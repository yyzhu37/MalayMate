#!/usr/bin/env python3
import argparse
import csv
import json
import re
from pathlib import Path
from urllib.parse import quote


SOURCE_URL_BASE = "https://kaikki.org/dictionary/Malay/kaikki.org-dictionary-Malay.jsonl"
ALLOWED_POS = {
    "adj": "adjective",
    "adv": "adverb",
    "classifier": "classifier",
    "conj": "conjunction",
    "det": "determiner",
    "intj": "interjection",
    "noun": "noun",
    "num": "number",
    "particle": "particle",
    "prep": "preposition",
    "pron": "pronoun",
    "verb": "verb",
}
SKIP_GLOSS_PREFIXES = (
    "abbreviation of ",
    "alternative form of ",
    "alternative spelling of ",
    "clipping of ",
    "form of ",
    "jawi spelling of ",
    "nonstandard spelling of ",
    "plural of ",
    "pronunciation spelling of ",
)
SKIP_SENSE_TAGS = {
    "archaic",
    "colloquial",
    "dialectal",
    "informal",
    "nonstandard",
    "obsolete",
    "slang",
    "vulgar",
}
WORD_RE = re.compile(r"^[a-z][a-z-]{2,20}$")


def normalize_entry(entry):
    if entry.get("lang_code") != "ms":
        return None

    word = (entry.get("word") or "").strip()
    pos = entry.get("pos", "")
    if pos not in ALLOWED_POS or not WORD_RE.match(word):
        return None

    gloss = first_gloss(entry.get("senses", []))
    if not gloss:
        return None

    syllables = syllables_from(entry)
    return {
        "term": word,
        "pos": ALLOWED_POS[pos],
        "zh": f"英文释义：{gloss}",
        "pronunciationNotes": pronunciation_from(entry),
        **audio_from(entry),
        "syllables": syllables,
        "examples": examples_from(entry, word),
        "sourceUrl": f"https://en.wiktionary.org/wiki/{quote(word)}#Malay",
        "sourceName": "Kaikki/Wiktionary",
        "license": "open dictionary source",
        "attribution": "Kaikki.org Wiktextract data from Wiktionary contributors",
        "reviewStatus": "needs-review",
    }


def first_gloss(senses):
    for sense in senses:
        if SKIP_SENSE_TAGS.intersection(set(sense.get("tags", []))):
            continue
        for gloss in sense.get("glosses", []):
            cleaned = clean_gloss(gloss)
            if not cleaned:
                continue
            lowered = cleaned.lower()
            if lowered.startswith(SKIP_GLOSS_PREFIXES):
                continue
            return cleaned
    return ""


def clean_gloss(value):
    value = re.sub(r"\s+", " ", value or "").strip()
    value = re.sub(r"^\(.*?\)\s*", "", value)
    return value


def pronunciation_from(entry):
    for sound in entry.get("sounds", []):
        ipa = sound.get("ipa")
        if ipa:
            return ipa
    return ""


def audio_from(entry):
    for sound in entry.get("sounds", []):
        mp3_url = sound.get("mp3_url")
        if mp3_url:
            return {"audioURL": mp3_url, "audioFormat": "mp3"}
        ogg_url = sound.get("ogg_url")
        if ogg_url:
            return {"audioURL": ogg_url, "audioFormat": "ogg"}
    return {}


def syllables_from(entry):
    for hyphenation in entry.get("hyphenations", []):
        parts = [part for part in hyphenation.get("parts", []) if part and re.search(r"[A-Za-z]", part)]
        if parts:
            return parts
    return []


def examples_from(entry, word):
    examples = []
    seen = set()
    for sense in entry.get("senses", []):
        if SKIP_SENSE_TAGS.intersection(set(sense.get("tags", []))):
            continue
        for example in sense.get("examples", []):
            text = clean_example(example.get("text", ""))
            if not text or text.lower() in seen:
                continue
            if word.lower() not in text.lower():
                continue
            seen.add(text.lower())
            examples.append(text)
            if len(examples) >= 2:
                return examples
    return examples


def clean_example(value):
    value = re.sub(r"\s+", " ", value or "").strip()
    if not value or len(value) > 140:
        return ""
    if any(marker in value for marker in ("{", "}", "[", "]", "|")):
        return ""
    return value


def entry_score(row):
    pos_rank = {
        "noun": 0,
        "verb": 1,
        "adjective": 2,
        "adverb": 3,
        "preposition": 4,
        "conjunction": 5,
        "determiner": 6,
        "pronoun": 7,
        "number": 8,
        "interjection": 9,
        "classifier": 10,
        "particle": 11,
    }
    word = row["term"]
    return (pos_rank.get(row["pos"], 99), len(word), word)


def read_frequency(path):
    if path is None:
        return []

    rows = []
    with Path(path).open("r", encoding="utf-8") as handle:
        for line in handle:
            parts = line.strip().split()
            if len(parts) < 2:
                continue
            term = parts[0].strip()
            if not term:
                continue
            try:
                count = int(parts[1])
            except ValueError:
                continue
            rows.append((term, count))
    return rows


def extract_entries(source_path, limit, excluded_terms=None, frequency_path=None):
    excluded_terms = {term.lower() for term in (excluded_terms or set())}
    rows_by_term = {}

    with Path(source_path).open("r", encoding="utf-8") as handle:
        for line in handle:
            if not line.strip():
                continue
            row = normalize_entry(json.loads(line))
            if row is None or row["term"].lower() in excluded_terms:
                continue
            rows_by_term.setdefault(row["term"], row)

    rows = []
    seen_terms = set()
    for term, count in read_frequency(frequency_path):
        row = rows_by_term.get(term)
        if row is None or term in seen_terms:
            continue
        row["_selectionCount"] = count
        rows.append(row)
        seen_terms.add(term)
        if limit is not None and len(rows) >= limit:
            return rows

    fallback_rows = []
    for row in rows_by_term.values():
        if row["term"] in seen_terms:
            continue
        row["_selectionCount"] = 0
        fallback_rows.append(row)
    rows.extend(sorted(fallback_rows, key=entry_score))
    return rows[:limit] if limit is not None else rows


def seed_terms(path):
    payload = json.loads(Path(path).read_text(encoding="utf-8"))
    terms = set()
    for deck in payload.get("decks", []):
        for word in deck.get("words", []):
            term = word.get("term", "").strip().lower()
            if term:
                terms.add(term)
    return terms


def write_dictionary(rows, path):
    output_path = Path(path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        "".join(
            json.dumps(
                {key: value for key, value in row.items() if not key.startswith("_")},
                ensure_ascii=False,
                sort_keys=True,
            )
            + "\n"
            for row in rows
        ),
        encoding="utf-8",
    )


def write_selection(rows, path):
    output_path = Path(path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, delimiter="\t", lineterminator="\n")
        writer.writerow(["term", "count"])
        for offset, row in enumerate(rows):
            writer.writerow([row["term"], row.get("_selectionCount") or len(rows) - offset])


def main(argv=None):
    parser = argparse.ArgumentParser(description="Extract MalayMate dictionary inputs from Kaikki Malay JSONL.")
    parser.add_argument("--source", required=True)
    parser.add_argument("--dictionary-output", required=True)
    parser.add_argument("--selection-output", required=True)
    parser.add_argument("--frequency-source")
    parser.add_argument("--exclude-seed-deck", action="append", default=[])
    parser.add_argument("--limit", type=int, default=300)
    args = parser.parse_args(argv)

    excluded_terms = set()
    for path in args.exclude_seed_deck:
        excluded_terms.update(seed_terms(path))

    rows = extract_entries(
        args.source,
        limit=args.limit,
        excluded_terms=excluded_terms,
        frequency_path=args.frequency_source,
    )
    write_dictionary(rows, args.dictionary_output)
    write_selection(rows, args.selection_output)
    return rows


if __name__ == "__main__":
    main()
