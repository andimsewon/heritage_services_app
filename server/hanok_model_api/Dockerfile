# 1. 기본 이미지 (Python 3.9 + CPU)
FROM python:3.9-slim

# 2. 작업 디렉토리 설정
WORKDIR /app

# 3. 시스템 패키지 설치 (예: gcc, libgl 등 이미지 처리에 필요)
RUN apt-get update && apt-get install -y \
    git wget curl build-essential \
    libgl1 libglib2.0-0 \
 && rm -rf /var/lib/apt/lists/*

# 4. requirements.txt 복사 및 설치
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 5. 앱 코드 복사
COPY . .

# 6. FastAPI 실행 (포트 8000)
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
