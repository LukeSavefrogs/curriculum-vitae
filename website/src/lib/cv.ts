import { marked } from "marked";
import { parse } from "yaml";

/** Any RenderCV entry: plain text, or an object whose fields decide the entry type. */
export type Entry = string | EntryFields;

export interface EntryFields {
  // Titles (experience, education, normal, publication, one-line and bullet entries)
  position?: string;
  company?: string;
  institution?: string;
  area?: string;
  degree?: string;
  name?: string;
  title?: string;
  authors?: string[];
  label?: string;
  details?: string;
  bullet?: string;
  // Common fields
  date?: string | number | null;
  start_date?: string | number | null;
  end_date?: string | number | null;
  location?: string | null;
  summary?: string | null;
  highlights?: string[] | null;
  grade?: string | null;
}

export interface Cv {
  name: string;
  location?: string;
  email?: string;
  phone?: string;
  website?: string | null;
  social_networks?: { network: string; username: string }[];
  sections: Record<string, Entry[]>;
}

const REPOSITORY_URL = "https://github.com/LukeSavefrogs/curriculum-vitae";
export const DEFAULT_LANGUAGE = "en";

const LABELS = {
  en: { language: "English", present: "present", grade: "Grade", pdf: "Download PDF" },
  it: { language: "Italiano", present: "presente", grade: "Voto", pdf: "Scarica PDF" },
} as const;

export function labels(lang: string) {
  return LABELS[lang as keyof typeof LABELS] ?? LABELS.en;
}

// One `cv-<lang>.yaml` file per language in the repository root (same files used by RenderCV)
const files = import.meta.glob<string>("../../../cv-*.yaml", {
  query: "?raw",
  import: "default",
  eager: true,
});

const cvs: Record<string, Cv> = Object.fromEntries(
  Object.entries(files).map(([path, raw]) => {
    const lang = /cv-([^/]+)\.yaml$/.exec(path)![1];
    return [lang, parse(raw).cv as Cv];
  }),
);

/** Available languages, default language first. */
export const languages = Object.keys(cvs).sort((a, b) =>
  a === DEFAULT_LANGUAGE ? -1 : b === DEFAULT_LANGUAGE ? 1 : a.localeCompare(b),
);

export function getCv(lang: string): Cv {
  return cvs[lang];
}

/** Prefixes a site path with the configured base path. */
export function url(path = ""): string {
  return import.meta.env.BASE_URL + path.replace(/^\//, "");
}

/** Link to the PDF attached to the latest GitHub release (see `.github/workflows/release-cv.yml`). */
export function pdfUrl(cv: Cv, lang: string): string {
  return `${REPOSITORY_URL}/releases/latest/download/${cv.name.replaceAll(" ", "_")}_CV-${lang}.pdf`;
}

const SOCIAL_URLS: Record<string, string> = {
  LinkedIn: "https://www.linkedin.com/in/",
  GitHub: "https://github.com/",
  GitLab: "https://gitlab.com/",
};

export function socialUrl(network: string, username: string): string | undefined {
  return SOCIAL_URLS[network] && SOCIAL_URLS[network] + username;
}

/** `snake_case` section keys become "Title Case", like RenderCV does. */
export function sectionTitle(key: string): string {
  if (/[A-Z]/.test(key)) return key;
  return key
    .split("_")
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
    .join(" ");
}

/** Renders inline Markdown (links, code, emphasis) used in the YAML files. */
export function inline(markdown: string | null | undefined): string {
  return markdown ? (marked.parseInline(markdown, { async: false }) as string) : "";
}

function formatDate(value: string | number | null | undefined, lang: string): string {
  if (value === null || value === undefined || value === "") return "";
  const text = String(value).trim();
  if (text === "present") return labels(lang).present;

  const match = /^(\d{4})-(\d{2})(?:-\d{2})?$/.exec(text);
  if (!match) return text;

  const formatted = new Intl.DateTimeFormat(lang, {
    month: "short",
    year: "numeric",
    timeZone: "UTC",
  }).format(new Date(Date.UTC(Number(match[1]), Number(match[2]) - 1, 1)));
  return formatted.charAt(0).toUpperCase() + formatted.slice(1);
}

export function dateRange(entry: EntryFields, lang: string): string {
  if (entry.date) return formatDate(entry.date, lang);
  const start = formatDate(entry.start_date, lang);
  const end = formatDate(entry.end_date, lang);
  return start && end ? `${start} – ${end}` : start || end;
}

export function isOneLine(entry: Entry): entry is EntryFields & { label: string } {
  return typeof entry === "object" && entry.label !== undefined;
}
