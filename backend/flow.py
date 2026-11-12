import os
from typing import List

from openai import AsyncOpenAI

from schemas import EntryType, KanjiResponse, LlmItem, LlmPayload

client = AsyncOpenAI(api_key=os.getenv("OPENAI_API_KEY"), timeout=30.0)
MODEL = os.getenv("OPENAI_MODEL", "gpt-4o-mini")

KANJI_SYSTEM = """당신은 일본어 한자 학습 콘텐츠 작성자입니다.
사용자 입력(한국어 뜻, 훈음, 또는 일본어 한자/읽기)과 의미가 가장 정확히 일치하는 일본 상용 한자(신자체) 3개를 추천하세요.

규칙:
- 한국어 뜻이 입력되면 그 뜻을 직접 나타내는 한자를 1순위로 고르세요.
- koreanMeaning: 한국 한자사전 훈음 형식. 예: "상대할 대 · 대답할 대". 서술형 금지.
- onYomi, kunYomi: 히라가나만. 가타카나 금지. 대표 읽기만 (없으면 빈 배열).
- examples: 각 한자마다 1개. jp는 8~18자의 자연스러운 일본어 문장. kana는 문장 전체 히라가나. ko는 한국어 번역.
- jlpt는 N1~N5, strokeCount는 획수.
- items 배열에 한자 객체 3개만 넣으세요.
"""

WORD_SYSTEM = """당신은 일본어 동사 학습 콘텐츠 작성자입니다.
사용자 입력에 가장 알맞은 일본어 동사 3개를 추천하세요.

입력 유형별 선택 기준:
1. 입력이 한국어 동사 뜻인 경우 (예: "욕하다", "망설이다"):
   - 그 한국어 뜻의 **직접적인 일본어 번역어**를 가장 먼저 고르세요. (예: "욕하다" → 罵る, 貶す, 悪口を言う)
   - 의미가 뭉뚱그려지는 기초 동사(言う, 話す, 行く, 見る, 食べる, する 등)로 억지 대체하지 마세요.
2. 입력이 일본어 동사인 경우 (예: "食べる"):
   - 입력된 동사 자체 또는 밀접한 유의어·반의어·복합동사를 고르세요.
3. 입력이 명사·장소·사물인 경우 (예: "산"):
   - 그것을 목적어나 대상으로 하는 동사를 고르세요. (예: 登る, 下山する, 越える)

규칙:
- literal: 동사 기본형(사전형)을 우선하되, 단일 동사로 뜻이 안 살면 '悪口を言う' 같은 짧은 동사구(관용구)도 허용. 명사·형용사 단독 사용 금지.
- reading: literal 전체의 요미가나. 히라가나만 사용 (가타카나 금지).
- koreanMeaning: "~하다, ~되다" 형태의 동사 뜻. 여러 뜻은 쉼표로 연결.
- examples: 각 동사마다 1개. jp는 8~18자의 일상 단문(활용 가능). kana는 문장 전체 히라가나. ko는 한국어.
- jlpt는 N1~N5. onYomi, kunYomi는 빈 배열, strokeCount는 0.
- 세 항목은 서로 중복되지 않아야 하며, items 배열에 3개만 넣으세요.
"""


def _to_response(item: LlmItem, index: int, entry_type: EntryType) -> KanjiResponse:
    meaning = item.koreanMeaning.strip()
    return KanjiResponse(
        id=f"ai_suggestion_{index + 1}",
        literal=item.literal,
        jlpt=item.jlpt or "N5",
        strokeCount=item.strokeCount if entry_type == EntryType.kanji else 0,
        koreanMeaning=meaning,
        meaningsKo=[meaning] if meaning else [],
        onYomi=item.onYomi if entry_type == EntryType.kanji else [],
        kunYomi=item.kunYomi if entry_type == EntryType.kanji else [],
        examples=item.examples[:1],
        kind=entry_type.value,
        reading=item.reading if entry_type == EntryType.word else "",
    )


async def generate_suggestions(text: str, entry_type: EntryType) -> List[KanjiResponse]:
    is_word = entry_type == EntryType.word
    completion = await client.beta.chat.completions.parse(
        model=MODEL,
        messages=[
            {
                "role": "system",
                "content": WORD_SYSTEM if is_word else KANJI_SYSTEM,
            },
            {
                "role": "user",
                "content": f"입력: {text.strip()}",
            },
        ],
        response_format=LlmPayload,
        temperature=0.4,
        max_tokens=1500,
    )

    payload = completion.choices[0].message.parsed
    if payload is None or not payload.items:
        raise ValueError("모델이 추천을 만들지 못했습니다")

    return [
        _to_response(item, i, entry_type)
        for i, item in enumerate(payload.items[:3])
    ]
