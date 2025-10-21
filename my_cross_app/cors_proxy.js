// CORS 프록시 서버 - Flutter 웹 개발용
// 사용법: node cors_proxy.js
// 그 후 Flutter 웹 앱을 http://localhost:3000에서 실행

const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');
const cors = require('cors');

const app = express();
const PORT = 3000;

// CORS 허용
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'Accept'],
}));

// API 프록시 설정 - Docker Compose Nginx 프록시(3001)로 전달
app.use('/api', createProxyMiddleware({
  target: 'http://localhost:3001',
  changeOrigin: true,
  onProxyReq: (proxyReq, req, res) => {
    console.log(`Proxying: ${req.method} ${req.url} -> http://localhost:3001${req.url}`);
  },
  onError: (err, req, res) => {
    console.error('Proxy error:', err);
    res.status(500).json({ error: 'Proxy error' });
  }
}));

// 정적 파일 서빙 (Flutter 웹 빌드 결과)
app.use(express.static('build/web'));

// 모든 요청을 index.html로 리다이렉트 (SPA 지원)
app.get('*', (req, res) => {
  res.sendFile(__dirname + '/build/web/index.html');
});

app.listen(PORT, () => {
  console.log(` CORS Proxy Server running on http://localhost:${PORT}`);
  console.log(` Proxying API requests to http://localhost:3001`);
  console.log(` Flutter Web app available at http://localhost:${PORT}`);
});
