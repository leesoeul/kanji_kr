# Kanji KR AI Backend

FastAPI + OpenAI 직접 호출 기반 한자/단어 자동완성 백엔드

## 설치

```bash
cd backend
pip install -r requirements.txt
cp .env.example .env
# .env 파일에 OpenAI API 키 입력
```

## 실행

```bash
python main.py
```

또는

```bash
uvicorn main:app --reload --port 8000
```

## API 테스트

### 한자 추천

```bash
curl -X POST http://localhost:8000/api/suggestions \
  -H "Content-Type: application/json" \
  -d '{"text": "산", "entry_type": "kanji"}'
```

### 단어 추천

```bash
curl -X POST http://localhost:8000/api/suggestions \
  -H "Content-Type: application/json" \
  -d '{"text": "등산", "entry_type": "word"}'
```

## API 문서

브라우저에서 다음 주소로 접속하면 자동 생성된 API 문서를 확인할 수 있습니다:

- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## 구조

- `main.py` - FastAPI 애플리케이션 및 라우터
- `schemas.py` - Pydantic 데이터 모델
- `flow.py` - OpenAI 호출 및 응답 변환
