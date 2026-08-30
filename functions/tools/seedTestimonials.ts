/**
 * Loads `data/testimonials.json` into the `testimonials` collection.
 *
 * Deliberately OUTSIDE `src/`, so it never lands in the deploy bundle and no
 * cold start pays for it.
 *
 * ## The rules this enforces, in code rather than in a policy document
 *
 * 1. **Every row needs a `consentRef`** — a pointer to the release the person
 *    actually signed. A quote from a real person with no record of permission
 *    is not something to put in front of a paywall. The file ships with these
 *    blank on purpose: until the founder fills them in, this refuses to write
 *    anything, the collection stays empty, and the app renders the bundled
 *    quotes exactly as it does today. Nothing regresses; nothing is claimed.
 * 2. **No names, no ages, no photos.** There is no field for one, and there
 *    must not be: docs/02 §3 D3 names the competitor's invented "Sarah, 29" as
 *    the review-bomb risk this product is positioned against.
 * 3. **Length is capped** at what the card can render, so a seeded row can
 *    never make the screen taller than the fallback it replaces.
 *
 *   npm run seed:testimonials
 */
import {existsSync, readdirSync, readFileSync} from 'node:fs';
import {join} from 'node:path';

const MAX_CHARS = 220;

interface Row {
  id: string;
  text: string;
  locale: string;
  consentRef: string;
  status: string;
  [key: string]: unknown;
}

function fail(message: string): never {
  process.stderr.write(`seed:testimonials — ${message}\n`);
  process.exit(1);
}

/**
 * Points the Admin SDK at a credential, or explains what to do.
 *
 * Inside Cloud Functions the SDK finds one on its own. A script on a laptop
 * does not, and the raw failure is a wall of `google-auth-library` stack that
 * says nothing about the fix. Resolution order is the one a developer would
 * use: an explicit `GOOGLE_APPLICATION_CREDENTIALS`, then a service-account
 * key sitting in `functions/`, then whatever `gcloud auth
 * application-default login` left behind.
 *
 * Must run BEFORE `src/lib/firestore` loads, which is why that import is
 * dynamic below — a static one is hoisted and would initialize the SDK first.
 */
function resolveCredentials(root: string): void {
  if (process.env['GOOGLE_APPLICATION_CREDENTIALS'] !== undefined) return;

  const key = readdirSync(root).find(
    (f) => f.includes('adminsdk') && f.endsWith('.json'),
  );
  if (key !== undefined) {
    process.env['GOOGLE_APPLICATION_CREDENTIALS'] = join(root, key);
    return;
  }

  // gcloud writes here and the SDK finds it unaided, so there is nothing to
  // set — just don't claim there is a problem.
  const adc =
    process.platform === 'win32'
      ? join(
          process.env['APPDATA'] ?? '',
          'gcloud',
          'application_default_credentials.json',
        )
      : join(
          process.env['HOME'] ?? '',
          '.config',
          'gcloud',
          'application_default_credentials.json',
        );
  if (existsSync(adc)) return;

  fail(
    'no credentials. Either run `gcloud auth application-default login`, or ' +
      'put a service-account key in functions/ (any *adminsdk*.json), or set ' +
      'GOOGLE_APPLICATION_CREDENTIALS to one.',
  );
}

async function main(): Promise<void> {
  // Resolved from the working directory, not from __dirname: this runs
  // compiled, so __dirname is `lib/tools/` and every relative hop from there
  // is one level off. `npm run` always sets cwd to the package root.
  const path = join(process.cwd(), 'data', 'testimonials.json');
  const rows = JSON.parse(readFileSync(path, 'utf8')) as Row[];

  const problems: string[] = [];
  const seen = new Set<string>();
  for (const row of rows) {
    if (typeof row.id !== 'string' || row.id.length === 0) {
      problems.push('a row has no id');
      continue;
    }
    if (seen.has(row.id)) problems.push(`${row.id}: duplicate id`);
    seen.add(row.id);
    if (typeof row.consentRef !== 'string' || row.consentRef.trim().length === 0) {
      problems.push(
        `${row.id}: consentRef is empty. Put anything that records where this ` +
        `quote came from and that you may use it — a form id, an email date, ` +
        `a Drive link, or for a string the app already ships, the ARB key it ` +
        `lives under. It is never sent to the client; it exists so a quote ` +
        `cannot be put in front of a paywall with no idea whose words it is.`,
      );
    }
    if (typeof row.text !== 'string' || row.text.trim().length === 0) {
      problems.push(`${row.id}: no text`);
    } else if (row.text.length > MAX_CHARS) {
      problems.push(`${row.id}: ${row.text.length} chars, max is ${MAX_CHARS}`);
    }
    if (typeof row.locale !== 'string' || row.locale.length === 0) {
      problems.push(`${row.id}: no locale`);
    }
    if (row.status !== 'live' && row.status !== 'hidden') {
      problems.push(`${row.id}: status must be live or hidden`);
    }
  }

  if (problems.length > 0) {
    fail(`refusing to write ${problems.length} row(s):\n  ${problems.join('\n  ')}`);
  }

  resolveCredentials(process.cwd());
  const {db} = await import('../src/lib/firestore');

  const batch = db.batch();
  for (const row of rows) {
    const {id, ...fields} = row;
    batch.set(db.collection('testimonials').doc(id), {
      ...fields,
      updatedAt: new Date(),
    });
  }
  await batch.commit();
  process.stdout.write(
    `seed:testimonials — wrote ${rows.length} row(s) to testimonials\n`,
  );
  // The Admin SDK holds a gRPC channel open, so without this the process hangs
  // with the write already committed — which reads exactly like a failure.
  process.exit(0);
}

main().catch((error: unknown) => fail(String(error)));
