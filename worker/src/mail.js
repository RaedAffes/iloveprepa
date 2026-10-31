// Transactional mail via Resend. Order creation must not fail if mail fails.
// The D17 QR is attached inline (CID). External image URLs are blocked by
// Gmail and hurt spam score.

const D17_NUMBER = '25680686';
const DEFAULT_CONTACT = 'contact@iprepa.tn';
const QR_CID = 'd17-qr';

export async function sendOrderConfirmation(env, { order, user, force = false }) {
  const apiKey = env.RESEND_API_KEY;
  const to = user && user.email;
  if (!apiKey) {
    console.error('order mail skipped: missing RESEND_API_KEY');
    return { ok: false, error: 'missing_api_key' };
  }
  if (!to) {
    console.error('order mail skipped: missing recipient email');
    return { ok: false, error: 'missing_to' };
  }

  const from =
    env.ORDER_FROM ||
    env.ALERT_FROM ||
    'I Love Prepa <onboarding@resend.dev>';
  const contact = env.CONTACT_EMAIL || DEFAULT_CONTACT;
  const label = order.label || 'votre formule';
  const amount = order.amountDt;
  const phone = order.payerPhone || '';
  const ref = order.id || '';
  const name = user.name || user.givenName || '';
  const idempotencyKey = force
    ? `order-confirm/${ref}/${Date.now()}`
    : `order-confirm/${ref}`;

  const qrPayload = `D17:${D17_NUMBER}:${amount}`;
  const qrBase64 = await fetchQrBase64(qrPayload);
  const attachments = qrBase64
    ? [
        {
          filename: 'qr-d17.png',
          content: qrBase64,
          content_id: QR_CID,
          content_type: 'image/png',
        },
      ]
    : undefined;

  const payload = {
    from,
    to: [to],
    reply_to: [contact],
    subject: `Confirmation de commande — ${label}`,
    text: orderEmailText({ name, label, amount, phone, ref, contact, d17: D17_NUMBER }),
    html: orderEmailHtml({
      name,
      label,
      amount,
      phone,
      ref,
      contact,
      d17: D17_NUMBER,
      hasQr: Boolean(qrBase64),
    }),
  };
  if (attachments) payload.attachments = attachments;

  try {
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
        'Idempotency-Key': idempotencyKey,
      },
      body: JSON.stringify(payload),
    });
    const text = await res.text();
    if (!res.ok) {
      console.error('order mail failed:', res.status, text, 'from=', from, 'to=', to);
      return { ok: false, status: res.status, error: text, from, to };
    }
    console.log('order mail sent:', text, 'to=', to);
    return { ok: true, status: res.status, body: text, from, to };
  } catch (err) {
    console.error('order mail error:', err && err.message ? err.message : err);
    return { ok: false, error: String(err && err.message ? err.message : err) };
  }
}

async function fetchQrBase64(payload) {
  try {
    const url =
      'https://api.qrserver.com/v1/create-qr-code/?size=280x280&margin=12&format=png&data=' +
      encodeURIComponent(payload);
    const res = await fetch(url);
    if (!res.ok) return null;
    const bytes = new Uint8Array(await res.arrayBuffer());
    let binary = '';
    for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
    return btoa(binary);
  } catch (_) {
    return null;
  }
}

function orderEmailText({ name, label, amount, phone, ref, contact, d17 }) {
  const hello = name ? `Bonjour ${name},` : 'Bonjour,';
  return `${hello}

Nous avons bien reçu votre commande I Love Prepa.

Formule : ${label}
Montant : ${amount} DT
Numéro D17 utilisé : ${phone}
Référence : ${ref}

Merci de payer avec D17 vers le commerçant ${d17}.
Ouvrez aussi Mes commandes dans l’application pour afficher le QR.

Votre accès est activé après réception du paiement (maximum 12 h).

Contact : ${contact}
`;
}

function orderEmailHtml({ name, label, amount, phone, ref, contact, d17, hasQr }) {
  const hello = name ? `Bonjour ${escapeHtml(name)},` : 'Bonjour,';
  const qrBlock = hasQr
    ? `<img src="cid:${QR_CID}" width="220" height="220" alt="QR D17 commerçant" style="display:block;border:0;border-radius:8px;" />
              <div style="margin-top:10px;font-size:13px;color:#5C6578;">QR commerçant D17</div>`
    : `<div style="margin-top:10px;font-size:13px;color:#5C6578;">Ouvrez Mes commandes dans l’app pour le QR.</div>`;
  return `<!DOCTYPE html>
<html lang="fr">
<body style="margin:0;padding:0;background:#f4f5f7;font-family:Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#16255E;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f4f5f7;padding:24px 12px;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" style="max-width:560px;background:#ffffff;border-radius:12px;overflow:hidden;border:1px solid #e6e8ef;">
          <tr>
            <td style="padding:28px 28px 8px;font-size:22px;font-weight:700;color:#1B3FA0;">
              Merci pour votre commande
            </td>
          </tr>
          <tr>
            <td style="padding:0 28px 20px;font-size:15px;line-height:1.55;color:#5C6578;">
              ${hello}<br/><br/>
              Nous avons bien reçu votre commande. Merci de vous assurer d’avoir payé avec <strong>D17</strong> vers le QR code commerçant ci-dessous.
            </td>
          </tr>
          <tr>
            <td style="padding:0 28px 20px;">
              <table role="presentation" width="100%" style="background:#f7f8fb;border-radius:10px;border:1px solid #e6e8ef;">
                <tr><td style="padding:16px 18px;font-size:14px;line-height:1.6;color:#16255E;">
                  <strong>Formule</strong> : ${escapeHtml(label)}<br/>
                  <strong>Montant</strong> : ${escapeHtml(String(amount))} DT<br/>
                  <strong>Numéro D17 utilisé</strong> : ${escapeHtml(phone)}<br/>
                  <strong>Référence</strong> : ${escapeHtml(ref)}
                </td></tr>
              </table>
            </td>
          </tr>
          <tr>
            <td align="center" style="padding:8px 28px 8px;">
              ${qrBlock}
              <div style="margin-top:4px;font-size:18px;font-weight:700;letter-spacing:0.04em;color:#16255E;">${escapeHtml(d17)}</div>
            </td>
          </tr>
          <tr>
            <td style="padding:16px 28px 8px;font-size:14px;line-height:1.55;color:#5C6578;">
              Votre accès est activé après réception du paiement (maximum 12 h). Vous pouvez aussi retrouver ce QR dans <strong>Mes commandes</strong>.
            </td>
          </tr>
          <tr>
            <td style="padding:8px 28px 28px;font-size:14px;line-height:1.55;color:#5C6578;">
              Une question ? Écrivez-nous à
              <a href="mailto:${escapeHtml(contact)}" style="color:#1B3FA0;text-decoration:none;">${escapeHtml(contact)}</a>.
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}
