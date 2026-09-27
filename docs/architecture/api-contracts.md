# API contracts - draft v1

Base path: `/api/v1`

## Public

- `GET /family/topology`
- `GET /people`
- `GET /people/{slug}`

## Authentication

- `POST /auth/magic-links`
- `GET /auth/magic-links/{token}` (temporary signed URL, browser redirect response)
- `GET /auth/session`
- `POST /auth/logout`

## Admin

- `GET|POST /admin/people`
- `GET|PATCH|DELETE /admin/people/{id}`
- `GET|POST /admin/family-units`
- `GET|PATCH|DELETE /admin/family-units/{id}`
- `GET|POST /admin/relationships`
- `GET|PATCH|DELETE /admin/relationships/{id}`
- `GET|POST /admin/media`
- `DELETE /admin/media/{id}`
- `GET /admin/audit-logs`

The API is domain-oriented. Database table names and internal columns are not the contract.

## Topology response envelope

```json
{
  "schemaVersion": 1,
  "familyId": "uuid-v7",
  "revision": 42,
  "people": [],
  "familyUnits": [],
  "familyUnitMembers": [],
  "parentChildRelationships": []
}
```

Compact Person topology fields:

```json
{
  "id": "uuid-v7",
  "slug": "alexey-sulimenko",
  "displayName": "...",
  "birthYear": 1982,
  "deathYear": null,
  "portrait": { "smallUrl": "/storage/..." },
  "flags": {}
}
```

No biography or original-media URL is allowed in topology.

## Error envelope

```json
{
  "type": "https://sulimenko.com/problems/validation",
  "title": "Validation failed",
  "status": 422,
  "code": "validation_failed",
  "detail": "One or more fields are invalid.",
  "request_id": "uuid-v7",
  "errors": {
    "slug": ["The slug is already in use."]
  }
}
```
