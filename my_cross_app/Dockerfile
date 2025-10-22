# Flutter Web Dockerfile
FROM ubuntu:latest

# 필수 패키지 설치
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

# Flutter SDK 설치
ENV FLUTTER_HOME=/usr/local/flutter
ENV PATH="$FLUTTER_HOME/bin:$PATH"

RUN git clone https://github.com/flutter/flutter.git -b stable $FLUTTER_HOME
RUN flutter doctor
RUN flutter config --enable-web

# 작업 디렉토리 설정
WORKDIR /app

# pubspec 파일 복사 및 의존성 설치
COPY pubspec.* ./
RUN flutter pub get

# 전체 소스 복사
COPY . .

# 웹 빌드
RUN flutter build web --release --pwa-strategy=none

# 서비스워커 파일 완전 제거
RUN rm -f /app/build/web/flutter_service_worker.js

# Nginx를 사용하여 정적 파일 서빙
FROM nginx:alpine
COPY --from=0 /app/build/web /usr/share/nginx/html

# Nginx 설정 복사
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 3001

CMD ["nginx", "-g", "daemon off;"]
