# API Specification - Factory Asset Manager

This document defines the REST API for the Factory Asset Manager backend.

Notes for devs using Codespaces and Copilot:
- Open this repo in Codespaces, start the app with the provided dev script or Docker.
- Use Copilot chat inline to generate handlers, DTOs, and tests based on endpoint specs below.
- Keep request/response models in sync with DATABASE_SCHEMA.sql and update this file on changes.

Base URL
- Local dev: http://localhost:3000 (or the forwarded Codespaces port)
- Prefix: /api
- All responses are JSON; use application/json. Timestamps are ISO 8601 (UTC).
- Auth: JWT Bearer in Authorization header unless otherwise noted.

Errors
- Error shape: { "error": { "code": string, "message": string, "details"?: any } }
- Common codes: validation_error, not_found, unauthorized, forbidden, conflict, internal_error

Pagination & Filtering
- Query params: page (1-based), pageSize (default 20, max 100), sort, order, q (search)
- List responses: { items: T[], page, pageSize, total }

Authentication
1) POST /api/auth/register
- Role: Admin only to create other admins; public to create operators if enabled by config.
- Body: { email, password, name, role?: "admin"|"manager"|"operator" }
- 201 { id, email, name, role, createdAt }
- 409 if email exists

2) POST /api/auth/login
- Body: { email, password }
- 200 { accessToken, refreshToken, user: { id, email, name, role } }
- 401 on bad credentials

3) POST /api/auth/refresh
- Body: { refreshToken }
- 200 { accessToken, refreshToken }
- 401 if invalid/expired

4) POST /api/auth/logout
- Header: Authorization: Bearer <access>
- Body: { refreshToken }
- 204

Users
- Entity: { id, email, name, role, isActive, createdAt, updatedAt }

1) GET /api/users
- Auth: admin|manager
- Query: page, pageSize, role, q, isActive
- 200 { items: User[], page, pageSize, total }

2) POST /api/users
- Auth: admin
- Body: { email, name, role, tempPassword? }
- 201 { id, email, name, role, isActive, createdAt }

3) GET /api/users/:id
- Auth: admin|manager (self for operators)
- 200 User; 404 if not found

4) PATCH /api/users/:id
- Auth: admin|manager (limited for manager)
- Body: { name?, role?, isActive? }
- 200 User

5) DELETE /api/users/:id
- Auth: admin
- 204; 409 if user owns critical records

Shops
- Entity: { id, name, code, location?, createdAt, updatedAt }

1) GET /api/shops
- Auth: admin|manager|operator
- Query: page, pageSize, q
- 200 { items: Shop[], page, pageSize, total }

2) POST /api/shops
- Auth: admin|manager
- Body: { name, code, location? }
- 201 Shop; 409 if code exists

3) GET /api/shops/:id
- Auth: admin|manager|operator
- 200 Shop

4) PATCH /api/shops/:id
- Auth: admin|manager
- Body: { name?, code?, location? }
- 200 Shop

5) DELETE /api/shops/:id
- Auth: admin
- 204; 409 if assets still assigned

Assets
- Entity: { id, tag, name, category, status: "available"|"in_use"|"maintenance"|"retired", shopId?, serial?, purchaseDate?, warrantyUntil?, metadata?, qrCode? }

1) GET /api/assets
- Auth: admin|manager|operator
- Query: page, pageSize, q, status, category, shopId, sort (name|tag|status|updatedAt)
- 200 { items: Asset[], page, pageSize, total }

2) POST /api/assets
- Auth: admin|manager
- Body: { tag, name, category, shopId?, serial?, purchaseDate?, warrantyUntil?, metadata? }
- 201 Asset; 409 if tag exists

3) GET /api/assets/:id
- Auth: admin|manager|operator
- 200 Asset

4) PATCH /api/assets/:id
- Auth: admin|manager
- Body: { name?, category?, status?, shopId?, serial?, purchaseDate?, warrantyUntil?, metadata? }
- 200 Asset

5) DELETE /api/assets/:id
- Auth: admin
- 204; 409 if active checkouts or open requests

Asset Requests (assignment/checkout requests)
- Entity: { id, assetId, requesterId, type: "assign"|"checkout"|"return"|"transfer", targetShopId?, status: "pending"|"approved"|"rejected"|"cancelled", note?, createdAt, decidedAt?, decidedBy? }

1) GET /api/asset-requests
- Auth: admin|manager (operators see own via mine=true)
- Query: page, pageSize, status, type, mine
- 200 { items: AssetRequest[], page, pageSize, total }

2) POST /api/asset-requests
- Auth: operator|manager|admin
- Body: { assetId, type, targetShopId?, note? }
- 201 AssetRequest (status=pending)

3) GET /api/asset-requests/:id
- Auth: admin|manager (requester can view)
- 200 AssetRequest

4) POST /api/asset-requests/:id/approve
- Auth: manager|admin
- Body: { note? }
- Effects: updates asset status/shop; creates checkinout log when applicable
- 200 AssetRequest { status: "approved", decidedAt, decidedBy }

5) POST /api/asset-requests/:id/reject
- Auth: manager|admin
- Body: { reason }
- 200 AssetRequest { status: "rejected", decidedAt, decidedBy }

6) POST /api/asset-requests/:id/cancel
- Auth: requester
- 200 AssetRequest { status: "cancelled" }

Operator Requests (maintenance/repair/calibration)
- Entity: { id, assetId, operatorId, requestType: "maintenance"|"repair"|"calibration", description, priority: "low"|"medium"|"high", status: "open"|"in_progress"|"resolved"|"closed", createdAt, updatedAt, closedAt? }

1) GET /api/operator-requests
- Auth: admin|manager (operators see own via mine=true)
- Query: page, pageSize, status, requestType, priority, mine
- 200 { items: OperatorRequest[], page, pageSize, total }

2) POST /api/operator-requests
- Auth: operator|manager|admin
- Body: { assetId, requestType, description, priority }
- 201 OperatorRequest

3) GET /api/operator-requests/:id
- Auth: admin|manager (requester can view)
- 200 OperatorRequest

4) PATCH /api/operator-requests/:id
- Auth: manager|admin
- Body: { status?, description?, priority? }
- 200 OperatorRequest

5) POST /api/operator-requests/:id/close
- Auth: manager|admin
- Body: { resolutionNote? }
- 200 OperatorRequest { status: "closed", closedAt }

Check-in/Check-out Logs
- Entity: { id, assetId, action: "check_out"|"check_in"|"transfer", byUserId, fromShopId?, toShopId?, note?, createdAt }

1) GET /api/checkinout-logs
- Auth: admin|manager
- Query: page, pageSize, assetId, from, to, action, userId
- 200 { items: Log[], page, pageSize, total }

2) POST /api/checkinout-logs
- Auth: manager|admin (system may create upon approvals)
- Body: { assetId, action, toShopId?, fromShopId?, note? }
- 201 Log

QR Scan Workflows
- Endpoints to enable scanning a QR (mapped to asset.tag or encoded id) for quick ops.

1) GET /api/qr/:code
- Auth: operator|manager|admin (optionally public behind feature flag)
- Resolves QR code to asset summary.
- 200 { asset: { id, tag, name, status, shopId }, nextActions: ["check_in"|"check_out"|"transfer"|"details"] }
- 404 if unknown QR

2) POST /api/qr/:code/check-out
- Auth: operator|manager|admin
- Body: { note? }
- 200 { asset, log }

3) POST /api/qr/:code/check-in
- Auth: operator|manager|admin
- Body: { note? }
- 200 { asset, log }

4) POST /api/qr/:code/transfer
- Auth: manager|admin
- Body: { toShopId, note? }
- 200 { asset, log }

Health & Misc
1) GET /api/health
- Public
- 200 { status: "ok", uptime, version, db: "ok"|"degraded"|"down" }

2) GET /api/version
- Public
- 200 { version, commit }

Webhooks (optional)
- POST /api/webhooks/asset-events
- Body: { event: "created"|"updated"|"deleted"|"status_changed", assetId, previous?, current? }

Security & Roles Summary
- Roles: admin > manager > operator; least-privilege enforced per endpoint above.
- Rate limits: recommended 60 req/min per IP; 401/429 responses include Retry-After.
- CSRF: not required for token APIs; required for cookie-based sessions if enabled.

Conventions for Implementation
- Use idempotency for POST that can be retried: Idempotency-Key header.
- Use ETag/If-Match for PATCH concurrency control where possible.
- Validate all inputs with descriptive messages; never leak credential validity details.
- Log requestId (x-request-id) and include in responses for traceability.

OpenAPI
- Keep an OpenAPI 3.1 spec in openapi.yaml in root; sync with this file.
