from pydantic import BaseModel, Field
from typing import List
from enum import Enum


class EntryType(str, Enum):
    kanji = "kanji"
    word = "word"


class SuggestionRequest(BaseModel):
    text: str = Field(..., description="사용자가 입력한 텍스트")
    entry_type: EntryType = Field(..., description="한자 또는 단어")


class ReadingModel(BaseModel):
    kana: str


class ExampleModel(BaseModel):
    jp: str
    kana: str
    ko: str


class LlmItem(BaseModel):
    """모델이 채우는 필드만. id/kind는 서버에서 붙인다."""

    literal: str
    koreanMeaning: str
    jlpt: str = "N5"
    strokeCount: int = 0
    reading: str = ""
    onYomi: List[ReadingModel] = Field(default_factory=list)
    kunYomi: List[ReadingModel] = Field(default_factory=list)
    examples: List[ExampleModel] = Field(default_factory=list)


class LlmPayload(BaseModel):
    items: List[LlmItem]


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
