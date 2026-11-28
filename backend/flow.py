import os
from typing import List

from openai import AsyncOpenAI

from schemas import EntryType, KanjiResponse, LlmItem, LlmPayload

client = AsyncOpenAI(api_key=os.getenv("OPENAI_API_KEY"), timeout=30.0)
MODEL = os.getenv("OPENAI_MODEL", "gpt-4o-mini")

KANJI_SYSTEM = """당신은 일본어 한자 학습 콘텐츠 작성자입니다.
사용자 입력(한국어 뜻, 훈음, 일본어 한자/읽기)에 가장 알맞은 일본 상용한자(신자체) 3개를 서로 중복되지 않게 추천하세요.

규칙:
- kind: "kanji"로 고정.
- literal: 한 글자 한자만 (2글자 이상 단어 금지).
- koreanMeaning: 입력을 그대로 복사하지 말고, 해당 한자 고유의 한국 한자사전 '훈 음'을 적으세요 (예: 高→"높을 고", 峰→"봉우리 봉").
- reading: 빈 문자열 "".
- onYomi, kunYomi: 히라가나만 (가타카나 금지). 일상에서 자주 쓰이는 핵심 대표 읽기만 각각 최대 2~3개 이내로 적고, 거의 쓰이지 않는 쪽은 빈 배열 []로 두세요.
- examples: 각 1개. jp는 8~18자의 자연스러운 일본어 문장, ko는 한국어 번역.
"""

WORD_SYSTEM = """당신은 일본어 단어 학습 콘텐츠 작성자입니다.
사용자 입력에 가장 알맞은 일본어 단어 3개를 서로 중복되지 않게 추천하세요.

입력별 선택 기준:
1. 한국어 뜻 입력 (예: "산", "욕하다"): 직접적인 번역어를 1순위로 고르고 입력과 같은 품사를 우선하세요 (예: "욕하다" → 罵る, 貶す, 悪口を言う). 言う, する, いい 같은 기초어로 억지 대체하지 마세요.
2. 일본어 단어 입력 (예: "食べる"): 입력 단어를 첫 번째로 넣고, 나머지는 유의어·반의어·관련어로 채우세요.
3. 읽기(히라가나·가타카나·로마자) 입력: 해당 읽기의 대표 단어를 고르세요.

규칙:
- kind: "word"로 고정.
- literal: 사전 표제어 형태 (동사·형용사는 기본형, な형용사는 な 제외, 짧은 관용구 허용).
- reading: literal 전체의 요미가나. 히라가나만 사용 (가타카나·외래어 표기 금지).
- koreanMeaning: 품사에 맞는 한국어 뜻. 가장 핵심적인 뜻 최대 2개까지만 쉼표로 연결 (전체 15자 이내).
- onYomi, kunYomi: 각각 빈 배열 [].
- examples: 각 1개. jp는 8~18자의 일상 단문, ko는 한국어 번역.
"""


def _to_response(item: LlmItem, entry_type: EntryType) -> KanjiResponse:
    return KanjiResponse(
        literal=item.literal,
        koreanMeaning=item.koreanMeaning.strip(),
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
        _to_response(item, entry_type)
        for item in payload.items[:3]
    ]
