#!/bin/bash
set -e
cd "$(dirname "$0")"

services=(analytics auth catalog gateway notifications orders payments recommendations search)

for svc in "${services[@]}"; do
  echo "========== Building $svc =========="
  docker build -t "kindling-test/$svc:local" "./$svc"
  echo "✅ $svc OK"
  echo ""
done

echo "🎉 All ${#services[@]} services built successfully!"
