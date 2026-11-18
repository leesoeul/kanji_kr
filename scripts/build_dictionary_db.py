#!/usr/bin/env python3
"""시드 JSON과 오픈소스 사전을 합쳐 assets/db/dictionary.db를 만든다.

출처 (source 컬럼):
- seed: assets/data의 한자·동사. 같은 글자가 있으면 항상 이쪽을 남긴다.
- kanjidic: KANJIDIC2(EDRDG, CC BY-SA 4.0)의 상용한자 음훈·획수·JLPT에
  libhangul hanja.txt(BSD)의 한국어 훈음을 붙인다. 훈음이 없는 한자는 넣지 않는다.
- wiktionary: kaikki.org가 추출한 위키낱말사전 한국어판·일본어판(CC BY-SA 4.0).
  한국어 뜻이 있고 히라가나 읽기를 알 수 있는 일본어 단어(품사 무관)만 넣는다.

원본 파일은 scripts/.dict_cache에 받아 두고 다시 쓴다.
DB 구조나 데이터가 바뀌면 DB_VERSION을 올리고,
lib/core/services/dictionary_db_service.dart의 kDictionaryDbVersion도 같이 올린다.
"""

from __future__ import annotations

import gzip
import json
import re
import sqlite3
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LISTS = ROOT / "assets/data/lists.json"
OUT = ROOT / "assets/db/dictionary.db"
CACHE = ROOT / "scripts/.dict_cache"
DB_VERSION = 4

SOURCES = {
    "kanjidic2.xml.gz": "http://www.edrdg.org/kanjidic/kanjidic2.xml.gz",
    "hanja.txt": "https://raw.githubusercontent.com/libhangul/libhangul/main/data/hanja/hanja.txt",
    "kowikt.jsonl.gz": "https://kaikki.org/kowiktionary/raw-wiktextract-data.jsonl.gz",
    "jawikt.jsonl.gz": "https://kaikki.org/jawiktionary/raw-wiktextract-data.jsonl.gz",
}

# 일반 단어로 볼 품사. 고유명사·한 글자 항목·접사·조사·어간은 뺀다.
WORD_POS = {
    "noun", "verb", "adj", "adj_noun", "adv", "adnominal",
    "pron", "num", "intj", "conj", "counter",
}

# KANJIDIC2의 jlpt는 옛 4단계(4가 가장 쉬움)라 가까운 N등급으로 바꾼다.
JLPT_OLD_TO_N = {"4": "N5", "3": "N4", "2": "N3", "1": "N1"}

SCHEMA = """
CREATE TABLE entries (
  id INTEGER PRIMARY KEY,
  source TEXT NOT NULL,
  source_id TEXT NOT NULL,
  list_id TEXT NOT NULL DEFAULT '',
  literal TEXT NOT NULL,
  reading TEXT NOT NULL DEFAULT '',
  meaning_ko TEXT NOT NULL DEFAULT '',
  meanings_json TEXT NOT NULL DEFAULT '[]',
  kind TEXT NOT NULL CHECK (kind IN ('kanji', 'word')),
  jlpt TEXT NOT NULL DEFAULT '',
  on_yomi TEXT NOT NULL DEFAULT '',
  kun_yomi TEXT NOT NULL DEFAULT '',
  stroke_count INTEGER NOT NULL DEFAULT 0,
  examples_json TEXT NOT NULL DEFAULT '[]',
  search_text TEXT NOT NULL DEFAULT '',
  UNIQUE (source, source_id)
);
CREATE INDEX idx_entries_kind ON entries(kind);
CREATE INDEX idx_entries_literal ON entries(literal);
CREATE INDEX idx_entries_reading ON entries(reading);
CREATE INDEX idx_entries_source ON entries(source);
"""

FTS = """
CREATE VIRTUAL TABLE entries_fts USING fts5(
  literal, reading, meaning_ko,
  content='entries', content_rowid='id',
  tokenize='trigram'
);
INSERT INTO entries_fts(rowid, literal, reading, meaning_ko)
  SELECT id, literal, reading || ' ' || on_yomi || ' ' || kun_yomi, meaning_ko
  FROM entries;
"""

HANGUL = re.compile(r"[가-힣]")
HIRAGANA_ONLY = re.compile(r"^[ぁ-ゖー]+$")
KANA_ONLY = re.compile(r"^[ぁ-ゖァ-ヺー]+$")
KATAKANA_ONLY = re.compile(r"^[ァ-ヺー・]+$")


def is_kanji(ch: str) -> bool:
    return "\u4e00" <= ch <= "\u9fff" or "\u3400" <= ch <= "\u4dbf" or ch == "々"


def to_hiragana(text: str) -> str:
    return "".join(
        chr(ord(ch) - 0x60) if 0x30A1 <= ord(ch) <= 0x30F6 else ch for ch in text
    )


def make_row(
    *,
    source: str,
    source_id: str,
    literal: str,
    kind: str,
    reading: str = "",
    meaning: str = "",
    meanings: list[str] | None = None,
    on: list[str] | None = None,
    kun: list[str] | None = None,
    jlpt: str = "",
    stroke_count: int = 0,
    examples: list[dict] | None = None,
    list_id: str = "",
) -> dict:
    """모든 출처가 같은 규칙으로 행을 만든다. 읽기는 히라가나, 예문이 없으면 []."""
    on = on or []
    kun = kun or []
    meanings = meanings or []
    search_parts = [literal, reading, *on, *kun, meaning, *meanings]
    return {
        "source": source,
        "source_id": source_id,
        "list_id": list_id,
        "literal": literal,
        "reading": reading,
        "meaning_ko": meaning,
        "meanings_json": json.dumps(meanings, ensure_ascii=False),
        "kind": kind,
        "jlpt": jlpt,
        "on_yomi": "・".join(on),
        "kun_yomi": "・".join(kun),
        "stroke_count": stroke_count,
        "examples_json": json.dumps(examples or [], ensure_ascii=False),
        "search_text": " ".join(p for p in search_parts if p).lower(),
    }


def fetch(name: str) -> Path:
    CACHE.mkdir(parents=True, exist_ok=True)
    path = CACHE / name
    if not path.exists():
        print(f"다운로드: {SOURCES[name]}")
        urllib.request.urlretrieve(SOURCES[name], path)
    return path


def jsonl(path: Path):
    with gzip.open(path, "rt", encoding="utf-8") as f:
        for line in f:
            yield json.loads(line)


# ---------------------------------------------------------------- seed


def kana_list(item: dict, key: str) -> list[str]:
    return [
        to_hiragana(r.get("kana", "")).strip()
        for r in item.get(key) or []
        if r.get("kana", "").strip()
    ]


def seed_rows() -> list[dict]:
    rows = []
    for meta in json.loads(LISTS.read_text(encoding="utf-8")):
        items = json.loads((ROOT / meta["asset"]).read_text(encoding="utf-8"))
        for item in items:
            if not item.get("literal"):
                continue
            kind = item.get("kind") or "kanji"
            on = kana_list(item, "onYomi")
            kun = kana_list(item, "kunYomi")
            meanings = [m.strip() for m in item.get("meaningsKo") or [] if m.strip()]
            korean = (item.get("koreanMeaning") or "").strip()
            if kind == "word":
                reading = (item.get("reading") or "").strip() or "・".join(kun)
                meaning = ", ".join(meanings) or korean
            else:
                reading = "・".join(kun + on)
                meaning = korean.replace("/", " · ") or ", ".join(meanings)
            rows.append(
                make_row(
                    source="seed",
                    source_id=item["id"],
                    list_id=meta["id"],
                    literal=item["literal"].strip(),
                    kind=kind,
                    reading=reading,
                    meaning=meaning,
                    meanings=meanings,
                    on=on,
                    kun=kun,
                    jlpt=item.get("jlpt") or "",
                    stroke_count=item.get("strokeCount") or 0,
                    examples=item.get("examples") or [],
                )
            )
    return rows


# ------------------------------------------------------------ kanjidic


def load_hanja() -> dict[str, list[tuple[str, str]]]:
    """한 글자 → [(한글 음, '배울 학, 가르칠 학'), ...]. 뜻이 빈 줄은 뺀다."""
    table: dict[str, list[tuple[str, str]]] = {}
    for line in fetch("hanja.txt").read_text(encoding="utf-8").splitlines():
        if not line or line.startswith("#"):
            continue
        parts = line.split(":", 2)
        if len(parts) != 3 or len(parts[1]) != 1 or not parts[2].strip():
            continue
        table.setdefault(parts[1], []).append((parts[0], parts[2].strip()))
    return table


def jis_variant(code: str, var_type: str) -> str | None:
    """KANJIDIC 변형자 kuten(1-53-60)을 글자로. 신자체 学 → 구자체 學."""
    try:
        _, ku, ten = (int(n) for n in code.split("-"))
        raw = bytes([ku + 0xA0, ten + 0xA0])
        if var_type == "jis212":
            raw = b"\x8f" + raw
        return raw.decode("euc_jp")
    except (ValueError, UnicodeDecodeError):
        return None


def hunEum(chars: list[str], korean: set[str], hanja: dict) -> str:
    """'배울 학 · 가르칠 학'처럼 훈음 최대 2개. KANJIDIC 한국어 음과 맞는 줄을 먼저."""
    for ch in chars:
        lines = hanja.get(ch) or []
        if not lines:
            continue
        lines = sorted(lines, key=lambda line: line[0] not in korean)
        picked: list[str] = []
        for _, meaning in lines:
            for part in meaning.split(","):
                part = part.strip()
                if part and HANGUL.search(part) and part not in picked:
                    picked.append(part)
        if picked:
            return " · ".join(picked[:2])
    return ""


def kanjidic_rows(skip: set[str]) -> list[dict]:
    hanja = load_hanja()
    rows = []
    with gzip.open(fetch("kanjidic2.xml.gz"), "rb") as f:
        for _, el in ET.iterparse(f):
            if el.tag != "character":
                continue
            literal = el.findtext("literal") or ""
            grade = el.findtext("misc/grade")
            # 상용한자: 1~6학년 + 8(중학 이상).
            if grade not in {"1", "2", "3", "4", "5", "6", "8"} or literal in skip:
                el.clear()
                continue
            on, kun, korean = [], [], set()
            for r in el.iter("reading"):
                text = (r.text or "").strip()
                kind = r.get("r_type")
                if kind == "ja_on":
                    value = to_hiragana(text)
                    if value not in on:
                        on.append(value)
                elif kind == "ja_kun":
                    value = text.replace(".", "").strip("-")
                    if value and value not in kun:
                        kun.append(value)
                elif kind == "korean_h":
                    korean.add(text)
            variants = []
            for var in el.iter("variant"):
                var_type, code = var.get("var_type"), (var.text or "").strip()
                if var_type in {"jis208", "jis212"}:
                    variants.append(jis_variant(code, var_type))
                elif var_type == "ucs":
                    variants.append(chr(int(code, 16)))
            meaning = hunEum(
                [literal, *(v for v in variants if v)], korean, hanja
            )
            if meaning:
                rows.append(
                    make_row(
                        source="kanjidic",
                        source_id=literal,
                        literal=literal,
                        kind="kanji",
                        reading="・".join(dict.fromkeys(kun + on)),
                        meaning=meaning,
                        meanings=meaning.split(" · "),
                        on=on,
                        kun=kun,
                        jlpt=JLPT_OLD_TO_N.get(el.findtext("misc/jlpt") or "", ""),
                        stroke_count=int(el.findtext("misc/stroke_count") or 0),
                    )
                )
            el.clear()
    return rows


# ---------------------------------------------------------- wiktionary


def ja_reading_map() -> dict[str, str]:
    """일본어판 위키낱말사전: 한자 단어 → 첫 히라가나 표기(transliteration)."""
    readings: dict[str, str] = {}
    for d in jsonl(fetch("jawikt.jsonl.gz")):
        if d.get("lang_code") != "ja" or d.get("pos") == "character":
            continue
        word = d.get("word") or ""
        if word in readings or not any(is_kanji(ch) for ch in word):
            continue
        for form in d.get("forms") or []:
            tags = form.get("tags") or []
            text = form.get("form") or ""
            if "transliteration" in tags and "kun" not in tags and HIRAGANA_ONLY.match(text):
                readings[word] = text
                break
    return readings


def ruby_reading(form: dict) -> str:
    text = form.get("form") or ""
    for base, kana in form.get("ruby") or []:
        text = text.replace(base, kana, 1)
    return text if HIRAGANA_ONLY.match(to_hiragana(text)) else ""


CATEGORY_READING = re.compile(r"^(.) 글자의 독음이 ([ぁ-ゖ]+)인 일본어 낱말$")


def category_reading(word: str, categories: list[str]) -> str:
    """'電 글자의 독음이 でん인 일본어 낱말' 분류로 글자마다 읽기를 이어 붙인다."""
    per_char = {}
    for cat in categories:
        if m := CATEGORY_READING.match(cat):
            per_char[m.group(1)] = m.group(2)
    if not per_char:
        return ""
    out = "".join(per_char.get(ch, ch) for ch in word)
    return to_hiragana(out) if HIRAGANA_ONLY.match(to_hiragana(out)) else ""


POS_PREFIX = re.compile(
    r"^\s*(?:명사|동사|형용사|형용동사|부사|감탄사|대명사|수사|관형사|연체사|"
    r"접속사|조사|조동사|접두사|접미사|조수사)\s*[:：]\s*"
)
BRACKETS = re.compile(r"\([^()]*\)|（[^（）]*）|\[[^\[\]]*\]|〔[^〔〕]*〕|【[^【】]*】")
NUMBERING = re.compile(r"^\s*(?:\d+[.)]|[①-⑳])\s*")
DEFINITION_TAIL = re.compile(r"(?:이르는 말|하는 일|는 일|는 것|의 일종|의 하나|의 준말)$")
# "고추를 사용한 향신료"처럼 조사가 붙은 설명문. 단어형 뜻에는 거의 없다.
DEFINITION_PARTICLE = re.compile(r"(?:을|를|의|에|에서)\s")
GRAMMAR_TERM = re.compile(
    r"^(?:접속|부|격|종|보|준체)?조사$|^조동사$|^접[두미]사$|"
    r"^(?:대?명사|동사|형용(?:동)?사|부사|감탄사|수사|관형사|연체사|접속사)$"
)
NON_KOREAN = re.compile(r"[ぁ-ヿ一-鿿A-Za-z]")
MAX_SENSE_LEN = 12


def ko_senses(text: str) -> list[str]:
    """위키낱말사전 한국어 뜻 한 줄을 시드처럼 짧은 뜻 목록으로 줄인다.

    품사 접두어·괄호를 지우고 쉼표·세미콜론으로 나눈 뒤,
    12자 이하이고 사전 정의문이 아닌 한국어 뜻만 남긴다.
    """
    text = re.sub(r"\s+", " ", text).strip()
    text = NUMBERING.sub("", POS_PREFIX.sub("", text))
    if text.startswith(("→", "=")):
        return []
    # 괄호는 중첩된 것까지 안쪽부터 지운다.
    while (stripped := BRACKETS.sub("", text)) != text:
        text = stripped
    senses = []
    # 마침표도 "가난. 빈곤. 궁핍"처럼 뜻 구분자로 쓰인다.
    for part in re.split(r"[,;，、；/.。]", text):
        part = part.strip(" ·-:~…")
        if (
            not part
            or len(part) > MAX_SENSE_LEN
            or not HANGUL.search(part)
            or NON_KOREAN.search(part)
            or DEFINITION_TAIL.search(part)
            or DEFINITION_PARTICLE.search(part)
            or GRAMMAR_TERM.match(part)
            or part in senses
        ):
            continue
        senses.append(part)
    return senses


def wiktionary_rows(
    skip: set[str], skip_kana_readings: set[str]
) -> tuple[list[dict], dict[str, int]]:
    """[skip]은 시드 단어 글자, [skip_kana_readings]는 시드 단어 읽기.
    たべる처럼 시드 食べる의 가나 표기만 다른 항목은 넣지 않는다."""
    readings = ja_reading_map()
    merged: dict[tuple[str, str], dict] = {}
    stats = {"no_reading": 0, "no_meaning": 0, "ko": 0, "ja": 0}

    def add(literal: str, reading: str, meanings: list[str], examples: list[dict]):
        if not literal or not reading or not meanings or literal in skip:
            return
        # ヨーヨー 같은 가타카나 외래어는 빼고, 한자·히라가나가 든 단어만 담는다.
        if KATAKANA_ONLY.match(literal):
            stats["katakana"] = stats.get("katakana", 0) + 1
            return
        if KANA_ONLY.match(literal) and reading in skip_kana_readings:
            return
        entry = merged.setdefault(
            (literal, reading), {"meanings": [], "examples": []}
        )
        for meaning in meanings:
            if meaning not in entry["meanings"]:
                entry["meanings"].append(meaning)
        if not entry["examples"]:
            entry["examples"] = examples

    def resolve(literal: str, word: str, categories: list[str], forms: list) -> str:
        if KANA_ONLY.match(literal):
            return to_hiragana(literal)
        for form in forms:
            if "canonical" in (form.get("tags") or []) and (r := ruby_reading(form)):
                return to_hiragana(r)
        if literal in readings:
            return readings[literal]
        if literal.endswith("する") and literal[:-2] in readings:
            return readings[literal[:-2]] + "する"
        if word in readings:
            return readings[word] + ("する" if literal.endswith("する") else "")
        return category_reading(literal, categories)

    # 한국어판: 뜻 자체가 한국어.
    for d in jsonl(fetch("kowikt.jsonl.gz")):
        if d.get("lang_code") != "ja" or d.get("pos") not in WORD_POS:
            continue
        word = (d.get("word") or "").strip()
        forms = d.get("forms") or []
        canonical = next(
            (f["form"] for f in forms if "canonical" in (f.get("tags") or [])), word
        )
        literal = canonical.strip()
        glosses, examples = [], []
        for sense in d.get("senses") or []:
            for gloss in sense.get("glosses") or []:
                for g in ko_senses(gloss):
                    if g not in glosses:
                        glosses.append(g)
            for ex in sense.get("examples") or []:
                text, ko = (ex.get("text") or "").strip(), (ex.get("translation") or "").strip()
                if not examples and text and ko and len(text) <= 40:
                    examples.append({"jp": text, "kana": "", "ko": ko})
        if not glosses:
            stats["no_meaning"] += 1
            continue
        reading = resolve(literal, word, d.get("categories") or [], forms)
        if not reading:
            stats["no_reading"] += 1
            continue
        stats["ko"] += 1
        add(literal, reading, glosses[:3], examples)

    # 일본어판: 번역(translations) 중 한국어.
    for d in jsonl(fetch("jawikt.jsonl.gz")):
        if d.get("lang_code") != "ja" or d.get("pos") not in WORD_POS:
            continue
        ko = []
        for t in d.get("translations") or []:
            if t.get("lang_code") != "ko":
                continue
            for word in ko_senses(t.get("word") or ""):
                if word not in ko:
                    ko.append(word)
        if not ko:
            if any(t.get("lang_code") == "ko" for t in d.get("translations") or []):
                stats["no_meaning"] += 1
            continue
        literal = (d.get("word") or "").strip()
        reading = resolve(literal, literal, [], d.get("forms") or [])
        if not reading:
            stats["no_reading"] += 1
            continue
        stats["ja"] += 1
        add(literal, reading, ko[:3], [])

    # 한국어판에는 規則을 きそく로도 따로 올린 항목이 많다.
    # 같은 읽기의 한자 표기가 있고 뜻이 겹치면 히라가나 항목은 한자 쪽에 합친다.
    by_reading: dict[str, list[tuple[str, str]]] = {}
    for key in merged:
        if not KANA_ONLY.match(key[0]):
            by_reading.setdefault(key[1], []).append(key)
    def senses(entry: dict) -> set[str]:
        return {
            part.strip()
            for meaning in entry["meanings"]
            for part in re.split(r"[,/]", meaning)
            if part.strip()
        }

    for key in [k for k in merged if KANA_ONLY.match(k[0])]:
        kana_entry = merged[key]
        for target in by_reading.get(key[1], []):
            entry = merged[target]
            if senses(entry) & senses(kana_entry):
                if not entry["examples"]:
                    entry["examples"] = kana_entry["examples"]
                del merged[key]
                stats["kana_merged"] = stats.get("kana_merged", 0) + 1
                break

    rows = [
        make_row(
            source="wiktionary",
            source_id=f"{literal}|{reading}",
            literal=literal,
            kind="word",
            reading=reading,
            meaning=", ".join(entry["meanings"][:3]),
            meanings=entry["meanings"][:3],
            examples=entry["examples"],
        )
        for (literal, reading), entry in merged.items()
    ]
    return rows, stats


# ---------------------------------------------------------------- main


def main() -> None:
    seed = seed_rows()
    ids = [r["source_id"] for r in seed]
    dupes = {i for i in ids if ids.count(i) > 1}
    if dupes:
        raise SystemExit(f"중복 id: {sorted(dupes)[:10]}")

    seed_kanji = {r["literal"] for r in seed if r["kind"] == "kanji"}
    seed_words = {r["literal"] for r in seed if r["kind"] == "word"}
    kanji = kanjidic_rows(skip=seed_kanji)
    seed_word_readings = {r["reading"] for r in seed if r["kind"] == "word"}
    words, stats = wiktionary_rows(
        skip=seed_words, skip_kana_readings=seed_word_readings
    )
    rows = seed + kanji + words

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.unlink(missing_ok=True)
    con = sqlite3.connect(OUT)
    con.executescript(SCHEMA)
    columns = list(rows[0].keys())
    con.executemany(
        f"INSERT INTO entries ({', '.join(columns)}) "
        f"VALUES ({', '.join(':' + c for c in columns)})",
        rows,
    )
    try:
        con.executescript(FTS)
        fts = "fts5 trigram"
    except sqlite3.OperationalError as error:
        fts = f"FTS 생략 ({error})"
    con.execute(f"PRAGMA user_version = {DB_VERSION}")
    con.commit()
    con.execute("VACUUM")

    print(f"{OUT.relative_to(ROOT)} v{DB_VERSION}, {fts}")
    for source, kind, count in con.execute(
        "SELECT source, kind, count(*) FROM entries GROUP BY source, kind "
        "ORDER BY source, kind"
    ):
        print(f"  {source:<11} {kind:<6} {count:>6}")
    total = con.execute("SELECT count(*) FROM entries").fetchone()[0]
    con.close()
    print(f"  {'합계':<17} {total:>6}")
    print(
        f"  위키낱말사전 원본: 한국어판 {stats['ko']}, 일본어판 {stats['ja']}, "
        f"읽기를 못 찾아 뺀 항목 {stats['no_reading']}, "
        f"한자 표기로 합친 가나 항목 {stats.get('kana_merged', 0)}"
    )
    print(
        f"  정제 후 뜻이 남지 않아 뺀 항목 {stats['no_meaning']}, "
        f"가타카나 외래어로 뺀 항목 {stats.get('katakana', 0)}"
    )
    print(f"  파일 크기: {OUT.stat().st_size / 1024 / 1024:.2f} MB")


if __name__ == "__main__":
    main()
