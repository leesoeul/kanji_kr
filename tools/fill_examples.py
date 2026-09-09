#!/usr/bin/env python3
"""각 한자/동사마다 고유하고 자연스러운 예문을 생성합니다."""

from __future__ import annotations

import json
import os
import time
from pathlib import Path

from dotenv import load_dotenv
from openai import OpenAI

ROOT = Path(__file__).resolve().parents[1]
load_dotenv(ROOT / "backend/.env")

FILES = [
    ROOT / "assets/data/kanji/beg.json",
    ROOT / "assets/data/kanji/mid.json",
    ROOT / "assets/data/kanji/adv.json",
    ROOT / "assets/data/word/verb_beg.json",
    ROOT / "assets/data/word/verb_mid.json",
    ROOT / "assets/data/word/verb_adv.json",
]

BATCH = 15
MODEL = os.getenv("OPENAI_MODEL", "gpt-4o-mini")
if "/?" not in MODEL and not MODEL.startswith("gpt"):
    MODEL = "gpt-4o-mini"
if MODEL.startswith("openai/"):
    MODEL = MODEL.split("/", 1)[1]

SYSTEM = """당신은 한국인을 위한 일본어 학습 앱의 예문 작가입니다.
각 항목(한자 또는 동사)마다 실용적이고 자연스러운 예문 1개를 만들어주세요.

필수 규칙:
1. 주어진 literal(한자 또는 동사)을 문장 안에 반드시 포함할 것
2. 동사는 사전형(辞書形)으로 사용하거나 자연스러운 활용형 사용
3. 초급~중급 학습자가 이해할 수 있는 짧고 명확한 문장
4. 의미(koreanMeaning)에 맞는 실제 사용 상황 반영
5. 각 항목마다 다른 문장 구조와 상황 사용 (패턴 반복 금지)
6. 후리가나/로마자/괄호 읽기 절대 금지
7. 한국어 번역은 자연스러운 한국어로 작성

절대 금지 패턴:
- "〜を勉強します", "〜ことがあります", "〜のが好きです", "〜のが大切です"
- "私は〜", "〜です/ます"로 끝나는 단조로운 문장 반복
- 뜻을 그대로 옮긴 어색한 문장 (예: "私はいることがあります")

좋은 예문 예시:
- 한자 '山': "富士山は日本で一番高い。" / "후지산은 일본에서 가장 높다."
- 동사 'いる': "猫が部屋にいる。" / "고양이가 방에 있다."
- 동사 '行く': "週末、友達と映画館に行った。" / "주말에 친구와 영화관에 갔다."

JSON 형식으로만 반환: {"examples":[{"id":"...","jp":"...","ko":"..."}]}
"""


def first_kana(readings: object) -> str:
    if not isinstance(readings, list) or not readings:
        return ""
    first = readings[0]
    if isinstance(first, dict):
        return str(first.get("kana") or "")
    return ""


def payload_for(item: dict) -> dict:
    kind = item.get("kind") or "kanji"
    row = {
        "id": item["id"],
        "kind": kind,
        "literal": item["literal"],
        "meaning": item.get("koreanMeaning") or "",
    }
    if kind == "word":
        row["reading"] = item.get("reading") or ""
    else:
        row["kun"] = first_kana(item.get("kunYomi"))
        row["on"] = first_kana(item.get("onYomi"))
    return row


def request_batch(client: OpenAI, batch: list[dict]) -> dict[str, dict]:
    user = (
        "다음 항목들의 예문을 만들어주세요. 각각 다른 문장 구조를 사용하세요:\\n"
        + json.dumps(batch, ensure_ascii=False)
    )
    last_error = None
    for attempt in range(4):
        try:
            response = client.chat.completions.create(
                model=MODEL,
                temperature=0.8,  # 더 다양한 응답을 위해 temperature 증가
                response_format={"type": "json_object"},
                messages=[
                    {"role": "system", "content": SYSTEM},
                    {"role": "user", "content": user},
                ],
            )
            raw = response.choices[0].message.content or "{}"
            data = json.loads(raw)
            rows = data.get("examples") or data.get("items") or []
            result: dict[str, dict] = {}
            for row in rows:
                item_id = row.get("id")
                jp = (row.get("jp") or "").strip()
                ko = (row.get("ko") or "").strip()
                if item_id and jp and ko:
                    result[item_id] = {"jp": jp, "kana": "", "ko": ko}
            return result
        except Exception as error:  # noqa: BLE001
            last_error = error
            time.sleep(1.5 * (attempt + 1))
    raise RuntimeError(f"batch failed: {last_error}")


def is_bad_example(jp: str) -> bool:
    """템플릿이거나 품질이 낮은 예문 판별"""
    bad_patterns = [
        "勉強します",
        "ことがあります",
        "のが好きです",
        "のが大切です",
        "わたしは",
        "私は",
    ]
    return any(pattern in jp for pattern in bad_patterns)


def apply_examples(items: list[dict], examples: dict[str, dict]) -> int:
    filled = 0
    for item in items:
        example = examples.get(item["id"])
        if example is None:
            continue
        literal = item["literal"]
        if literal not in example["jp"]:
            continue
        if is_bad_example(example["jp"]):
            continue
        item["examples"] = [example]
        item.pop("hint", None)
        item.pop("koreanHanja", None)
        filled += 1
    return filled


def process_file(client: OpenAI, path: Path) -> None:
    items = json.loads(path.read_text(encoding="utf-8"))
    print(f"\\n{'='*60}")
    print(f"처리 중: {path.relative_to(ROOT)} (총 {len(items)}개 항목)")
    print(f"{'='*60}")
    
    total_filled = 0
    for start in range(0, len(items), BATCH):
        batch_items = items[start : start + BATCH]
        payload = [payload_for(item) for item in batch_items]
        
        print(f"\\n[{start + 1}-{start + len(batch_items)}] 예문 생성 중...", end=" ", flush=True)
        examples = request_batch(client, payload)
        filled = apply_examples(batch_items, examples)
        
        # 품질이 낮은 예문이 있으면 재생성
        missing = [
            item["id"]
            for item in batch_items
            if not item.get("examples")
            or is_bad_example(item["examples"][0].get("jp", ""))
        ]
        
        if missing:
            print(f"재생성 중({len(missing)}개)...", end=" ", flush=True)
            retry_payload = [
                payload_for(item) for item in batch_items if item["id"] in missing
            ]
            retry = request_batch(client, retry_payload)
            filled += apply_examples(batch_items, retry)
        
        total_filled += filled
        print(f"완료 ({filled}개 성공)")
        
        # 중간 저장
        if (start + BATCH) % (BATCH * 5) == 0:
            path.write_text(
                json.dumps(items, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )
            print(f"  → 중간 저장 완료")
    
    # 최종 저장
    path.write_text(
        json.dumps(items, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"\\n✓ 완료: 총 {total_filled}개 예문 생성")


def main() -> None:
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise SystemExit("OPENAI_API_KEY가 설정되지 않았습니다.")
    
    client = OpenAI(api_key=api_key.strip().strip('"'))
    
    print("\\n" + "="*60)
    print("예문 생성 시작")
    print("="*60)
    
    for path in FILES:
        try:
            process_file(client, path)
        except Exception as e:
            print(f"\\n✗ 오류 발생: {path.name}")
            print(f"  {str(e)}")
            continue
    
    print("\\n" + "="*60)
    print("모든 파일 처리 완료!")
    print("="*60)


if __name__ == "__main__":
    main()
