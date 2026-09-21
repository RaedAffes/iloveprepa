import { DocumentItem, displayNameOf, fileNameOf } from "./document-item";
import { LibraryFolder, buildLibraryTree } from "./library-folder";

export enum ResourceType {
  cours = "Cours",
  td = "TD",
  tp = "TP",
  examens = "Examens",
  series = "Séries",
  etude = "Étude",
  livres = "Livres",
  autre = "Autre",
}

export interface SearchResult {
  title: string;
  path: string[];
  isFolder: boolean;
  document?: DocumentItem;
  type?: ResourceType;
}

export function pathLabelOf(result: SearchResult): string {
  return result.path.join(" → ");
}

const ACCENTS = "àáâãäåāăèéêëēėęìíîïīıòóôõöōøùúûüūçćčñńśšžżźýÿ";
const PLAIN = "aaaaaaaaeeeeeeeiiiiiiioooooooouuuuucccnnsszzzyy";

export function searchNorm(input: string): string {
  const text = input
    .toLowerCase()
    .replaceAll("œ", "oe")
    .replaceAll("æ", "ae");
  let out = "";
  for (const ch of text) {
    const i = ACCENTS.indexOf(ch);
    out += i >= 0 ? PLAIN[i] : ch;
  }
  return out;
}

const COURS = new Set([
  "cours", "cm", "lecon", "lecons", "lesson", "lessons", "poly", "polys", "polycopie",
]);
const TD = new Set(["td", "tds", "exercice", "exercices"]);
const TP = new Set(["tp", "tps", "laboratoire", "pratique"]);
const EXAMENS = new Set([
  "examen", "examens", "devoir", "devoirs", "controle", "controles",
  "epreuve", "epreuves", "ds", "test", "tests", "interro", "interrogation",
  "interrogations",
]);
const SERIES = new Set(["serie", "series"]);
const LIVRES = new Set(["livre", "livres", "manuel", "manuels", "book", "books"]);
const ETUDE = new Set(["etude", "etudes", "revision", "revisions", "rappel"]);

export function resourceTypeForName(folderName: string): ResourceType | undefined {
  const tokens = new Set(
    searchNorm(folderName)
      .split(/[^a-z0-9]+/)
      .filter((t) => t.length > 0),
  );
  const any = (set: Set<string>) => [...tokens].some((t) => set.has(t));

  if (any(EXAMENS)) return ResourceType.examens;
  if (any(COURS)) return ResourceType.cours;
  if (any(TD)) return ResourceType.td;
  if (any(TP)) return ResourceType.tp;
  if (any(SERIES)) return ResourceType.series;
  if (any(LIVRES)) return ResourceType.livres;
  if (any(ETUDE)) return ResourceType.etude;
  return undefined;
}

function typeForSegments(segments: string[]): ResourceType | undefined {
  for (let i = 1; i < segments.length; i++) {
    const type = resourceTypeForName(segments[i]);
    if (type) return type;
  }
  return undefined;
}

interface Scored<T> {
  score: number;
  value: T;
}

function walkFolder(
  node: LibraryFolder,
  ancestors: string[],
  visit: (folder: LibraryFolder, segments: string[]) => void,
) {
  for (const child of node.children.values()) {
    const segments = [...ancestors, child.name];
    visit(child, segments);
    walkFolder(child, segments, visit);
  }
}

export class LibraryIndex {
  readonly root: LibraryFolder;

  constructor(public documents: DocumentItem[]) {
    this.root = buildLibraryTree(documents);
  }

  search(query: string): SearchResult[] {
    const q = searchNorm(query.trim());
    if (!q) return [];

    const terms = q.split(/\s+/).filter((t) => t.length > 0);
    function matchScore(haystack: string): number {
      let score = 0;
      for (const term of terms) {
        if (haystack.includes(term)) score++;
      }
      return score;
    }

    const results: Scored<SearchResult>[] = [];

    walkFolder(this.root, [], (folder, segments) => {
      const score = matchScore(searchNorm(folder.name));
      if (score > 0) {
        results.push({
          score,
          value: {
            title: folder.name,
            path: segments.slice(0, -1),
            isFolder: true,
            type: resourceTypeForName(folder.name),
          },
        });
      }
    });

    for (const doc of this.documents) {
      const segments = doc.name
        .split("/")
        .filter((s) => s.trim().length > 0);
      const score = matchScore(fileHaystack(doc));
      if (score > 0) {
        results.push({
          score,
          value: {
            title: displayNameOf(doc),
            path: segments.slice(0, -1),
            document: doc,
            isFolder: false,
            type: typeForSegments(segments),
          },
        });
      }
    }

    results.sort((a, b) => {
      if (a.score !== b.score) return b.score - a.score;
      if (a.value.isFolder !== b.value.isFolder) {
        return a.value.isFolder ? -1 : 1;
      }
      return a.value.title.toLowerCase().localeCompare(b.value.title.toLowerCase());
    });

    return results.map((r) => r.value);
  }
}

function fileHaystack(doc: DocumentItem): string {
  const name = searchNorm(fileNameOf(doc));
  const display = searchNorm(displayNameOf(doc));
  return `${display} ${name}`;
}