import { test } from 'node:test';
import assert from 'node:assert/strict';
import { activity } from '../dist/state.js';

test('sends only normalized hostname from a full URL', () => {
  assert.deepEqual(activity(true, false, 'https://WWW.YouTube.com/watch?v=secret#private'), {state:'active', hostname:'www.youtube.com'});
  assert.deepEqual(activity(true, false, 'https://bücher.de/secret'), {state:'active', hostname:'xn--bcher-kva.de'});
});
test('private, background, unsupported and malformed pages have no hostname', () => {
  for (const [focused, privateWindow, url] of [
    [true, true, 'https://secret.com/path'], [false, false, 'https://secret.com'],
    [true, false, 'chrome://settings'], [true, false, 'file:///private/file'],
    [true, false, 'invalid'], [true, false, 'https://[::1]/'], [true, false, undefined]
  ]) {
    const result = activity(focused, privateWindow, url);
    assert.equal(Object.hasOwn(result, 'hostname'), false);
    assert.notEqual(result.state, 'active');
  }
});
