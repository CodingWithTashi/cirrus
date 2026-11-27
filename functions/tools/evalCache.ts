/**
 * The eval's answer cache: an identical request, asked for the same roll, is
 * bought once.
 *
 * Why: a prompt change is judged by five rolls of OLD and five of NEW, and
 * on Nov 25 2026 a second attempt re-bought all five OLD rolls although not
 * one character of what was sent had changed. The same goes for any scenario
 * a change does not touch (a panic turn, when only the ordinary card moved).
 *
 * The key is the whole request and nothing else: model id, system
 * instruction, turns, output cap, temperature, JSON mode, plus the roll
 * number for a sampled call. So a hit is exactly "this was already asked",
 * and it cannot go stale when a prompt, a fixture or a model id moves: the
 * key moves with them.
 *
 *  - A sampled call (a coach reply at temperature 0.8) is keyed by roll:
 *    roll 3 of a question is one draw, kept. Five rolls are still five
 *    draws. An unchanged scenario then shows the SAME five replies on both
 *    sides of a comparison, which takes its noise out of the difference.
 *  - A call that should not vary (the judge at temperature 0) is keyed
 *    without a roll, so one reply is always judged the same way.
 *  - Entries expire after thirty days. Model ids are pinned, but a provider
 *    can move a model under its id, and a baseline should not outlive that.
 *
 * It lives beside the ledger in `~/.cirrus-eval/`, shared by every working
 * copy, because the two sides of a comparison run from different folders.
 */
import {createHash} from 'node:crypto';
import {existsSync, mkdirSync, readFileSync, renameSync, writeFileSync} from 'node:fs';
import {join} from 'node:path';
import type {GenerateRequest, GenerateResult} from '../src/ai/model';

const MAX_AGE_MS = 30 * 24 * 60 * 60 * 1000;

export class EvalCache {
  /** [dir] null switches the cache off (`--no-cache`): never read, never written. */
  constructor(
    private readonly dir: string | null,
    private readonly now: () => Date = () => new Date(),
  ) {}

  key(request: GenerateRequest, sample: number | null): string {
    const canonical = JSON.stringify({
      v: 1,
      model: request.model,
      systemInstruction: request.systemInstruction,
      turns: request.turns.map((turn) => [turn.role, turn.text]),
      maxOutputTokens: request.maxOutputTokens,
      temperature: request.temperature ?? null,
      json: request.json ?? false,
      sample,
    });
    return createHash('sha256').update(canonical).digest('hex');
  }

  has(key: string): boolean {
    return this.get(key) !== null;
  }

  get(key: string): GenerateResult | null {
    if (this.dir === null) return null;
    const file = join(this.dir, `${key}.json`);
    if (!existsSync(file)) return null;
    let parsed: unknown;
    try {
      parsed = JSON.parse(readFileSync(file, 'utf8'));
    } catch {
      return null;
    }
    const row = parsed as {
      at?: unknown;
      text?: unknown;
      inputTokens?: unknown;
      outputTokens?: unknown;
      thoughtTokens?: unknown;
    } | null;
    if (
      row === null ||
      typeof row.at !== 'string' ||
      typeof row.text !== 'string' ||
      typeof row.inputTokens !== 'number' ||
      typeof row.outputTokens !== 'number'
    ) {
      return null;
    }
    const age = this.now().getTime() - new Date(row.at).getTime();
    if (!Number.isFinite(age) || age > MAX_AGE_MS) return null;
    return {
      text: row.text,
      inputTokens: row.inputTokens,
      outputTokens: row.outputTokens,
      ...(typeof row.thoughtTokens === 'number' ? {thoughtTokens: row.thoughtTokens} : {}),
    };
  }

  put(key: string, result: GenerateResult): void {
    if (this.dir === null) return;
    mkdirSync(this.dir, {recursive: true});
    const file = join(this.dir, `${key}.json`);
    // Temp then rename: a run killed mid-write must not leave half an answer.
    const temp = `${file}.${process.pid}.tmp`;
    writeFileSync(temp, JSON.stringify({at: this.now().toISOString(), ...result}));
    renameSync(temp, file);
  }
}
