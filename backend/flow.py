import os
from typing import List

from openai import AsyncOpenAI

from schemas import EntryType, KanjiResponse, LlmItem, LlmPayload

client = AsyncOpenAI(api_key=os.getenv("OPENAI_API_KEY"), timeout=30.0)
MODEL = os.getenv("OPENAI_MODEL", "gpt-4o-mini")

KANJI_SYSTEM = """당신은 일본어 한자 학습 콘텐츠 작성자입니다.
사용자 입력과 가장 관련 있는 일본 상용 한자(신자체) 3개를 추천하세요.

규칙:
- koreanMeaning: 한국 한자사전 훈음. 예: "상대할 대 · 대답할 대". 서술형 금지.
- onYomi, kunYomi: 히라가나만. 가타카나 금지. 대표 읽기만.
- examples: 각 한자마다 1개. jp는 10~18자의 완전한 문장. kana는 문장 전체 히라가나. ko는 한국어.
- jlpt는 N1~N5, strokeCount는 획수.
- items 배열에 한자 객체 3개만 넣으세요.
"""

WORD_SYSTEM = """당신은 일본어 동사 학습 콘텐츠 작성자입니다.
사용자 입력과 가장 관련 있고 자주 쓰이는 일본어 동사 3개를 추천하세요.

규칙:
- literal: 동사 기본형(사전형)만. 명사·형용사·구문 금지. 복합동사 가능.
- reading: 동사 전체 요미가나. 히라가나만. 가타카나 금지.
- koreanMeaning: "~하다, ~되다" 동사형. 여러 뜻은 쉼표로 연결.
- examples: 각 동사마다 1개. jp는 10~18자의 일상 단문(활용 가능). kana는 문장 전체 히라가나. ko는 한국어.
- jlpt는 N1~N5. onYomi, kunYomi는 빈 배열, strokeCount는 0.
- items 배열에 동사 객체 3개만 넣으세요.
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
                "content": text.strip(),
            },
        ],
        response_format=LlmPayload,
        temperature=0.4,
        max_tokens=900,
    )

    payload = completion.choices[0].message.parsed
    if payload is None or not payload.items:
        raise ValueError("모델이 추천을 만들지 못했습니다")

    return [
        _to_response(item, i, entry_type)
        for i, item in enumerate(payload.items[:3])
    ]
