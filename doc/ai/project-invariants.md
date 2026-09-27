# SULIMENKO project invariants

## Product architecture

SULIMENKO is a long-lived public family digital platform.

The repository is a monorepo:

- `apps/web` — Nuxt 4 / Vue 3 / TypeScript frontend, SSR, public UI and admin UI.
- `apps/api` — Laravel 13 backend, domain logic, authentication, persistence and files.
- PostgreSQL 18 is the authoritative data store.

Laravel is the only owner of application business logic and PostgreSQL persistence.
Nuxt server code must not duplicate Laravel domain rules.

The system has one canonical Family Graph. `/family/{personSlug}` changes only the selected viewpoint on that graph.

Read `docs/adr/0001-core-architecture.md` before architectural or domain changes.

## Runtime

Required local runtimes:

- Node.js 24
- PHP 8.5
- PostgreSQL 18

Local development on macOS does not use Docker.
Docker may be used later on the server/deployment environment.

Do not automatically run destructive or schema-mutating database commands.
Commands such as `migrate`, `migrate:fresh`, rollback, DROP or production ALTER operations require an explicit operator step.

Tests that use PostgreSQL must use a dedicated test database, never the development database.

## Data and security

The GitHub repository is public.

Never commit:

- `.env` files;
- passwords, tokens, credentials or private keys;
- database dumps;
- original private family media;
- login/magic-link tokens;
- machine-specific configuration containing secrets.

Domain IDs use UUIDv7.
Human-readable slugs are alternate identifiers and are never foreign keys.

PostgreSQL/Laravel are the source of truth. Pinia is a client projection/cache only.

## Dependency policy

Do not introduce additional frameworks or major dependencies without an explicit architectural reason.

In particular, do not introduce:

- Vue 3.6 prereleases;
- Vue Flow 2 prereleases;
- Motion Vue;
- a second graph library;
- a media-management framework;
- JWT for the first-party admin UI.

Use the dependency policy in ADR-0001 as the authority.

## Implementation priorities

Every milestone must leave the repository buildable and reviewable.

Prefer small bounded changes over broad speculative implementation.
Do not implement later milestones prematurely.

Current milestone progression is defined by `docs/milestones.md`.
