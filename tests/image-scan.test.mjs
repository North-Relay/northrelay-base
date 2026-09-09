import { test } from 'node:test';
import assert from 'node:assert/strict';
import { evaluate } from '../scripts/check-image-scan.mjs';
test('rejects available fixes and high severity findings without fixes', () => {
  const result = evaluate({ Results: [{ Vulnerabilities: [
    { VulnerabilityID: 'critical', Severity: 'CRITICAL', FixedVersion: '2' },
    { VulnerabilityID: 'low', Severity: 'LOW', FixedVersion: '3' },
    { VulnerabilityID: 'unfixed', Severity: 'HIGH' },
  ] }] });
  assert.equal(result.total, 3);
  assert.deepEqual(result.blocking.map(v => v.id), ['critical', 'low', 'unfixed']);
});
test('accepts an actually clean report', () => assert.deepEqual(evaluate({ Results: [{}] }), { total: 0, blocking: [] }));
test('fails closed without scan evidence', () => assert.throws(() => evaluate({}), /Missing/));
