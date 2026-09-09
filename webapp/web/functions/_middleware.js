// Injects a unique, keyword-targeted <title> and <meta description> into the
// app shell for each keyword URL (prepa-examens, prepa-ds, ...), so Google
// sees a relevant, distinct page per query without any change to the visible
// site. The root app is untouched; the meta only affects search results.

const META = {
  "iprepa": {
    title: "IlovePrepa : 2000+ documents de prépa tunisienne gratuits",
    desc: "IlovePrepa : plus de 2000 documents de prépa tunisienne gratuits (cours, TD, DS, examens) en PDF, sans inscription, pour réussir.",
  },
  "prepa-tunisie": {
    title: "Prépa Tunisie : documents des classes prépas en PDF gratuit",
    desc: "Prépa Tunisie : tous les documents des classes préparatoires tunisiennes (cours, TD, DS, examens) en PDF gratuit, sans inscription.",
  },
  "prepa-docs": {
    title: "Documents de Prépa Tunisie : PDF gratuits à télécharger",
    desc: "Documents de prépa tunisienne gratuits en PDF : cours, TD, DS, examens et exercices corrigés pour toutes les filières scientifiques.",
  },
  "prepa-document": {
    title: "Document Prépa Tunisie : cours, TD, examens en PDF",
    desc: "Document de prépa tunisienne en PDF : cours, TD, examens et exercices corrigés gratuits, sans inscription, pour les classes prépas.",
  },
  "prepa-documents": {
    title: "Documents de Prépa Tunisie : cours, TD, examens PDF",
    desc: "Documents de prépa tunisienne : base complète de cours, TD, examens et corrigés en PDF gratuit pour les filières MP, PC, PT, T.",
  },
  "documents-prepa": {
    title: "Documents de Prépa Tunisie : base complète de PDF",
    desc: "Documents de prépa tunisienne à télécharger gratuitement : cours, TD, DS et examens corrigés classés par filière et par matière.",
  },
  "prepa-ds": {
    title: "Devoirs de Synthèse (DS) Prépa Tunisie : PDF gratuits",
    desc: "Devoirs de synthèse (DS) de prépa tunisienne gratuits en PDF : sujets de DS corrigés de maths, physique et chimie pour toutes les filières.",
  },
  "prepa-devoir": {
    title: "Devoir de Prépa Tunisie : DS et devoirs maison en PDF",
    desc: "Devoir de prépa tunisienne en PDF gratuit : devoirs de synthèse, devoirs maison et devoirs surveillés corrigés pour toutes les filières.",
  },
  "prepa-devoirs": {
    title: "Devoirs de Prépa Tunisie : DS, devoirs maison en PDF",
    desc: "Devoirs de prépa tunisienne gratuits en PDF : devoirs de synthèse et devoirs maison corrigés, classés par filière et par matière.",
  },
  "devoirs-prepa": {
    title: "Devoirs de Prépa Tunisie à télécharger : PDF gratuits",
    desc: "Devoirs de prépa tunisienne à télécharger gratuitement : DS, devoirs maison et devoirs surveillés avec corrigés en PDF.",
  },
  "prepa-examen": {
    title: "Examen de Prépa Tunisie : sujets d'examens corrigés en PDF",
    desc: "Examen de prépa tunisienne : tous les sujets d'examens corrigés des classes préparatoires (MP, PC, PT, T) en téléchargement gratuit PDF.",
  },
  "prepa-examens": {
    title: "Examens de Prépa Tunisie : sujets MP, PC, PT en PDF",
    desc: "Examens de prépa tunisienne gratuits en PDF : sujets d'examens de synthèse et épreuves corrigées pour les filières MP, PC, PT et T.",
  },
  "examens-prepa": {
    title: "Sujets d'Examens Prépa Tunisie : MP, PC, PT en PDF",
    desc: "Sujets d'examens de prépa tunisienne MP, PC, PT, T gratuits en PDF : examens de synthèse et épreuves corrigées de maths, physique et chimie.",
  },
  "prepa-exercice": {
    title: "Exercices de Prépa Tunisie corrigés : PDF gratuits",
    desc: "Exercices de prépa tunisienne corrigés en PDF : exercices types de maths, physique et chimie pour réviser chaque chapitre du programme.",
  },
  "prepa-exercices": {
    title: "Exercices de Prépa Tunisie : séries corrigées en PDF",
    desc: "Exercices de prépa tunisienne gratuits : séries d'exercices corrigés de maths, physique, chimie et informatique, classées par chapitre.",
  },
  "exercices-prepa": {
    title: "Exercices de Prépa : séries corrigées à télécharger",
    desc: "Exercices de prépa tunisienne à télécharger en PDF : séries d'exercices corrigés pour les filières MP, PC, PT et T.",
  },
  "prepa-cours": {
    title: "Cours de Prépa Tunisie : cours complets en PDF gratuit",
    desc: "Cours de prépa tunisienne gratuits en PDF : cours complets de maths, physique, chimie, informatique et SVT pour toutes les filières.",
  },
  "cours-prepa": {
    title: "Cours de Prépa Tunisie : cours MP, PC, PT et T en PDF",
    desc: "Cours de prépa tunisienne en PDF gratuit : cours complets et structurés de mathématiques, physique et chimie pour les prépas MP, PC, PT.",
  },
  "prepa-td": {
    title: "TD de Prépa Tunisie : travaux dirigés corrigés en PDF",
    desc: "TD de prépa tunisienne corrigés en PDF : travaux dirigés de maths, physique et chimie, classés par chapitre, gratuits à télécharger.",
  },
  "td-prepa": {
    title: "TD Prépa Tunisie : travaux dirigés avec corrigés en PDF",
    desc: "TD de prépa tunisienne à télécharger : travaux dirigés avec corrections détaillées de mathématiques, physique et chimie en PDF.",
  },
  "prepa-sujet": {
    title: "Sujets de Prépa Tunisie : DS, examens, concours en PDF",
    desc: "Sujets de prépa tunisienne en PDF gratuit : sujets d'examens, de devoirs de synthèse et de concours blancs pour toutes les filières.",
  },
  "prepa-sujets": {
    title: "Sujets de Prépa Tunisie : collection complète en PDF",
    desc: "Sujets de prépa tunisienne : collection complète d'annales, examens et devoirs de synthèse classés par filière, en PDF gratuit.",
  },
  "sujets-prepa": {
    title: "Sujets de Prépa Tunisie à télécharger : PDF gratuit",
    desc: "Sujets de prépa tunisienne à télécharger gratuitement : examens, DS et concours blancs de maths, physique et chimie en PDF.",
  },
  "prepa-concours": {
    title: "Concours de Prépa Tunisie : annales en PDF gratuits",
    desc: "Concours de prépa tunisienne : annales des concours nationaux avec sujets et corrigés, gratuites en PDF pour bien se préparer.",
  },
  "concours-prepa": {
    title: "Concours de Prépa Tunisie : annales et corrigés PDF",
    desc: "Concours de prépa tunisienne : annales, sujets et corrigés des épreuves de concours en téléchargement gratuit en PDF.",
  },
  "prepa-revision": {
    title: "Révision Prépa Tunisie : fiches de révision en PDF",
    desc: "Fiches de révision de prépa tunisienne en PDF : résumés de cours, formules essentielles et exercices types pour réviser efficacement.",
  },
  "prepa-revisions": {
    title: "Révisions Prépa Tunisie : fiches et annales en PDF",
    desc: "Révisions de prépa tunisienne : fiches de révision, résumés de cours et annales corrigées en PDF gratuit pour réussir ses examens.",
  },
  "revisions-prepa": {
    title: "Révisions de Prépa Tunisie : fiches gratuites en PDF",
    desc: "Révisions de prépa tunisienne gratuites : fiches, formules et exercices types en PDF, classés par matière et par filière.",
  },
  "prepa-corrige": {
    title: "Corrigés de Prépa Tunisie : corrections complètes en PDF",
    desc: "Corrigés de prépa tunisienne en PDF gratuit : corrections détaillées d'examens, de devoirs de synthèse et d'exercices.",
  },
  "prepa-corriges": {
    title: "Corrigés Prépa Tunisie : DS et examens corrigés en PDF",
    desc: "Corrigés de prépa tunisienne : corrections complètes de DS, examens et séries d'exercices en PDF gratuit pour toutes les filières.",
  },
  "corriges-prepa": {
    title: "Corrigés de Prépa : exercices et examens en PDF",
    desc: "Corrigés de prépa tunisienne à télécharger : corrections détaillées de devoirs de synthèse et d'examens en PDF gratuit.",
  },
  "prepa-mp": {
    title: "Prépa MP Tunisie : cours, TD, examens de MP en PDF",
    desc: "Tous les documents de prépa tunisienne de la filière MP (mathématiques-physique) : cours, TD, DS, examens et exercices corrigés en PDF gratuit.",
  },
  "prepa-pc": {
    title: "Prépa PC Tunisie : cours, TD, examens de PC en PDF",
    desc: "Tous les documents de prépa tunisienne de la filière PC (physique-chimie) : cours, TD, DS, examens et exercices corrigés en PDF gratuit.",
  },
  "prepa-pt": {
    title: "Prépa PT Tunisie : cours, TD, examens de PT en PDF",
    desc: "Tous les documents de prépa tunisienne de la filière PT (physique-technologie) : cours, TD, DS, examens et exercices corrigés en PDF gratuit.",
  },
  "prepa-t": {
    title: "Prépa T Tunisie : cours, TD, examens de la filière T",
    desc: "Tous les documents de prépa tunisienne de la filière T (technologie) : cours, TD, DS, examens et exercices corrigés en PDF gratuit.",
  },
  "prepa-bg": {
    title: "Prépa BG Tunisie : documents de la filière BG en PDF",
    desc: "Tous les documents de prépa tunisienne de la filière BG (biologie-géologie) : cours, TD, DS, examens et exercices corrigés en PDF gratuit.",
  },
  "prepa-maths": {
    title: "Maths Prépa Tunisie : cours, TD, examens de maths en PDF",
    desc: "Documents de prépa tunisienne en mathématiques : cours complets, TD, exercices, DS et examens corrigés en PDF gratuit, classés par chapitre.",
  },
  "prepa-mathematiques": {
    title: "Mathématiques Prépa Tunisie : cours et exercices en PDF",
    desc: "Documents de prépa tunisienne en mathématiques : cours complets, TD, exercices, DS et examens corrigés en PDF gratuit, classés par chapitre.",
  },
  "mathematiques-prepa": {
    title: "Mathématiques Prépa : cours, TD et annales en PDF",
    desc: "Documents de prépa tunisienne en mathématiques : cours complets, TD, exercices, DS et examens corrigés en PDF gratuit, classés par chapitre.",
  },
  "prepa-physique": {
    title: "Physique Prépa Tunisie : cours, TD, examens en PDF",
    desc: "Documents de prépa tunisienne en physique : cours complets, TD, exercices, DS et examens corrigés en PDF gratuit, classés par chapitre.",
  },
  "physique-prepa": {
    title: "Physique Prépa : cours, TD et annales corrigées en PDF",
    desc: "Documents de prépa tunisienne en physique : cours complets, TD, exercices, DS et examens corrigés en PDF gratuit, classés par chapitre.",
  },
  "prepa-chimie": {
    title: "Chimie Prépa Tunisie : cours, TD, examens en PDF",
    desc: "Documents de prépa tunisienne en chimie : cours complets, TD, exercices, DS et examens corrigés en PDF gratuit, classés par chapitre.",
  },
  "chimie-prepa": {
    title: "Chimie Prépa : cours, TD et annales corrigées en PDF",
    desc: "Documents de prépa tunisienne en chimie : cours complets, TD, exercices, DS et examens corrigés en PDF gratuit, classés par chapitre.",
  },
  "prepa-informatique": {
    title: "Informatique Prépa Tunisie : cours et TD en PDF",
    desc: "Documents de prépa tunisienne en informatique : cours complets, TD, exercices, DS et examens corrigés en PDF gratuit, classés par chapitre.",
  },
  "informatique-prepa": {
    title: "Informatique Prépa : cours, TD et examens en PDF",
    desc: "Documents de prépa tunisienne en informatique : cours complets, TD, exercices, DS et examens corrigés en PDF gratuit, classés par chapitre.",
  },
  "prepa-svt": {
    title: "SVT Prépa Tunisie : cours, TD et examens en PDF",
    desc: "Documents de prépa tunisienne en SVT : cours complets, TD, exercices, DS et examens corrigés en PDF gratuit, classés par chapitre.",
  },
  "svt-prepa": {
    title: "SVT Prépa : cours et exercices à télécharger en PDF",
    desc: "Documents de prépa tunisienne en SVT : cours complets, TD, exercices, DS et examens corrigés en PDF gratuit, classés par chapitre.",
  },
};

export async function onRequest(context) {
  const url = new URL(context.request.url);
  const key = url.pathname.replace(/^\/+|\/+$/g, "");
  const meta = META[key];
  if (!meta) return context.next();

  const res = await context.env.ASSETS.fetch(new URL("/", context.request.url));
  let html = await res.text();
  const canonical = "https://iprepa.tn/" + key + "/";

  html = html.replace(/<title>[\s\S]*?<\/title>/, "<title>" + meta.title + "</title>");
  html = html.replace(
    /(<meta name="description" content=")[^"]*(")/,
    "$1" + meta.desc + "$2",
  );
  html = html.replace(
    /(<meta property="og:title" content=")[^"]*(")/,
    "$1" + meta.title + "$2",
  );
  html = html.replace(
    /(<meta property="og:description" content=")[^"]*(")/,
    "$1" + meta.desc + "$2",
  );
  html = html.replace(
    /(<meta property="og:url" content=")[^"]*(")/,
    "$1" + canonical + "$2",
  );
  if (!html.includes('rel="canonical"')) {
    html = html.replace(
      '<meta property="og:url" content="' + canonical + '">',
      '<meta property="og:url" content="' + canonical + '">\n  <link rel="canonical" href="' + canonical + '">',
    );
  }

  return new Response(html, {
    status: 200,
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "no-cache",
    },
  });
}