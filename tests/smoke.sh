#!/bin/sh
echo "Running smoke tests..."
curl -f http://localhost:8080/health || exit 1
echo "Smoke tests passed!"
