# <abbr>-api-gateway

Single entry point of the system: routing, the cheap authentication filter,
rate limiting and CORS. It is **configuration, not code** — which is why it
has no language variant. A gateway written by hand in Go, Java, Python or C#
is an application someone now has to maintain; a declarative proxy is not.
If the team needs logic a proxy cannot express, that is a decision for an ADR.

```
nginx/nginx.conf                      global settings, log format, includes
nginx/conf.d/00-resolver.conf         per-request DNS: a domain that is down does not take the gateway down
nginx/conf.d/10-security.conf         rate-limit zones, CORS origins, correlation id, the credentials filter
nginx/conf.d/20-server.conf           the server block, the gateway's own errors, includes every route file
nginx/snippets/headers.conf           headers every response carries (CORS, security, X-Correlation-Id)
nginx/routes/<domain>.conf            ONE file per domain — each team adds its own
nginx/routes/workflow.conf            /api/v1/sagas -> <abbr>-workflow
nginx/routes/_health.conf
deploy/
tests/smoke.sh                        the checks the gateway must pass
```

## What the gateway does — and what it does not

| Responsibility | Where |
|---|---|
| Route `/api/v1/<domain>/...` to the right service | here |
| Reject a protected request that carries **no** `Authorization` header | here (cheap filter) |
| Rate limiting and CORS (`Idempotency-Key` and `X-Correlation-Id` allowed, `X-Correlation-Id` exposed) | here |
| Reuse or create `X-Correlation-Id`, pass it to the service, return it, log it | here |
| Answer its **own** errors with the shared error envelope: `401 UNAUTHORIZED`, `404 NOT_FOUND`, `429 TOO_MANY_REQUESTS`, `503 SERVICE_UNAVAILABLE` | here |
| **Validate** the token (signature, expiry, claims) | **each service**, never only here |
| Business rules | never here |

Services reached **internally** do not go through the gateway, so they must not
trust that someone else validated the token.

## Adding a domain

1. Add `routes/<domain>.conf` with its `location` blocks, using a variable in
   `proxy_pass` exactly as `routes/orders.conf` does. A location that adds a
   header must `include /etc/nginx/snippets/headers.conf`: nginx drops the outer
   `add_header` lines as soon as a location declares its own.
2. Run `tests/smoke.sh`.

```bash
docker compose -f deploy/compose.yml up -d
./tests/smoke.sh http://localhost:8000
```
