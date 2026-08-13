import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const CONFIG = JSON.parse(
  fs.readFileSync(new URL('./config.json', import.meta.url), 'utf8'),
);

const { endpoint, accessKeyId, secretAccessKey, bucket, folder } = CONFIG;

if (accessKeyId.startsWith('PUT_') || secretAccessKey.startsWith('PUT_')) {
  console.error('ERROR: Open config.json and fill in the Access Key ID and Secret Access Key.');
  process.exit(1);
}
if (!folder) {
  console.error('ERROR: Set the "folder" path in config.json to the folder containing the files.');
  process.exit(1);
}
if (!fs.existsSync(folder)) {
  console.error(`ERROR: Folder not found: ${folder}`);
  process.exit(1);
}

const HOST = new URL(endpoint).host;
const REGION = 'auto';
const SERVICE = 's3';
const RETRIES = 3;

const sha256 = (buf) => crypto.createHash('sha256').update(buf).digest('hex');
const hmac = (key, data) => crypto.createHmac('sha256', key).update(data).digest();

function awsEncode(s) {
  return encodeURIComponent(s)
    .replace(/[!'()*]/g, (c) => '%' + c.charCodeAt(0).toString(16).toUpperCase())
    .replace(/%2F/g, '/');
}

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
    pptx: 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    zip: 'application/zip',
    txt: 'text/plain',
    md: 'text/markdown',
  };
  return table[ext] || 'application/octet-stream';
};

function walk(dir) {
  const out = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...walk(full));
    else if (entry.isFile()) out.push(full);
  }
  return out;
}

async function putObject(key, data, contentType) {
  const date = new Date().toISOString().replace(/[-:]|\.\d{3}/g, '');
  const dateOnly = date.slice(0, 8);
  const payloadHash = sha256(data);
  const encodedKey = awsEncode(key);

  const canonicalHeaders =
    `content-type:${contentType}\n` +
    `host:${HOST}\n` +
    `x-amz-content-sha256:${payloadHash}\n` +
    `x-amz-date:${date}\n`;
  const signedHeaders = 'content-type;host;x-amz-content-sha256;x-amz-date';

  const canonicalRequest =
    `PUT\n/${bucket}/${encodedKey}\n\n${canonicalHeaders}\n${signedHeaders}\n${payloadHash}`;

  const stringToSign =
    'AWS4-HMAC-SHA256\n' +
    date +
    '\n' +
    `${dateOnly}/${REGION}/${SERVICE}/aws4_request\n` +
    sha256(Buffer.from(canonicalRequest, 'utf8'));

  const kDate = hmac('AWS4' + secretAccessKey, dateOnly);
  const kRegion = hmac(kDate, REGION);
  const kService = hmac(kRegion, SERVICE);
  const kSigning = hmac(kService, 'aws4_request');
  const signature = hmac(kSigning, stringToSign).toString('hex');

  const authorization =
    `AWS4-HMAC-SHA256 Credential=${accessKeyId}/${dateOnly}/${REGION}/${SERVICE}/aws4_request, ` +
    `SignedHeaders=${signedHeaders}, Signature=${signature}`;

  for (let i = 1; i <= RETRIES; i++) {
    try {
      const res = await fetch(`${endpoint}/${bucket}/${encodedKey}`, {
        method: 'PUT',
        headers: {
          'content-type': contentType,
          'x-amz-content-sha256': payloadHash,
          'x-amz-date': date,
          authorization,
        },
        body: data,
      });
      if (!res.ok) throw new Error(`HTTP ${res.status} ${(await res.text()).slice(0, 200)}`);
      return;
    } catch (err) {
      if (i === RETRIES) throw err;
      await new Promise((r) => setTimeout(r, 1500 * i));
    }
  }
}

const files = walk(folder);
console.log(`Uploading ${files.length} files to "${bucket}"...`);

let done = 0;
let failed = 0;
const failures = [];

for (const file of files) {
  const key = path.relative(folder, file).split(path.sep).join('/');
  const contentType = mime(file);
  try {
    await putObject(key, fs.readFileSync(file), contentType);
    done++;
    if (done % 10 === 0 || done === files.length) {
      console.log(`  ${done}/${files.length} (${(done / files.length * 100).toFixed(0)}%)`);
    }
  } catch (err) {
    failed++;
    failures.push(key);
    console.error(`  FAIL ${key}: ${err.message}`);
  }
}

console.log(`\nDone. ${done} uploaded, ${failed} failed.`);
if (failures.length) {
  console.log('Failed files:\n' + failures.join('\n'));
  process.exitCode = 1;
}
