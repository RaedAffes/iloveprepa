import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';

const need = (name) => {
  const v = process.env[name];
  if (!v) throw new Error(`Missing env var ${name}`);
  return v;
};

const OLD_API = process.env.OLD_API || 'https://iloveprepa-r2.raedaffes.workers.dev';
const CONCURRENCY = 8;
const RETRIES = 4;

const client = new S3Client({
  region: 'auto',
  endpoint: need('NEW_R2_ENDPOINT'),
  credentials: { accessKeyId: need('NEW_R2_ACCESS_KEY'), secretAccessKey: need('NEW_R2_SECRET_KEY') },
});
const BUCKET = process.env.NEW_R2_BUCKET || 'iloveprepa';

async function fetchWithRetry(url, attempts = RETRIES) {
  for (let i = 1; i <= attempts; i++) {
    try {
      const res = await fetch(url, { redirect: 'follow' });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      return res;
    } catch (err) {
      if (i === attempts) throw err;
      await new Promise((r) => setTimeout(r, 1000 * i));
    }
  }
}

async function copyOne(name) {
  const res = await fetchWithRetry(
    `${OLD_API}/api/download?file=${encodeURIComponent(name)}`,
  );
  const buffer = Buffer.from(await res.arrayBuffer());
  const contentType = res.headers.get('content-type') || 'application/pdf';
  await client.send(new PutObjectCommand({
    Bucket: BUCKET,
    Key: name,
    Body: buffer,
    ContentType: contentType,
  }));
}

const listRes = await fetchWithRetry(`${OLD_API}/api/files`);
const { files } = await listRes.json();
console.log(`Found ${files.length} files. Copying...`);

const queue = [...files];
let done = 0;
let failed = 0;
const failures = [];

async function workerFn() {
  while (queue.length) {
    const item = queue.shift();
    if (!item) return;
    try {
      await copyOne(item.name);
      done++;
      if (done % 25 === 0 || done === files.length) {
        console.log(`  ${done}/${files.length} (${(done / files.length * 100).toFixed(0)}%)`);
      }
    } catch (err) {
      failed++;
      failures.push(item.name);
      console.error(`  FAIL ${item.name}: ${err.message}`);
    }
  }
}

await Promise.all(Array.from({ length: Math.min(CONCURRENCY, files.length) }, workerFn));

console.log(`\nDone. ${done} copied, ${failed} failed.`);
if (failures.length) {
  console.log('Failures:\n' + failures.join('\n'));
  process.exit(1);
}
