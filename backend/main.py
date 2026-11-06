import os
import traceback
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv

# 환경변수 로드 (다른 모듈 import 전에 먼저 실행)
load_dotenv()

from schemas import SuggestionRequest, SuggestionResponse
from flow import generate_suggestions

# FastAPI 앱
app = FastAPI(
    title="Kanji KR AI Backend",
    description="한자/단어 자동완성 API",
    version="1.0.0"
)

# CORS 설정
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
async def health_check():
    """헬스 체크"""
    return {"status": "healthy"}


@app.post("/api/suggestions", response_model=SuggestionResponse)
async def get_suggestions(request: SuggestionRequest):
    """사용자 입력에 따라 AI가 생성한 3개의 추천을 반환"""
    try:
        suggestions = await generate_suggestions(
            text=request.text,
            entry_type=request.entry_type
        )
        return SuggestionResponse(suggestions=suggestions)
    except Exception as e:
        print("\n" + "=" * 50)
        print("🔥 [백엔드 에러 발생] 상세 내용:")
        traceback.print_exc()
        print("=" * 50 + "\n")
        raise HTTPException(status_code=500, detail=f"AI 생성 실패: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)
