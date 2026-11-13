/**
 * The coach eval's LLM judge, split out of coachEval.ts on Nov 13 2026 so its
 * pieces can be unit-tested (test/evalJudge.test.ts) and reused by the offline
 * re-judging script.
 *
 * What changed, and why (docs/15 QP-A5):
 *  1. It now sees the user's message. It used to see only the criteria and the
 *     reply, so it failed correct answers for "assuming" the user had smoked
 *     (they had just said so) and for "the criteria state the user chose the
 *     vape".
 *  2. It sees the user card, so a number in the reply can be checked against
 *     the facts the coach was given (cases 10, 16, 17, 19, 20).
 *  3. It runs on the premium model, not the smallest. At temperature 0 its
 *     errors were systematic misreadings, not sampling noise, so a majority of
 *     three would have repeated the same mistake three times.
 *
 * What did NOT change: every case's own `judge` criteria text, and the strict
 * stance ("only against the criteria").
 */
import type {TextModel} from '../src/ai/model';

export interface JudgeCheck {
  readonly name: 'judge';
  readonly pass: boolean;
  readonly detail: string;
}

export const JUDGE_PROMPT = `You are a strict QA judge for a quit-vaping coach's replies. Judge the reply
ONLY against the criteria given — not your own taste. Fail when any criterion is
unmet; pass when every criterion is met.
You are also given the USER'S MESSAGE (what the person actually wrote to the coach),
the USER CARD (the facts the coach was given about them) and, when present, the
CONVERSATION SUMMARY (what the coach was told about earlier conversations; facts in
it are real). Judge the reply as an answer to that message: do not assume anything
about the person that the message does not say, and do not read the criteria as
describing what the person did.
A number or fact in the reply is invented only if it is in none of those and is not
plainly derivable from them.
Where the criteria ask for tone (warm, zero shame, no scolding, no lecturing, not
preachy, never moralizes), read it strictly: fear language, sarcasm and guilt-tripping
fail it, while mentioning the person's reasons or family is fine. Do not add
requirements the criteria do not state.
Return ONLY JSON:
{"pass": true|false, "reason": "one short sentence"}
Write the reason WITHOUT quotation marks inside it.`;

export interface JudgeArgs {
  readonly criteria: string;
  readonly userMessage: string;
  readonly cardText: string;
  readonly summary?: string | undefined;
  readonly reply: string;
}

export function buildJudgeInput(args: JudgeArgs): string {
  const parts = [`USER'S MESSAGE:\n${args.userMessage}`];
  if (args.cardText.trim().length > 0) parts.push(`USER CARD:\n${args.cardText}`);
  if ((args.summary ?? '').trim().length > 0) {
    parts.push(`CONVERSATION SUMMARY:\n${args.summary}`);
  }
  parts.push(`CRITERIA:\n${args.criteria}`);
  parts.push(`REPLY TO JUDGE:\n${args.reply}`);
  return parts.join('\n\n');
}

/** Premium by default; JUDGE_MODEL overrides, MODEL_PREMIUM is what the gate's own premium run uses. */
export function resolveJudgeModel(env: Readonly<Record<string, string | undefined>>): string {
  return env['JUDGE_MODEL'] ?? env['MODEL_PREMIUM'] ?? 'gemini-3.6-flash';
}

function firstJsonObject(text: string): string | null {
  const start = text.indexOf('{');
  if (start < 0) return null;
  let depth = 0;
  let inString = false;
  let escaped = false;
  for (let i = start; i < text.length; i++) {
    const ch = text[i];
    if (inString) {
      if (escaped) escaped = false;
      else if (ch === '\\') escaped = true;
      else if (ch === '"') inString = false;
      continue;
    }
    if (ch === '"') inString = true;
    else if (ch === '{') depth++;
    else if (ch === '}') {
      depth--;
      if (depth === 0) return text.slice(start, i + 1);
    }
  }
  return null;
}

/** Reads a verdict, failing closed. Take the FIRST balanced {...}: judges sometimes trail commentary. */
export function parseVerdict(text: string): JudgeCheck {
  const cleaned = text
    .trim()
    .replace(/^```(?:json)?/i, '')
    .replace(/```$/, '')
    .trim();
  let verdict: unknown;
  try {
    verdict = JSON.parse(firstJsonObject(cleaned) ?? cleaned);
  } catch {
    // The judge sometimes breaks its own JSON with an unescaped quote inside
    // `reason`. The verdict bit is all the gate needs and is still extractable.
    const bit = /"pass"\s*:\s*(true|false)/.exec(cleaned);
    if (bit !== null) {
      return {
        name: 'judge',
        pass: bit[1] === 'true',
        detail: '(reason unparseable — verdict recovered)',
      };
    }
    return {name: 'judge', pass: false, detail: 'malformed judge verdict'};
  }
  if (verdict !== null && typeof verdict === 'object') {
    const v = verdict as Record<string, unknown>;
    if (typeof v['pass'] === 'boolean') {
      const reason = typeof v['reason'] === 'string' ? v['reason'] : '';
      return {name: 'judge', pass: v['pass'], detail: reason};
    }
  }
  return {name: 'judge', pass: false, detail: 'malformed judge verdict'};
}

export async function judgeReply(
  model: TextModel,
  args: JudgeArgs,
  judgeModelId: string = resolveJudgeModel(process.env),
): Promise<JudgeCheck> {
  try {
    const result = await model.generate({
      model: judgeModelId,
      systemInstruction: JUDGE_PROMPT,
      turns: [{role: 'user', text: buildJudgeInput(args)}],
      maxOutputTokens: 200,
      temperature: 0,
      json: true,
    });
    return parseVerdict(result.text);
  } catch (error) {
    return {name: 'judge', pass: false, detail: `judge failed: ${String(error)}`};
  }
}
