# ADR-0001: Core architecture for SULIMENKO

- Status: PROPOSED
- Date: 2026-09-27
- Decision owners: Project owner and Senior Software Architect

## Context

SULIMENKO is a long-lived public family digital platform. It must support an interactive genealogy graph, SSR public biography pages, a first-party admin application, passwordless authentication, auditability, and future expansion without rewriting the Person / Family / Relationship core.

The system has one canonical Family Graph. A Person route is a viewpoint on that graph, not a separate tree.

## Decision summary

Use one monorepo with a Nuxt frontend and a Laravel backend:

```text
apps/web  -> Nuxt SSR, public UI, interactive tree, admin UI
apps/api  -> Laravel API, domain rules, authentication, persistence, files
PostgreSQL -> single source of truth for domain data
```

Nuxt server routes must not duplicate business logic. Same-origin reverse proxying sends `/api/*` and `/sanctum/*` directly to Laravel.

## 1. Frontend architecture

### 1.1 Nuxt responsibilities

Nuxt owns:

- SSR and SEO for public pages.
- Routing and page composition.
- Client-side Family Tree experience after hydration.
- Admin UI.
- Presentation-level state and caches.

Nuxt does not own domain persistence or domain mutation rules.

### 1.2 Route model

Primary routes:

- `/`
- `/family/{personSlug}`
- `/people`
- `/people/{personSlug}`
- `/timeline`
- `/places`
- `/archive`
- `/principles`
- `/projects`
- `/family-access`
- `/admin`
- `/admin/people`
- `/admin/people/{id}`
- `/admin/family-units`
- `/admin/relationships`
- `/admin/media`
- `/admin/audit`

The `/family/{personSlug}` route uses one stable Family Tree host instance. Route param changes must not recreate the graph component. The implementation must use one route record and a constant page/component key or a persistent family layout, verified by an automated component lifecycle test.

### 1.3 SEO and canonical strategy

- `/people/{personSlug}` is the canonical biography URL.
- It is SSR-rendered and contains full biography content and metadata.
- `/family/{personSlug}` has Person-specific title and description but does not duplicate the full biography.
- `/family/{personSlug}` declares canonical `/people/{personSlug}`.
- Recommended initial robots policy for `/family/*`: `noindex,follow` to prevent duplicate/thin interactive pages from competing with biography pages. This can be relaxed later without data-model changes.
- Placeholder public routes are `noindex` until they contain substantive content.

### 1.4 Client state

Pinia stores projections/caches only. PostgreSQL/Laravel remain authoritative.

Core stores:

- `familyTopologyStore`: normalized whole-family topology, ETag, graph revision.
- `personProfileStore`: lazily loaded Person profiles for details/bottom sheet.
- `treeViewStore`: selected/root Person, current visible subgraph, viewport state, transition status.
- `authStore`: current admin session only.

### 1.5 Topology provider abstraction

Tree components consume a topology provider interface, not HTTP directly. Initial provider loads the complete public topology once. A future neighborhood provider can merge server-loaded neighborhoods into the same normalized store without changing public tree component APIs.

## 2. Backend architecture

Laravel is the only application backend and owns:

- Versioned API.
- Domain validation and genealogy integrity rules.
- Authentication and authorization.
- PostgreSQL persistence.
- Audit context for mutations.
- File upload and derivative generation.
- Topology projection and cache revisioning.

Use service classes for cross-aggregate mutations, not fat controllers and not Eloquent observers as the only source of behavior.

Suggested modules/namespaces:

```text
App/Domain/Family
App/Domain/People
App/Domain/Relationships
App/Domain/Media
App/Domain/Auth
App/Domain/Audit
App/Http/Controllers/Api/V1
App/Http/Resources/Api/V1
```

## 3. Identifiers

All domain entity primary keys use native PostgreSQL `uuid` columns and UUIDv7 values.

Laravel 13 `HasUuids` generates UUIDv7. Slugs are human-readable alternate identifiers only and are never foreign keys.

Slug uniqueness:

- Person slug: globally unique on the site because the public route has no Family namespace.
- Family slug: unique in the Family namespace.

Future slug redirect/history can be added without relation migrations.

## 4. Database model

Minimum tables:

- `families`
- `people`
- `person_names`
- `person_translations`
- `family_units`
- `family_unit_members`
- `parent_child_relationships`
- `places`
- `media`
- `users`
- `login_tokens`
- `audit_logs`

Operational tables such as sessions and cache records may also exist.

### 4.1 Family

`families` is the graph container and carries a monotonically increasing `topology_revision` used for cache invalidation/ETag generation.

### 4.2 Person

A Person is independent of family unions. Core fields include:

- UUIDv7 `id`
- `family_id`
- unique `slug`
- optional genealogical sex value only when needed
- birth partial-date fields
- death partial-date fields
- `birth_place_id`, `death_place_id`
- publication and visibility fields, default public/published
- timestamps

Biography text is localized in `person_translations`.

### 4.3 Partial historical dates

Do not store unknown dates as fake January 1 values.

For birth/death MVP use:

- `{prefix}_year nullable integer`
- `{prefix}_month nullable smallint`
- `{prefix}_day nullable smallint`
- `{prefix}_precision` with values `exact`, `month`, `year`, `circa`, `unknown`

Database CHECK constraints enforce structural consistency and simple ranges. A Laravel `HistoricalDate` value object validates real calendar dates and converts API payloads.

### 4.4 Person names and translations

`person_names` supports multiple names and contains name type, native spelling, transliteration, locale/script metadata, primary flag, and stable ordering.

`person_translations` is unique on `(person_id, locale)` and contains localized display name, short biography, extended biography, and optional SEO fields.

### 4.5 FamilyUnit

A FamilyUnit is a union/household/partnership grouping and is not restricted to one male + one female.

It supports multiple partnerships over time and ended/former partnerships. A FamilyUnit may have one known member when another parent/partner is unknown; the system does not create fake `Unknown Person` records.

### 4.6 FamilyUnitMember

Unique `(family_unit_id, person_id)`. Membership role is non-gendered. Start/end partial dates can be added as needed.

### 4.7 ParentChildRelationship

Contains:

- `parent_person_id`
- `child_person_id`
- optional `family_unit_id`
- relationship type: `biological`, `adoptive`, `step`, `guardian`, `unknown`

Constraints:

- parent cannot equal child
- exact duplicate relationship is forbidden
- cross-Family relationships are forbidden

Use composite foreign keys with `family_id` where practical so PostgreSQL also enforces same-Family consistency.

More complex ancestry cycles are rejected by a Laravel domain service using graph traversal/recursive query inside the mutation transaction.

### 4.8 Future GEDCOM compatibility

The model maps cleanly to the core concepts needed later:

- INDI -> Person
- FAM -> FamilyUnit
- names -> PersonName
- family membership -> FamilyUnitMember
- children -> ParentChildRelationship
- events -> future PersonEvent/Event model
- media -> Media
- sources/citations -> future Source/Citation tables

GEDCOM import/export is explicitly outside MVP.

## 5. Public topology API

Initial endpoint:

`GET /api/v1/family/topology`

Response is a projection, not a database dump. It contains only tree data:

- topology schema version
- Family ID
- topology revision
- compact people
- compact family units
- memberships
- parent-child relationships
- presentation flags

It excludes full biography and original media.

The endpoint supports `ETag` and `If-None-Match`. The recommended ETag is a weak ETag derived from topology schema version + Family UUID + `topology_revision`. Response ordering must be deterministic.

Graph-related admin mutations bump `topology_revision` in the same database transaction and invalidate the serialized topology cache.

## 6. Visible subgraph module

The visible subgraph algorithm is a deterministic pure TypeScript module. It receives normalized topology, root Person ID, and a visibility policy.

Default policy:

- ancestors: depth 2
- descendants: depth 2
- root siblings
- root spouses/partners
- co-parents required to render included children correctly
- directly required FamilyUnits

It returns stable sorted IDs for Persons, FamilyUnits, memberships, and relationships.

No Vue, Pinia, router, or network code is allowed inside this module.

## 7. Graph rendering pipeline

1. Route/root Person changes.
2. Visible subgraph is computed synchronously from cached topology.
3. Pure graph-transform module converts domain graph -> layout graph.
4. FamilyUnit is represented as a small invisible/specialized junction node when needed.
5. Layout request is sent to a dedicated ELK Web Worker.
6. ELK returns stable node positions.
7. Animation coordinator interpolates from current visual state to target layout.
8. Vue Flow renders nodes, edges, pan, zoom, focus, pointer and keyboard interactions.

ELK never runs on the main UI thread.

Person Vue Flow node IDs are stable across layouts. FamilyUnit layout node IDs are separately namespaced.

## 8. Rapid navigation and Worker cancellation

A generation ID identifies every reroot operation.

When a new Person is selected during an active transition:

1. Sample the current interpolated visual state.
2. Commit that sampled state as the new transition start.
3. Increment generation.
4. Cancel obsolete network requests with AbortController where applicable.
5. If ELK is still computing an obsolete request, terminate that Worker and create a fresh Worker immediately.
6. Compute/request only the newest target layout.
7. Ignore any result whose generation is not current.

This avoids both stale application and CPU-side queueing behind an obsolete ELK calculation.

## 9. Animation state machine

States:

- `stable`
- `layout-pending`
- `animating`
- `layout-error`

One requestAnimationFrame clock controls the entire layout transition.

The coordinator owns:

- retained node position interpolation
- entering node origin + opacity
- leaving node target + opacity
- viewport interpolation

Entering nodes originate from the closest already-visible connected branch. Leaving nodes move/fade toward the closest retained connected branch before removal.

Edges are rendered from current node positions every frame so they stay synchronized. Do not run unrelated per-node CSS position animations.

Default motion duration is a design token initially set near 550 ms and later replaced by the Kimi design specification.

With `prefers-reduced-motion`, apply the target layout immediately or with a very short non-essential transition.

## 10. Authentication

No passwords and no public registration.

MVP flow:

`POST /api/v1/auth/magic-links`

Always returns the same neutral accepted response. If the email belongs to an active admin:

- create 32 random bytes of cryptographic token material
- return/send plaintext only in the email URL
- store SHA-256 token hash only
- set expiry near 10 minutes
- generate Laravel temporary signed URL
- send through configured Laravel mail transport

Consume endpoint runs in a database transaction and locks the LoginToken row. It validates signature, hash, expiry, unused state, and active admin status, atomically sets `used_at`, logs the user in, regenerates the session ID, and redirects to `/admin`.

Rate limiting is keyed by normalized email + client IP with an additional IP-only ceiling.

Protected API uses Laravel Sanctum SPA/session authentication. No JWT for the first-party admin UI.

`users` supports multiple future admins using an active/disabled state and admin authorization flag. Passkeys can be added later without removing magic links.

## 11. Audit

`audit_logs` is append-only.

A PostgreSQL generic row-level AFTER trigger is attached to audited domain tables. It records:

- UUIDv7 id
- nullable actor user UUID
- nullable request UUID
- table name
- record UUID
- operation
- OLD JSONB
- NEW JSONB
- changed field names
- nullable IP
- nullable user agent
- timestamp

Before each application mutation, Laravel opens a transaction and calls transaction-local `set_config(..., true)` for:

- `app.actor_user_id`
- `app.request_id`
- `app.ip_address`
- `app.user_agent`

The trigger uses `current_setting(..., true)` and gracefully stores NULL if context is absent. Direct DB/artisan changes therefore remain auditable.

Eloquent observers may add application behavior but are never the sole audit source.

The audit table itself is not audited. Update/delete access to audit rows is blocked by application policy and should also be protected at the database layer.

## 12. File storage

MVP uses Laravel filesystem only.

```text
storage/app/private/persons/{personId}/original/
storage/app/public/persons/{personId}/web/
```

Database stores disk/path/metadata, never image binaries.

Original uploads are retained privately. Web derivatives are generated on upload using a native PHP imaging extension when available, strip unnecessary metadata, and are safe for public delivery. The domain stores logical disk + paths so changing to an S3-compatible disk later does not alter Person/Media relations.

No media-management framework is introduced in MVP.

## 13. API error contract

Use an RFC 9457-style Problem Details envelope with stable application `code` and `request_id`.

Example fields:

- `type`
- `title`
- `status`
- `code`
- `detail`
- `instance`
- `request_id`
- `errors` for validation failures

Production responses never expose raw Laravel exception messages or stack traces.

## 14. Deployment topology

Recommended initial production topology:

```text
Internet
  -> Nginx/TLS
       -> /api/*, /sanctum/* -> PHP-FPM 8.5 -> Laravel 13
       -> /storage/*         -> public Laravel storage derivatives
       -> everything else    -> Node.js 24 LTS -> Nuxt 4.5

Laravel -> dedicated PostgreSQL 18 database
Laravel -> local filesystem
Laravel -> SMTP provider via environment configuration
```

The database is dedicated to SULIMENKO and must not share tables/schema with unrelated products.

The test subdomain `alexey.sulimenko.com` is infrastructure-only and may return a 302 to `https://sulimenko.com/family/alexey-sulimenko`. No wildcard tenant/subdomain architecture is introduced.

## 15. Testing strategy

Backend, against PostgreSQL 18 (not SQLite):

- API feature tests
- magic-link single use / expiry / neutral response / rate limiting
- authorization
- relationship constraints and cycle rejection
- audit trigger INSERT/UPDATE/DELETE behavior
- topology projection and ETag/304
- topology revision invalidation

Frontend:

- visible-subgraph pure module
- domain graph -> Vue Flow graph transformation
- reroot behavior
- route synchronization
- rapid navigation generation races
- active animation cancellation and restart from interpolated state
- reduced-motion behavior
- Worker failure fallback

E2E with Playwright:

- direct Family Tree URL
- Person selection updates URL without document reload
- reroot transition
- browser back/forward
- mobile pan/zoom/tap/bottom sheet
- magic-link admin login
- admin Person mutation changes topology revision and public graph projection

## 16. Dependency policy

Initial specialized production dependencies are intentionally narrow:

- Nuxt / Vue / Vue Router
- Pinia
- Vue Flow stable 1.x
- elkjs
- Laravel / Sanctum

Do not adopt Vue Flow 2 prerelease, Vue 3.6 prerelease, Motion Vue, a second graph library, a media framework, S3 client abstraction beyond Laravel Filesystem, or a heavy UI framework before a demonstrated need.

## Consequences

### Benefits

- One canonical graph and stable Person IDs.
- Frontend reroots without mandatory network requests.
- Business logic has one owner.
- Family graph remains extensible for multiple partnerships, unknown parents, adoption and future GEDCOM support.
- Audit survives application bypass paths.
- Future neighborhood loading, S3, passkeys, private access, and source citations can be added incrementally.

### Costs

- PostgreSQL-specific audit and integrity testing means SQLite cannot be the authoritative test database.
- Family graph animation requires a custom coordinator and careful lifecycle tests.
- Partial historical dates require explicit value objects and validation rather than a single date column.
