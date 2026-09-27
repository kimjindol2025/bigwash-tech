/* 정적 화면 + HQ API 프록시. 업무 로직은 HQ에 있다. */
const http = require('http');
const fs = require('fs');
const path = require('path');
const { URL } = require('url');

const PORT = Number(process.env.TECH_PORT || process.env.PORT || 30100);
const HQ = (process.env.HQ_API || 'http://127.0.0.1:30000').replace(/\/$/, '');
const ROOT = path.join(__dirname, 'public');

const TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png'
};

function sendFile(res, file) {
  fs.readFile(file, (err, buf) => {
    if (err) {
      res.writeHead(404, { 'content-type': 'text/plain; charset=utf-8' });
      res.end('not found');
      return;
    }
    const ext = path.extname(file);
    res.writeHead(200, { 'content-type': TYPES[ext] || 'application/octet-stream' });
    res.end(buf);
  });
}

function proxy(req, res, targetPath) {
  const dest = new URL(targetPath, HQ);
  const headers = Object.assign({}, req.headers);
  delete headers.host;
  const preq = http.request(dest, { method: req.method, headers }, (pres) => {
    res.writeHead(pres.statusCode || 502, pres.headers);
    pres.pipe(res);
  });
  preq.on('error', (err) => {
    res.writeHead(502, { 'content-type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify({ error: 'HQ 연결 실패: ' + err.message }));
  });
  req.pipe(preq);
}

const server = http.createServer((req, res) => {
  const u = new URL(req.url, 'http://127.0.0.1');
  if (u.pathname.startsWith('/api/')) {
    proxy(req, res, u.pathname.slice(4) + u.search);
    return;
  }
  let rel = decodeURIComponent(u.pathname);
  if (rel === '/' || rel === '') rel = '/index.html';
  const file = path.normalize(path.join(ROOT, rel));
  if (!file.startsWith(ROOT)) {
    res.writeHead(403);
    res.end('forbidden');
    return;
  }
  sendFile(res, file);
});

server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    console.error('[bigwash-tech] bind failed :' + PORT);
    process.exit(1);
  }
  console.error('[bigwash-tech] ' + err.message);
  process.exit(1);
});

server.listen(PORT, '0.0.0.0', () => {
  console.log('[bigwash-tech] :' + PORT + ' hq=' + HQ);
});
