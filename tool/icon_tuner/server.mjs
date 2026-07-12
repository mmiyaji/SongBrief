import { createServer } from 'node:http';
import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '../..');
const port = Number(process.argv[2] ?? process.env.PORT ?? 5174);

const routes = new Map([
  ['/', path.join(__dirname, 'index.html')],
  ['/index.html', path.join(__dirname, 'index.html')],
  ['/icon_params.json', path.join(__dirname, 'icon_params.json')],
  ['/current-icon.png', path.join(repoRoot, 'assets/branding/songbrief_icon.png')],
]);

const mimeByExt = new Map([
  ['.html', 'text/html; charset=utf-8'],
  ['.json', 'application/json; charset=utf-8'],
  ['.png', 'image/png'],
  ['.js', 'text/javascript; charset=utf-8'],
  ['.css', 'text/css; charset=utf-8'],
]);

function send(res, status, body, contentType = 'text/plain; charset=utf-8') {
  res.writeHead(status, {
    'content-type': contentType,
    'cache-control': 'no-store',
    'access-control-allow-origin': '*',
  });
  res.end(body);
}

async function readJsonBody(req) {
  const chunks = [];
  let total = 0;
  for await (const chunk of req) {
    total += chunk.length;
    if (total > 25 * 1024 * 1024) {
      throw new Error('Request body is too large.');
    }
    chunks.push(chunk);
  }
  return JSON.parse(Buffer.concat(chunks).toString('utf8'));
}

function decodePngDataUrl(value) {
  const match = /^data:image\/png;base64,([A-Za-z0-9+/=]+)$/.exec(value ?? '');
  if (!match) {
    throw new Error('Expected a PNG data URL.');
  }
  return Buffer.from(match[1], 'base64');
}

function run(command, args) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      cwd: repoRoot,
      shell: process.platform === 'win32',
      windowsHide: true,
    });
    let output = '';
    child.stdout.on('data', (chunk) => {
      output += chunk.toString();
    });
    child.stderr.on('data', (chunk) => {
      output += chunk.toString();
    });
    child.on('error', reject);
    child.on('close', (code) => {
      if (code === 0) {
        resolve(output);
      } else {
        reject(new Error(output || `${command} exited with ${code}`));
      }
    });
  });
}

async function saveAssets(req, res) {
  const body = await readJsonBody(req);
  const iconPng = decodePngDataUrl(body.iconPng);
  const iosPng = body.iosPng == null ? undefined : decodePngDataUrl(body.iosPng);
  const foregroundPng = decodePngDataUrl(body.foregroundPng);

  await mkdir(path.join(repoRoot, 'assets/branding'), { recursive: true });
  await writeFile(path.join(repoRoot, 'assets/branding/songbrief_icon.png'), iconPng);
  if (iosPng) {
    await writeFile(path.join(repoRoot, 'assets/branding/songbrief_icon_ios.png'), iosPng);
  }
  await writeFile(
    path.join(repoRoot, 'assets/branding/songbrief_icon_foreground.png'),
    foregroundPng,
  );
  await writeFile(
    path.join(__dirname, 'icon_params.json'),
    `${JSON.stringify(body.params, null, 2)}\n`,
  );

  send(
    res,
    200,
    JSON.stringify({
      ok: true,
      files: [
        'assets/branding/songbrief_icon.png',
        ...(iosPng ? ['assets/branding/songbrief_icon_ios.png'] : []),
        'assets/branding/songbrief_icon_foreground.png',
        'tool/icon_tuner/icon_params.json',
      ],
    }),
    'application/json; charset=utf-8',
  );
}

async function regenerateAssets(_req, res) {
  const launcherOutput = await run('dart', ['run', 'flutter_launcher_icons']);
  const splashOutput = await run('dart', ['run', 'flutter_native_splash:create']);
  send(
    res,
    200,
    JSON.stringify({ ok: true, output: launcherOutput + splashOutput }),
    'application/json; charset=utf-8',
  );
}

const server = createServer(async (req, res) => {
  try {
    const url = new URL(req.url ?? '/', `http://${req.headers.host}`);

    if (req.method === 'OPTIONS') {
      send(res, 204, '');
      return;
    }

    if (req.method === 'POST' && url.pathname === '/api/save') {
      await saveAssets(req, res);
      return;
    }

    if (req.method === 'POST' && url.pathname === '/api/regenerate') {
      await regenerateAssets(req, res);
      return;
    }

    if (req.method !== 'GET') {
      send(res, 405, 'Method not allowed');
      return;
    }

    const staticPath = routes.get(url.pathname);
    if (!staticPath || !existsSync(staticPath)) {
      send(res, 404, 'Not found');
      return;
    }

    const ext = path.extname(staticPath);
    send(res, 200, await readFile(staticPath), mimeByExt.get(ext) ?? 'application/octet-stream');
  } catch (error) {
    send(
      res,
      500,
      JSON.stringify({ ok: false, error: error instanceof Error ? error.message : String(error) }),
      'application/json; charset=utf-8',
    );
  }
});

server.listen(port, '127.0.0.1', () => {
  console.log(`SongBrief icon tuner: http://127.0.0.1:${port}/`);
});
