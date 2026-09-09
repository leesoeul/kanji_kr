import os
from crewai import Agent, Task, Crew, LLM
from crewai.flow.flow import Flow, listen, start
from schemas import SuggestionState, KanjiResponse, ReadingModel, ExampleModel, EntryType
from typing import List
import json

# CrewAI LLM 설정
_model = os.getenv("OPENAI_MODEL", "gpt-4o-mini")
if "/" not in _model:
    _model = f"openai/{_model}"
llm = LLM(
    model=_model,
    api_key=os.getenv("OPENAI_API_KEY"),
)

# 프롬프트 템플릿
KANJI_PROMPT = """
당신은 전문 일본어 교육 콘텐츠 작성자입니다.
사용자가 '{input_text}'를 입력했습니다. 이와 가장 관련성이 높고 유용한 일본 상용 한자(신자체) 3개를 추천해주세요.

[작성 규칙]
1. koreanMeaning: 한국 한자사전의 훈음 형식으로 작성 (예: "상대할 대", "살 생"). 여러 뜻은 가운뎃점(·) 연결 (예: "상대할 대 · 대답할 대"). 서술형이나 단순 음 표기 금지.
2. onYomi & kunYomi:
   - 음독과 훈독 모두 반드시 '히라가나'로만 작성 (가타카나 절대 금지).
   - 대표적인 읽기를 포함 (예: たい, つい).
3. examples (예문):
   - 모바일 화면 크기에 맞춰 **10~18자 내외의 간결한 완전한 문장**으로 작성하세요. (장문 금지)
   - 단순 단어 나열("対話する")은 안 되지만, 불필요하게 수식어가 긴 문장도 지양합니다.
   - 예시 스타일: "質問に対してすぐに答えた。(질문에 바로 대답했다.)"

각 한자에 대해 다음 JSON 배열 규격을 엄격히 지켜 반환하세요:
[
  {{
    "literal": "対",
    "koreanMeaning": "상대할 대 · 대답할 대",
    "onYomi": [{{"kana": "たい"}}, {{"kana": "つい"}}],
    "kunYomi": [{{"kana": "こたえる"}}],
    "examples": [
      {{
        "jp": "質問に対してすぐに答えた。",
        "kana": "しつもんにたいしてすぐにこたえた。",
        "ko": "질문에 바로 대답했다."
      }}
    ],
    "jlpt": "N3",
    "strokeCount": 7
  }}
]

반드시 위 조건을 충족하는 3개의 한자 객체를 JSON 배열 형식으로만 반환하세요.
"""

WORD_PROMPT = """
당신은 전문 일본어 교육 콘텐츠 작성자입니다.
사용자가 '{input_text}'를 입력했습니다. 이와 가장 관련성이 높고 실생활/시험에 자주 쓰이는 일본어 '동사(Verb)' 3개를 추천해주세요.

[작성 규칙]
1. literal: 반드시 동사의 '기본형(사전형)'으로 표기하세요 (명사, 형용사, 구문 절대 금지). 복합동사(落ち込む 등)도 가능합니다.
2. reading: 해당 동사 전체의 요미가나를 반드시 '히라가나'로만 작성하세요 (가타카나 금지).
3. koreanMeaning:
   - 반드시 '~하다, ~되다' 등 동사형 뜻으로 명확히 작성하세요.
   - 대표 의미가 여러 개면 쉼표(,)로 연결하세요 (예: "우울해지다, 낙담하다", "부러워하다").
4. examples (예문):
   - 모바일 카드 UI에 맞춰 **10~18자 내외의 간결한 일상 단문**으로 작성하세요 (장문 금지).
   - jp: 해당 동사가 자연스럽게 활용(과거형, te형, 기본형 등)된 일본어 문장
   - kana: jp 문장 전체의 히라가나 읽기 (공백 없이 작성)
   - ko: 자연스러운 한국어 번역

각 동사에 대해 다음 JSON 배열 규격을 엄격히 지켜 반환하세요:
[
  {{
    "literal": "落ち込む",
    "koreanMeaning": "우울해지다, 낙담하다",
    "reading": "おちこむ",
    "examples": [
      {{
        "jp": "試験に落ちてひどく落ち込んだ。",
        "kana": "しけんにおちてひどくおちこんだ。",
        "ko": "시험에 떨어져 몹시 낙담했다."
      }}
    ],
    "jlpt": "N2"
  }},
  {{
    "literal": "迷う",
    "koreanMeaning": "망설이다, 헤매다",
    "reading": "まよう",
    "examples": [
      {{
        "jp": "どの服を買うか迷っている。",
        "kana": "どのふくをかうかまよっている。",
        "ko": "어떤 옷을 살지 망설이고 있다."
      }}
    ],
    "jlpt": "N3"
  }}
]

반드시 위 조건을 충족하는 3개의 동사 객체를 JSON 배열 형식으로만 반환하세요.
"""


class SuggestionFlow(Flow[SuggestionState]):

    @start()
    def generate_suggestions(self):
        """입력 타입에 따라 추천 생성"""

        # Agent 생성
        expert = Agent(
            role="일본어 전문가" if self.state.entry_type == EntryType.word else "한자 전문가",
            goal="사용자 입력과 관련된 정확한 추천 제공",
            backstory="JLPT와 일본어 학습에 정통한 전문가",
            llm=llm,
            verbose=True
        )

        # 프롬프트 선택
        prompt = WORD_PROMPT if self.state.entry_type == EntryType.word else KANJI_PROMPT
        prompt = prompt.format(input_text=self.state.input_text)

        # Task 생성
        task = Task(
            description=prompt,
            expected_output="3개의 추천 항목을 JSON 배열로 반환",
            agent=expert
        )

        # Crew 실행
        crew = Crew(agents=[expert], tasks=[task], verbose=True)
        result = crew.kickoff()

        return result

    @listen(generate_suggestions)
    def parse_and_format(self, result):
        """AI 결과를 Pydantic 모델로 변환"""
        try:
            # JSON 파싱
            result_text = str(result)

            # JSON 추출 (```json ... ``` 형태일 수 있음)
            if "```json" in result_text:
                result_text = result_text.split("```json")[1].split("```")[0]
            elif "```" in result_text:
                result_text = result_text.split("```")[1].split("```")[0]

            data = json.loads(result_text.strip())

            # KanjiResponse 객체로 변환
            suggestions = []
            for i, item in enumerate(data[:3]):  # 최대 3개
                suggestion = KanjiResponse(
                    id=f"ai_suggestion_{i+1}",
                    literal=item.get("literal", ""),
                    jlpt=item.get("jlpt", "N5"),
                    strokeCount=item.get("strokeCount", 0),
                    koreanMeaning=item.get("koreanMeaning", ""),
                    meaningsKo=[item.get("koreanMeaning", "")],
                    onYomi=[ReadingModel(**r) for r in item.get("onYomi", [])],
                    kunYomi=[ReadingModel(**r)
                             for r in item.get("kunYomi", [])],
                    examples=[ExampleModel(**e)
                              for e in item.get("examples", [])],
                    kind=self.state.entry_type.value,
                    reading=item.get("reading", "")
                )
                suggestions.append(suggestion)

            self.state.suggestions = suggestions

        except Exception as e:
            print(f"Error parsing result: {e}")
            # 에러 시 빈 리스트 반환
            self.state.suggestions = []

# Flow 실행 함수


async def generate_suggestions(text: str, entry_type: EntryType) -> List[KanjiResponse]:
    """Flow를 실행하고 결과 반환"""
    flow = SuggestionFlow()
    flow.state.input_text = text
    flow.state.entry_type = entry_type

    flow.kickoff()

    return flow.state.suggestions
