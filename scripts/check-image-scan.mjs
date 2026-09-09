import { readFileSync } from 'node:fs';
export function evaluate(report) {
  if (!Array.isArray(report.Results)) throw new Error('Missing image scan results');
  const findings = report.Results.flatMap(result => result.Vulnerabilities || []);
  const blocking = findings.filter(v => typeof v.FixedVersion === 'string' && v.FixedVersion.trim());
  return { total: findings.length, blocking: blocking.map(v => ({
    id: v.VulnerabilityID, package: v.PkgName, installed: v.InstalledVersion, fixed: v.FixedVersion,
  })) };
}
if (process.argv[2]) {
  const result = evaluate(JSON.parse(readFileSync(process.argv[2], 'utf8')));
  console.log(JSON.stringify(result, null, 2));
  if (result.blocking.length) process.exitCode = 1;
}
