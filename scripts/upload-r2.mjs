import { readdirSync } from 'node:fs';
import { join, relative, resolve, sep } from 'node:path';
import { execFile } from 'node:child_process';

const ROOT = resolve(import.meta.dirname, '..');
const WRANGLER = join(ROOT, 'worker', 'node_modules', 'wrangler', 'bin', 'wrangler.js');
const BUCKET = 'iloveprepa';
const FOLDERS = ['MP1', 'MP2'];
const CONCURRENCY = 10;

const mime = (name) => {
  const ext = name.toLowerCase().split('.').pop();
  const table = {
    pdf: 'application/pdf',
    png: 'image/png',
    jpg: 'image/jpeg',
    jpeg: 'image/jpeg',
    gif: 'image/gif',
    svg: 'image/svg+xml',
    doc: 'application/msword',
    docx: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    ppt: 'application/vnd.ms-powerpoint',
    zip: 'application/zip',
  };
  return table[ext] || 'application/octet-stream';
};

function walk(dir) {
  const out = [];
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) out.push(...walk(full));
    else if (entry.isFile()) out.push(full);
  }
  return out;
}

function runWrangler(key, file) {
  return new Promise((resolvePromise, reject) => {
    execFile(
      process.execPath,
      [
        WRANGLER,
        'r2', 'object', 'put',
        `${BUCKET}/${key}`,
        '--file', file,
        '--content-type', mime(file),
        '--remote',
        '-y',
      ],
      { cwd: join(ROOT, 'worker'), windowsHide: true, maxBuffer: 16 * 1024 * 1024 },
      (err, stdout, stderr) => {
        if (err) reject(new Error(String(stderr || stdout || err.message)));
        else resolvePromise(stdout);
      },
    );
  });
}

const files = [];
for (const folder of FOLDERS) {
  for (const file of walk(join(ROOT, folder))) {
    files.push({
      key: relative(ROOT, file).split(sep).join('/'),
      file,
    });
  }
}

console.log(`Uploading ${files.length} files to R2 bucket "${BUCKET}"...`);

let done = 0;
let failed = 0;
const queue = [...files];

async function worker() {
  while (queue.length) {
    const job = queue.shift();
    if (!job) return;
    try {
      await runWrangler(job.key, job.file);
      done++;
      if (done % 25 === 0) console.log(`  ${done}/${files.length} uploaded`);
    } catch (e) {
      failed++;
      console.error(`  FAIL ${job.key}: ${String(e.message).split('\n')[0]}`);
    }
  }
}

await Promise.all(Array.from({ length: Math.min(CONCURRENCY, files.length) }, worker));

console.log(`\nDone. ${done} uploaded, ${failed} failed.`);
process.exit(failed ? 1 : 0);
