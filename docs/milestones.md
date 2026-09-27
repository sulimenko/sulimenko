# Implementation milestones

Every milestone must leave the repository buildable/testable.

## M0 - Architecture and repository bootstrap

Deliverables:

- ADR-0001 accepted.
- Public GitHub repository exists; public source code is an explicit project decision.
- Monorepo directories, README, editor settings, gitignore.
- Version policy documented.

Exit criteria: repository contains architecture only; no speculative UI framework.

## M1 - Runnable platform skeleton

- Scaffold `apps/web` with Nuxt 4.5.x and Vue 3.5.x.
- Scaffold `apps/api` with Laravel 13 and PHP 8.5 requirement.
- Configure Node 24 LTS.
- Add PostgreSQL 18 local development service/configuration.
- Same-origin dev proxy strategy.
- Health endpoints/pages.
- CI: frontend typecheck/test/build, backend test, PostgreSQL service.

Exit criteria: clean clone starts both apps and CI is green.

## M2 - Database core and audit foundation

- Core migrations and UUIDv7 models.
- HistoricalDate value object.
- FK/CHECK/UNIQUE constraints.
- AuditLog table, generic PostgreSQL trigger/function, request context middleware/service.
- Seed one Family and one admin user through explicit environment/bootstrap command.

Exit criteria: database feature tests prove constraints and audit INSERT/UPDATE/DELETE.

## M3 - Passwordless admin authentication

- Magic-link request/consume/logout/session endpoints.
- Sanctum SPA auth.
- Neutral response, token hashing, 10-minute expiry, single use, row lock, session regeneration.
- Rate limits email+IP and IP ceiling.
- `/admin/login` and protected admin shell.

Exit criteria: feature + E2E tests prove login and reuse rejection.

## M4 - Person and relationship domain API

- Person CRUD and translations/names.
- FamilyUnit CRUD.
- ParentChildRelationship CRUD.
- Domain cycle validation.
- Unified API problem format.
- Admin pages with minimal unstyled/neutral UI pending Kimi design.

Exit criteria: CRUD and integrity tests green; no raw Eloquent resources exposed.

## M5 - Public Person SSR and media

- `/people/{slug}` SSR biography.
- Metadata, canonical, JSON-LD foundation.
- Local original + web derivative upload.
- Public optimized portrait delivery.
- `/people` basic SSR index.

Exit criteria: public Person is fully SSR-visible with no JS requirement for biography text.

## M6 - Topology projection and client cache

- `GET /api/v1/family/topology`.
- Compact DTO only.
- Stable ordering, weak ETag, 304 handling.
- Family topology revision bump on graph mutations.
- Pinia normalized topology store.
- Pure visible-subgraph selector with tests.

Exit criteria: Person reroot target can be resolved entirely from cached topology.

## M7 - Vue Flow + ELK Worker baseline tree

- Vue Flow stable 1.x.
- Domain-to-layout transformer.
- Invisible FamilyUnit junction nodes.
- ELK worker and protocol.
- Initial direct URL layout, pan/zoom, Person click, keyboard focus.
- Mobile full-viewport tree and details bottom sheet shell.

Exit criteria: functional tree with worker-only layout computation.

## M8 - Production reroot transition engine

- One-RAF animation coordinator.
- Enter/retain/leave mapping by stable IDs.
- Nearest-branch enter/leave origins.
- Viewport interpolation.
- Generation IDs.
- Worker terminate/recreate cancellation.
- Rapid navigation restart from current interpolated state.
- Reduced motion.
- Worker error fallback.

Exit criteria: race/cancellation/component-lifecycle tests and E2E URL-without-reload test pass.

## M9 - Design integration

- Apply Kimi Production Design Prompt.
- Design tokens, typography, responsive details, cards, tree visuals, exact motion timing.
- Preserve established architecture and transition contracts.

Exit criteria: visual QA desktop/mobile, accessibility pass.

## M10 - Public placeholder surfaces and deployment hardening

- Home production page.
- Quality placeholders for timeline/places/archive/principles/projects/family-access.
- Nginx production routing.
- 302 for `alexey.sulimenko.com`.
- Backups, restore runbook, secure env, logging, cache headers.
- Full E2E smoke suite.

Exit criteria: production deployment checklist complete.
