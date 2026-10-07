import { readFileSync } from 'node:fs';
// npm ships its dependencies bundled, so overrides cannot reach them and npm audit keeps
// reporting the bundled copies. Builders delete each bundled module that tools/npm/package.json
// installs at top level (see Dockerfile.builder); only those exact bundled nodes are exempt.
// The top-level replacements are audited normally, so a vulnerable replacement still blocks.
export function evaluate(audit, manifest) {
  if (!audit || typeof audit.vulnerabilities !== 'object') throw new Error('Missing npm audit results');
  const replaced = new Set(Object.keys(manifest.dependencies || {}).filter(name => name !== 'npm'));
  const findings = Object.values(audit.vulnerabilities);
  const blocking = findings.flatMap(v => (v.nodes || []).filter(node =>
    !(replaced.has(v.name) && node === `node_modules/npm/node_modules/${v.name}`))
    .map(node => ({ package: v.name, severity: v.severity, node })));
  return { total: findings.length, blocking };
}
if (process.argv[3]) {
  const result = evaluate(JSON.parse(readFileSync(process.argv[2], 'utf8')),
    JSON.parse(readFileSync(process.argv[3], 'utf8')));
  console.log(JSON.stringify(result, null, 2));
  if (result.blocking.length) process.exitCode = 1;
}
