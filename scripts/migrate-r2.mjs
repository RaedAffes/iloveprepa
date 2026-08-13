import { S3Client, ListObjectsV2Command, GetObjectCommand, PutObjectCommand } from '@aws-sdk/client-s3';
import { Readable } from 'node:stream';

const need = (name) => {
  const v = process.env[name];
  if (!v) throw new Error(`Missing env var ${name}`);
  return v;
};

const oldClient = new S3Client({
  region: 'auto',
  endpoint: need('OLD_R2_ENDPOINT'),
  credentials: { accessKeyId: need('OLD_R2_ACCESS_KEY'), secretAccessKey: need('OLD_R2_SECRET_KEY') },
});

const newClient = new S3Client({
  region: 'auto',
  endpoint: need('NEW_R2_ENDPOINT'),
  credentials: { accessKeyId: need('NEW_R2_ACCESS_KEY'), secretAccessKey: need('NEW_R2_SECRET_KEY') },
});

const OLD_BUCKET = process.env.OLD_R2_BUCKET || 'iloveprepa';
const NEW_BUCKET = process.env.NEW_R2_BUCKET || 'iloveprepa';

async function* listAll(client, bucket) {
  let cursor;
  do {
    const res = await client.send(new ListObjectsV2Command({ Bucket: bucket, ContinuationToken: cursor, MaxKeys: 1000 }));
    for (const obj of res.Contents || []) yield obj;
    cursor = res.IsTruncated ? res.NextContinuationToken : undefined;
  } while (cursor);
}

let copied = 0;
let failed = 0;
const failures = [];

for await (const obj of listAll(oldClient, OLD_BUCKET)) {
  const key = obj.Key;
  try {
    const get = await oldClient.send(new GetObjectCommand({ Bucket: OLD_BUCKET, Key: key }));
    const body = get.Body;
    await newClient.send(new PutObjectCommand({
      Bucket: NEW_BUCKET,
      Key: key,
      Body: body,
      ContentType: get.ContentType || undefined,
    }));
    copied++;
    if (copied % 100 === 0) console.log(`  ${copied} copied (${key})`);
  } catch (err) {
    failed++;
    failures.push(key);
    console.error(`  FAIL ${key}: ${err.message}`);
  }
}

console.log(`\nDone. ${copied} objects copied, ${failed} failed.`);
if (failures.length) console.log('Failures:\n' + failures.join('\n'));
process.exit(failed ? 1 : 0);
