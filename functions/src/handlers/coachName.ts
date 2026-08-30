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
import {isAllowedCoachName} from '../lib/nameGuard';
import {log} from '../lib/logger';

/** Matches the 20 grapheme clusters `coach_name.dart` enforces client-side. */
const MAX_CHARS = 20;

export const setCoachName = onCall(
  {region: REGION, enforceAppCheck: true, memory: '256MiB'},
  async (request): Promise<{coachName: string}> => {
    const {uid} = requireCaller(request);
    const data = (request.data ?? {}) as Record<string, unknown>;
    const name = requireText(data['coachName'], 'coachName', MAX_CHARS);

    if (!isAllowedCoachName(name)) {
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
