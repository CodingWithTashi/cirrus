/**
 * Function barrel. Keep it thin: Cloud Functions loads THIS file on every
 * cold start of every function, so top-level work here is latency every
 * handler pays. Logic lives in `handlers/`.
 *
 * docs/05 §7 lists the MVP set. `dangerHourPush` is deliberately absent:
 * danger-hour reminders are deterministic once computed, so they are
 * scheduled on-device with `flutter_local_notifications` — free, works
 * offline, and deletes an hourly fan-out over the whole userbase. FCM is
 * reserved for events that genuinely originate server-side.
 */
import {setGlobalOptions} from 'firebase-functions/v2';
import {REGION} from './config';

setGlobalOptions({
  region: REGION,
  // A runaway loop should cost a bounded amount of money, not an unbounded one.
  maxInstances: 40,
});

export {aiCoachChat} from './handlers/aiCoachChat';
export {panicSession} from './handlers/panicSession';
export {syncUserContext} from './handlers/syncUserContext';
export {deleteUserData} from './handlers/deleteUserData';
export {moderatePost} from './handlers/moderatePost';
export {taperRecalc} from './handlers/taperRecalc';
export {pruneDevices} from './handlers/pruneDevices';
export {weeklyInsight} from './handlers/weeklyInsight';
export {rcWebhook} from './handlers/rcWebhook';
export {createPost} from './handlers/createPost';
export {createReply} from './handlers/createReply';
export {reportReply} from './handlers/reportReply';
export {moderateReply} from './handlers/moderateReply';
export {onReaction} from './handlers/onReaction';
export {moderationQueue, resolveModeration} from './handlers/moderationQueue';
export {coachMemories, forgetCoachMemory} from './handlers/coachMemories';
export {seedCoachMemories} from './handlers/seedCoachMemories';
export {matchedTestimonials} from './handlers/testimonials';
export {setCoachName} from './handlers/coachName';
