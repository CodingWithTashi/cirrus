/**
 * Whether a user-chosen coach name is one we are willing to render.
 *
 * ## Why this is server-side
 *
 * A denylist shipped in the app bundle is extractable in minutes and reads, to
 * anyone who pulls it apart, as "a list of slurs this company maintains". It
 * lives here instead, and the client never learns *why* a name was refused —
 * a denylist that explains itself is a denylist you can enumerate.
 *
 * ## What this is honestly for
 *
 * `coachName` is **private**: it is rendered to exactly one person, the one who
 * typed it. It never appears in a post, in a push to anyone else, or in the
 * feed. So this is not content moderation — it is keeping our own chrome out of
 * an embarrassing screenshot, and stopping someone impersonating the app.
 *
 * That matters because of the limit worth stating plainly: an English wordlist
 * catches English. Spanish, French, German and Portuguese terms will get
 * through, and per-language lists will not be maintained by a one-person team.
 * Shipping the pretence of five-language coverage would be worse than shipping
 * this and saying what it does.
 *
 * The impersonation tokens below are language-independent and are the half that
 * actually protects the product. The abusive-word half is supplied by the
 * founder in `data/name-denylist.json` (gitignored, one lowercase term per
 * line of a JSON array) — absent, this still blocks impersonation and the
 * syntactic rules in `coach_name.dart` still apply.
 */
import {readFileSync} from 'node:fs';
import {join} from 'node:path';

/**
 * Whole-token matches only. Substring matching on these would refuse "Sam"
 * inside nothing and "Cass" inside nothing, but it WOULD refuse a perfectly
 * good name that happens to contain one — the classic "Scunthorpe" failure.
 */
const IMPERSONATION = [
  'cirrus',
  'lastpuff',
  'admin',
  'administrator',
  'moderator',
  'support',
  'staff',
  'official',
  'system',
  'root',
];

const LEET: Record<string, string> = {
  '0': 'o', '1': 'i', '3': 'e', '4': 'a', '5': 's', '7': 't',
  '@': 'a', '$': 's', '!': 'i',
};

/**
 * Folds a name to the form a match is made against: lowercase, de-accented,
 * de-leeted, alphanumerics only, and repeated letters collapsed. So `A_d_m1n`,
 * `ADMIIIN` and `@dmin` all reduce to `admin`.
 */
export function skeleton(name: string): string {
  const lowered = name
    .normalize('NFKD')
    // Combining marks: strips the accent, keeps the letter.
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase();
  const deleeted = [...lowered].map((c) => LEET[c] ?? c).join('');
  const letters = deleeted.replace(/[^a-z0-9]/g, '');
  return letters.replace(/(.)\1+/g, '$1');
}

/**
 * Below this length a term is matched against the WHOLE folded name, never as
 * a substring.
 *
 * This is the Scunthorpe rule, and it is not hypothetical here: skeletonizing
 * collapses repeats, so "ass" folds to "as" — which is a substring of Cassie,
 * Cass and Bassam, and "hell" folds to "hel", a substring of Shelly. A guard
 * that refuses somebody's actual name is worse than no guard, because the user
 * cannot see why and we deliberately will not tell them.
 *
 * Long terms stay substring-matched, because padding a long word out is the
 * evasion that actually happens and accidental containment is vanishingly rare.
 */
const SUBSTRING_MIN = 5;

let cachedList: string[] | null = null;

/** Founder-supplied terms, if the file exists. Read once per instance. */
function denylist(): string[] {
  if (cachedList !== null) return cachedList;
  // Two candidates because the working directory differs between a local
  // `npm run` (the package root) and a gen-2 container (/workspace, which is
  // usually the same thing — but "usually" is not something to hang a content
  // guard on). The second is relative to this compiled file: it lands at
  // `lib/src/lib/`, so three hops up is the package root either way.
  const candidates = [
    join(process.cwd(), 'data', 'name-denylist.json'),
    join(__dirname, '..', '..', '..', 'data', 'name-denylist.json'),
  ];
  for (const path of candidates) {
    try {
      const parsed: unknown = JSON.parse(readFileSync(path, 'utf8'));
      if (!Array.isArray(parsed)) continue;
      cachedList = parsed.filter((t): t is string => typeof t === 'string');
      return cachedList;
    } catch {
      // Try the next one.
    }
  }
  // No file is the expected state in the repo, and in that case the
  // impersonation guard above is still live.
  cachedList = [];
  return cachedList;
}

/**
 * True when the name may be used, judged against an explicit term list.
 *
 * Split out from [isAllowedCoachName] so the matching rules are testable
 * without a file on disk — the real list is gitignored and absent in CI.
 */
export function isAllowedAgainst(
  name: string,
  terms: readonly string[],
): boolean {
  const folded = skeleton(name);
  if (folded.length === 0) return false;
  // Impersonation always matches the whole name, so "Adminka" is fine.
  if (IMPERSONATION.map(skeleton).includes(folded)) return false;
  return !terms.some((raw) => {
    const term = skeleton(raw);
    if (term.length === 0) return false;
    return term.length < SUBSTRING_MIN
        ? folded === term
        : folded.includes(term);
  });
}

/** True when the name may be used. */
export function isAllowedCoachName(name: string): boolean {
  return isAllowedAgainst(name, denylist());
}
