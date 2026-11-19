import os
from typing import List

from openai import AsyncOpenAI

from schemas import EntryType, KanjiResponse, LlmItem, LlmPayload

client = AsyncOpenAI(api_key=os.getenv("OPENAI_API_KEY"), timeout=30.0)
MODEL = os.getenv("OPENAI_MODEL", "gpt-4o-mini")

KANJI_SYSTEM = """당신은 일본어 한자 학습 콘텐츠 작성자입니다.
사용자 입력(한국어 뜻, 훈음, 또는 일본어 한자/읽기)과 의미가 가장 정확히 일치하는 일본 한자(신자체) 3개를 추천하세요.

규칙:
- 한국어 뜻이 입력되면 그 뜻을 직접 나타내는 한자를 1순위로 고르세요. (입력 단어를 그대로 복사하지 말고 해당 한자의 정확한 한국 한자사전 훈음을 적으세요.)
- koreanMeaning: 반드시 "훈 음" 형식. 예: "산 산", "곶 갑", "높을 고". 서술형 금지.
- onYomi, kunYomi: 히라가나만. 가타카나 금지. 일본어 사전에 등재된 대표 음읽기와 훈읽기를 반드시 채우세요. (상용한자 표 외 읽기라도 실제로 쓰이는 읽기가 있으면 포함하고, 정말로 아예 존재하지 않는 경우에만 빈 배열 []을 쓰세요.)
- examples: 각 한자마다 1개. jp는 8~18자의 자연스러운 일본어 문장. kana는 문장 전체 히라가나. ko는 한국어 번역.
- jlpt는 N1~N5, strokeCount는 획수.
- items 배열에 한자 객체 3개만 넣으세요.
"""

WORD_SYSTEM = """당신은 일본어 단어 학습 콘텐츠 작성자입니다.
사용자 입력에 가장 알맞은 일본어 단어 3개를 추천하세요.
단어는 명사·동사·い형용사·な형용사·부사 등 품사를 가리지 않습니다.

입력 유형별 선택 기준:
1. 입력이 한국어 뜻인 경우 (예: "산", "욕하다", "예쁘다", "천천히"):
   - 그 한국어 뜻의 **직접적인 일본어 번역어**를 가장 먼저 고르고, 입력과 같은 품사를 우선하세요.
     (예: "산" → 山, 山岳, 峰 / "욕하다" → 罵る, 貶す, 悪口を言う / "예쁘다" → 綺麗, 可愛い, 美しい)
   - 뜻이 뭉뚱그려지는 기초어(言う, する, いい, もの 등)로 억지 대체하지 마세요.
2. 입력이 일본어 단어인 경우 (예: "食べる", "静か"):
   - 입력된 단어 자체를 첫 번째로 넣고, 나머지는 밀접한 유의어·반의어·관련어를 고르세요.
3. 입력이 히라가나·가타카나·로마자 읽기인 경우 (예: "やま", "yama"):
   - 그 읽기를 가진 대표 단어를 고르세요. 동음이의어가 있으면 서로 다른 단어로 채우세요.

규칙:
- literal: 사전에 실리는 표제어 형태. 동사·형용사는 기본형(사전형), な형용사는 な 없이(静か), 명사는 그대로.
  단일 단어로 뜻이 안 살면 '悪口を言う' 같은 짧은 관용구도 허용.
- reading: literal 전체의 요미가나. 히라가나만 사용 (가타카나 금지, 외래어도 히라가나로).
- koreanMeaning: 품사에 맞는 자연스러운 한국어 뜻. 동사는 "~하다", 형용사는 "~하다/~다", 명사는 명사형. 여러 뜻은 쉼표로 연결.
- examples: 각 단어마다 1개. jp는 8~18자의 일상 단문(활용 가능). kana는 문장 전체 히라가나. ko는 한국어.
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
