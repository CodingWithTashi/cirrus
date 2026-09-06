import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/router/app_router.dart';

/// The thread route is written in two languages and has to agree.
///
/// `Routes.communityPost` builds it in Dart; `threadRoute` in
/// `functions/src/lib/notifyReply.ts` builds the same path in TypeScript, and
/// puts it in a push payload the app then matches against its allow-list.
/// Nothing compiles the two together, so a rename on one side would ship a
/// notification that opens the app and goes nowhere — which is exactly the
/// failure mode this whole feature is most prone to, since a push that lands
/// on the wrong screen looks like a push that was never sent.
///
/// Same arrangement as `test/domain/post_quality_test.dart`, which reads the
/// TypeScript prefilter to pin the posting floor across the two.
void main() {
  test('the server builds the same thread route the client registers', () {
    final source = File(
      'functions/src/lib/notifyReply.ts',
    ).readAsStringSync();

    final match = RegExp(
      r'export function threadRoute\(postId: string\): string \{\s*'
      r'return `([^`]*)`;',
    ).firstMatch(source);
    expect(
      match,
      isNotNull,
      reason: 'threadRoute is gone or reshaped in notifyReply.ts',
    );

    // `/community/post/${postId}` on the server side.
    final template = match!.group(1)!;
    final serverPath = template.replaceAll(r'${postId}', 'abc123');
    expect(serverPath, Routes.communityPost('abc123'));
  });

  test('the tag the server groups by names the post', () {
    final source = File(
      'functions/src/lib/notifyReply.ts',
    ).readAsStringSync();
    // The tag is what makes a repeat send REPLACE the shade line rather than
    // stack, so it has to be stable per thread and carry the post id.
    expect(source, contains(r'return `thread:${postId}`;'));
  });

  test('the route the client accepts covers what the server sends', () {
    // `PushService.routeFor` matches an allow-listed prefix, and the thread
    // route has always been covered by `/community` — but only by accident of
    // sharing a prefix. Pin it, so splitting the community route later fails
    // here rather than in production silence.
    expect(
      Routes.communityPost('abc123').startsWith(Routes.community),
      isTrue,
    );
    expect(Routes.communityPostBase.startsWith(Routes.community), isTrue);
  });
}
