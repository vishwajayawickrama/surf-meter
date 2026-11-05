import { test } from 'node:test';
import assert from 'node:assert/strict';

test('worker reports changes, excludes private windows, reconnects, and drops stale queries', async () => {
  function event() {
    const listeners = [];
    return { addListener: fn => listeners.push(fn), fire: () => listeners.forEach(fn => fn()) };
  }
  const sent = [];
  let disconnected;
  let connectedCount = 0;
  let window = { id:1, focused:true, incognito:false, type:'normal' };
  let queryWindow = () => Promise.resolve(window);
  const events = { activated:event(), updated:event(), removed:event(), focus:event(), closed:event(), startup:event(), installed:event(), alarm:event(), click:event() };
  globalThis.chrome = {
    runtime: { connectNative: name => {
      assert.equal(name, 'dev.surfmeter.bridge');
      connectedCount++;
      disconnected = event();
      return { disconnect: () => disconnected.fire(), postMessage: message => sent.push(message), onDisconnect:disconnected, onMessage:event() };
    }, onStartup:events.startup, onInstalled:events.installed },
    tabs: { query: async () => [{incognito:false, url:'https://example.com/path?secret=1'}], onActivated:events.activated, onUpdated:events.updated, onRemoved:events.removed },
    windows: { getLastFocused: () => queryWindow(), onFocusChanged:events.focus, onRemoved:events.closed },
    alarms: {create: async () => {}, onAlarm:events.alarm},
    action: {setBadgeText:async () => {}, setTitle:async () => {}, onClicked:events.click}
  };
  const originalInterval = globalThis.setInterval;
  globalThis.setInterval = () => 0;
  const settle = () => new Promise(resolve => setImmediate(resolve));
  try {
    await import('../dist/background.js');
    await settle();
    assert.equal(sent.at(-1).hostname, 'example.com');
    assert.equal('url' in sent.at(-1), false);
    const session = sent.at(-1).sessionID;
    window = {...window, incognito:true};
    events.focus.fire(); await settle();
    assert.equal(sent.at(-1).state, 'unavailable');
    assert.equal('hostname' in sent.at(-1), false);
    window = {...window, incognito:false, focused:false};
    events.focus.fire(); await settle();
    assert.equal(sent.at(-1).state, 'inactive');
    let resolveOld;
    queryWindow = () => new Promise(resolve => { resolveOld = resolve; });
    events.focus.fire();
    queryWindow = () => Promise.resolve({...window, focused:true});
    events.activated.fire(); await settle();
    const latest = sent.length;
    resolveOld({...window, focused:false}); await settle();
    assert.equal(sent.length, latest, 'older focus result overwrote latest state');
    disconnected.fire();
    events.click.fire(); await settle();
    assert.equal(connectedCount, 2);
    assert.equal(sent.at(-1).sessionID, session);
    assert.ok(sent.every((value, index) => index === 0 || value.sequence > sent[index-1].sequence));
  } finally { globalThis.setInterval = originalInterval; delete globalThis.chrome; }
});
