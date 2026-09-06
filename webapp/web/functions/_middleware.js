const KEYWORD_SLUGS = [
  "iprepa",
  "prepa-tunisie",
  "prepa-docs",
  "prepa-document",
  "prepa-documents",
  "documents-prepa",
  "prepa-ds",
  "prepa-devoir",
  "prepa-devoirs",
  "devoirs-prepa",
  "prepa-examen",
  "prepa-examens",
  "examens-prepa",
  "prepa-exercice",
  "prepa-exercices",
  "exercices-prepa",
  "prepa-cours",
  "cours-prepa",
  "prepa-td",
  "td-prepa",
  "prepa-sujet",
  "prepa-sujets",
  "sujets-prepa",
  "prepa-concours",
  "concours-prepa",
  "prepa-revision",
  "prepa-revisions",
  "revisions-prepa",
  "prepa-corrige",
  "prepa-corriges",
  "corriges-prepa",
  "prepa-mp",
  "prepa-pc",
  "prepa-pt",
  "prepa-t",
  "prepa-bg",
  "prepa-maths",
  "prepa-mathematiques",
  "mathematiques-prepa",
  "prepa-physique",
  "physique-prepa",
  "prepa-chimie",
  "chimie-prepa",
  "prepa-informatique",
  "informatique-prepa",
  "prepa-svt",
  "svt-prepa"
];

const slugSet = new Set(KEYWORD_SLUGS);

export async function onRequest(context) {
  const url = new URL(context.request.url);
  const key = url.pathname.replace(/^\/+|\/+$/g, "");
  if (slugSet.has(key)) {
    const res = await context.env.ASSETS.fetch(new URL("/", context.request.url));
    return new Response(res.body, { status: 200, headers: res.headers });
  }
  return context.next();
}