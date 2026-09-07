import {describe, expect, it} from 'vitest';
import {buildMessage, deviceIdFor, type PushPayload, type SendOptions} from '../src/lib/push';
import {
  CHANNEL_COMMUNITY,
  CHANNEL_COMMUNITY_QUIET,
  CHANNEL_INSIGHTS,
} from '../src/lib/pushKinds';

/**
 * The wire shape, which nothing else can check.
 *
 * `buildMessage` is the one part of the push path with no runtime feedback at
 * all: FCM accepts a malformed-for-the-platform message and delivers it wrong,
 * or drops it silently, and the only symptom is a notification somebody did
 * not get. Its own docstring has named this file since the day it was split
 * out, and until now the file did not exist — which is how the iOS half
 * shipped with no `sound` and every push landed on an iPhone as a silent
 * banner while the identical send buzzed on Android.
 *
 * Every assertion here is a bug that has been shipped or nearly shipped.
 */

const TOKENS = ['tok-a', 'tok-b'];
const PAYLOAD: PushPayload = {
  title: 'Someone replied',
  body: 'Two people answered your post',
  route: '/community/post/abc123',
};

function build(opts: Partial<SendOptions>, quiet = false) {
  return buildMessage(TOKENS, PAYLOAD, {kind: 'communityReply', ...opts}, quiet);
}

describe('buildMessage — iOS', () => {
  it('names a sound, because APNs plays none unless asked', () => {
    const aps = build({}).apns?.payload?.['aps'] as Record<string, unknown>;
    expect(aps['sound']).toBe('default');
  });

  it('goes silent in quiet hours instead — never both', () => {
    const aps = build({}, true).apns?.payload?.['aps'] as Record<string, unknown>;
    expect(aps['sound']).toBeUndefined();
    expect(aps['interruption-level']).toBe('passive');
  });

  it('adds no interruption level outside quiet hours', () => {
    const aps = build({}).apns?.payload?.['aps'] as Record<string, unknown>;
    expect(aps['interruption-level']).toBeUndefined();
  });

  it('carries the collapse id in the APNs header, capped at 64 chars', () => {
    const tag = 'thread:' + 'x'.repeat(100);
    expect(build({tag}).apns?.headers?.['apns-collapse-id']).toHaveLength(64);
  });

  it('groups threads with aps.threadId and never a raw thread-id', () => {
    // Setting both throws INVALID_PAYLOAD at send time, which is a failure
    // with no local reproduction at all.
    const aps = build({threadId: 'post:abc123'}).apns?.payload?.[
      'aps'
    ] as Record<string, unknown>;
    expect(aps['threadId']).toBe('post:abc123');
    expect(aps['thread-id']).toBeUndefined();
  });

  it('omits the collapse header entirely when nothing collapses', () => {
    expect(build({}).apns?.headers?.['apns-collapse-id']).toBeUndefined();
  });
});

describe('buildMessage — Android', () => {
  it('swaps the channel for quiet delivery rather than lowering a flag', () => {
    expect(build({}).android?.notification?.channelId).toBe(CHANNEL_COMMUNITY);
    expect(build({}, true).android?.notification?.channelId).toBe(
      CHANNEL_COMMUNITY_QUIET,
    );
  });

  it('reads the channel from the kind, not from the call site', () => {
    expect(build({kind: 'insightReady'}).android?.notification?.channelId).toBe(
      CHANNEL_INSIGHTS,
    );
  });

  it('sets the tag, which is what makes twenty replies one shade line', () => {
    const msg = build({tag: 'post:abc123'});
    expect(msg.android?.notification?.tag).toBe('post:abc123');
    expect(msg.android?.collapseKey).toBe('post:abc123');
  });
});

describe('buildMessage — payload', () => {
  it('puts the route in data, where a tapped notification can still read it', () => {
    // The notification block alone cannot carry a destination.
    expect(build({}).data).toEqual({
      kind: 'communityReply',
      route: '/community/post/abc123',
    });
  });

  it('omits the route key when there is none, rather than sending empty', () => {
    const msg = buildMessage(
      TOKENS,
      {title: 't', body: 'b'},
      {kind: 'system'},
      false,
    );
    expect(msg.data).toEqual({kind: 'system'});
  });

  it('sends the title and body every platform falls back to', () => {
    expect(build({}).notification).toEqual({
      title: PAYLOAD.title,
      body: PAYLOAD.body,
    });
  });

  it('copies the token list rather than aliasing the caller\'s', () => {
    const msg = build({});
    expect(msg.tokens).toEqual(TOKENS);
    expect(msg.tokens).not.toBe(TOKENS);
  });
});

describe('deviceIdFor', () => {
  it('is not the token — a registration token is a credential', () => {
    expect(deviceIdFor('tok-a')).not.toContain('tok-a');
    expect(deviceIdFor('tok-a')).toHaveLength(64);
  });

  it('is idempotent, so re-registering overwrites instead of adding a row', () => {
    expect(deviceIdFor('tok-a')).toBe(deviceIdFor('tok-a'));
  });

  it('ignores surrounding whitespace, like registerDevice does', () => {
    expect(deviceIdFor('  tok-a  ')).toBe(deviceIdFor('tok-a'));
  });
});
