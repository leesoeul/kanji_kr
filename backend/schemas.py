from pydantic import BaseModel, Field
from typing import List, Optional
from enum import Enum

# 요청


class EntryType(str, Enum):
    kanji = "kanji"
    word = "word"


class SuggestionRequest(BaseModel):
    text: str = Field(..., description="사용자가 입력한 텍스트")
    entry_type: EntryType = Field(..., description="한자 또는 단어")

# 응답


class ReadingModel(BaseModel):
    kana: str


class ExampleModel(BaseModel):
    jp: str
    kana: str
    ko: str


class KanjiResponse(BaseModel):
    id: str
    literal: str
    jlpt: str
    strokeCount: int
    koreanMeaning: str
    meaningsKo: List[str]
    onYomi: List[ReadingModel]
    kunYomi: List[ReadingModel]
    examples: List[ExampleModel]
    kind: str
    listId: str = "ai_suggestion"
    reading: str
    isUserAdded: bool = False


class SuggestionResponse(BaseModel):
    suggestions: List[KanjiResponse]

# Flow 상태


class SuggestionState(BaseModel):
    input_text: str = ""
    entry_type: EntryType = EntryType.kanji
    suggestions: List[KanjiResponse] = []
