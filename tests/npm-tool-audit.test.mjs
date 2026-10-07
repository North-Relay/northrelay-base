import { test } from 'node:test';
import assert from 'node:assert/strict';
import { evaluate } from '../scripts/check-npm-tool-audit.mjs';
const manifest = { dependencies: { npm: '11.19.1', undici: '6.29.0' } };
const vuln = (name, nodes) => ({ name, severity: 'high', nodes });
test('exempts only the bundled copy of a replaced module', () => {
  const result = evaluate({ vulnerabilities: { undici: vuln('undici', ['node_modules/npm/node_modules/undici']) } }, manifest);
  assert.deepEqual(result.blocking, []);
});
test('blocks bundled modules without a replacement', () => {
  const result = evaluate({ vulnerabilities: { 'http-cache-semantics': vuln('http-cache-semantics',
    ['node_modules/npm/node_modules/http-cache-semantics']) } }, manifest);
  assert.deepEqual(result.blocking.map(v => v.package), ['http-cache-semantics']);
});
test('blocks a vulnerable replacement and nested copies', () => {
  const result = evaluate({ vulnerabilities: { undici: vuln('undici', ['node_modules/undici',
    'node_modules/npm/node_modules/undici', 'node_modules/npm/node_modules/x/node_modules/undici']) } }, manifest);
  assert.deepEqual(result.blocking.map(v => v.node),
    ['node_modules/undici', 'node_modules/npm/node_modules/x/node_modules/undici']);
});
test('npm itself is never treated as a replacement', () => {
  const result = evaluate({ vulnerabilities: { npm: vuln('npm', ['node_modules/npm/node_modules/npm']) } }, manifest);
  assert.equal(result.blocking.length, 1);
});
test('fails closed without audit evidence', () => assert.throws(() => evaluate({ error: {} }, manifest), /Missing/));
