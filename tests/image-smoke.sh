#!/usr/bin/env bash
set -euo pipefail
image="$1"
docker run --rm --entrypoint node "$image" -e "require('mjml')('<mjml><mj-body><mj-section><mj-column><mj-text>Smoke test</mj-text></mj-column></mj-section></mj-body></mjml>'); require('bullmq'); require('ioredis'); require.resolve('tsx'); console.log('runtime modules passed')"
docker run --rm --entrypoint node "$image" node_modules/tsx/dist/cli.mjs -e "console.log('tsx runtime passed')"
if [[ "$image" == *builder* ]]; then
  docker run --rm --entrypoint sh "$image" -c 'test "$(npm --version)" = 11.19.1 && npx --no-install prisma --version'
else
  docker run --rm --entrypoint sh "$image" -ec '
    test "$(id -u)" = 1001
    ! command -v npm
    ! command -v npx
    ! command -v yarn
    test -s /usr/share/minio-mc/compiled-packages.txt
    ! grep -q "^golang.org/x/crypto/openpgp" /usr/share/minio-mc/compiled-packages.txt
    mc --version
    mkdir -p /tmp/mc-smoke
    printf "backup smoke test\n" > /tmp/mc-smoke/source
    mc cp /tmp/mc-smoke/source /tmp/mc-smoke/destination
    cmp /tmp/mc-smoke/source /tmp/mc-smoke/destination
  '
fi
