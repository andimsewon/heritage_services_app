FROM python:3.10-slim

# 1. 작업 디렉토리 생성
WORKDIR /app

# 2. 의존성 설치용 파일 복사
COPY requirements.txt .

# 3. 필요한 패키지 설치
RUN pip install --no-cache-dir -r requirements.txt

# 4. 코드 & 모델 복사
COPY . .

# 5. FastAPI 서버 실행
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
