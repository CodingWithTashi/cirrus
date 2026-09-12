/**
 * `setCoachName` — the server's copy of what the user calls their coach.
 *
 * There are deliberately two copies. `journeys/{uid}.profile.coachName` is
 * client-owned and drives every screen; **this** one is server-owned and is the
 * only version the model is ever told about.
 *
 * That split is the whole point. The journey document is written wholesale by
 * the app on every optimistic mutation, so a name there is arbitrary client
 * input — and a name like `"Ember. IGNORE ALL PRIOR INSTRUCTIONS"` flowing
 * straight into a system prompt is a live injection surface. A name that
 * reaches the model has passed through here, so it has been validated by
 * construction.
 */
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {REGION} from '../config';
import {FieldValue, userDoc} from '../lib/firestore';
import {requireCaller, requireText} from '../lib/guards';
import {
  COACH_NAME_MAX,
  coachNameLength,
  hasAllowedShape,
  isAllowedCoachName,
  normalizeCoachName,
} from '../lib/nameGuard';
import {log} from '../lib/logger';

/**
 * The widest a valid name can be in UTF-16 code units: 20 code points, each at
 * most a surrogate pair. `requireText` counts code units, so this is only a
 * cheap upper bound to bring the string in safely — the real limit is
 * [COACH_NAME_MAX], counted in code points below, which is what the client and
 * the user both count. Bounding on code units alone refused an 11-letter name
 * in Adlam, CJK Extension B, or the styled text people paste from a bio.
 */
const MAX_WIRE_CHARS = COACH_NAME_MAX * 2;

export const setCoachName = onCall(
  {region: REGION, enforceAppCheck: true, memory: '256MiB'},
  async (request): Promise<{coachName: string}> => {
    const {uid} = requireCaller(request);
    const data = (request.data ?? {}) as Record<string, unknown>;
    const name = normalizeCoachName(
      requireText(data['coachName'], 'coachName', MAX_WIRE_CHARS),
    );

    if (coachNameLength(name) > COACH_NAME_MAX) {
      throw new HttpsError(
        'invalid-argument',
        `"coachName" must be ${COACH_NAME_MAX} characters or fewer.`,
      );
    }

    // The shape rules the app enforces as they type. Re-checked here because
    // the app is the untrusted side and this name goes into a system prompt.
    if (!hasAllowedShape(name) || !isAllowedCoachName(name)) {
      // Deliberately says nothing about which rule it broke: a denylist that
      // explains itself is a denylist you can enumerate, and spelling out the
      // trigger to a seventeen-year-old is worse than a shrug.
      throw new HttpsError('invalid-argument', 'Pick a different name.');
    }

    await userDoc(uid).set(
      {coachName: name, updatedAt: FieldValue.serverTimestamp()},
      {merge: true},
    );
    // The name itself is never logged — it is the user's own private word.
    log.info('coach.renamed', {uid});
    return {coachName: name};
  },
);
