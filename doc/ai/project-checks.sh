#!/usr/bin/env bash
set -euo pipefail

BASE_BRANCH="${BASE_BRANCH:-develop}"
CHECK_MODE="${CHECK_MODE:-default}"

ROOT_DIR="$(git rev-parse --show-toplevel)"
cd "$ROOT_DIR"

echo "==> SULIMENKO project checks"
echo "mode=$CHECK_MODE base=$BASE_BRANCH"

if ! command -v node >/dev/null 2>&1; then
    echo "ERROR: Node.js not found"
    exit 1
fi

NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"

if [ "$NODE_MAJOR" != "24" ]; then
    echo "ERROR: Node.js 24 required, found $(node --version)"
    exit 1
fi

if ! command -v php >/dev/null 2>&1; then
    echo "ERROR: PHP not found"
    exit 1
fi

PHP_MAJOR_MINOR="$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')"

if [ "$PHP_MAJOR_MINOR" != "8.5" ]; then
    echo "ERROR: PHP 8.5 required, found $(php -r 'echo PHP_VERSION;')"
    exit 1
fi

if ! php -m | grep -q '^pdo_pgsql$'; then
    echo "ERROR: PHP pdo_pgsql extension not available"
    exit 1
fi

if ! php -m | grep -q '^pgsql$'; then
    echo "ERROR: PHP pgsql extension not available"
    exit 1
fi

echo "==> Runtime"
node --version
php -r 'echo "PHP ".PHP_VERSION.PHP_EOL;'
psql --version

echo "==> Git checks"
git diff --check
git diff --cached --check

changed_files() {
    {
        git diff --name-only "$BASE_BRANCH"...HEAD 2>/dev/null || true
        git diff --name-only 2>/dev/null || true
        git diff --cached --name-only 2>/dev/null || true
        git ls-files --others --exclude-standard 2>/dev/null || true
    } | awk 'NF' | sort -u
}

run_php_lint_changed() {
    local files

    files="$(
        changed_files |
        grep '^apps/api/.*\.php$' || true
    )"

    if [ -z "$files" ]; then
        echo "==> PHP lint: no changed PHP files"
        return 0
    fi

    while IFS= read -r file; do
        if [ -f "$file" ]; then
            php -l "$file" >/dev/null
            echo "PHP OK: $file"
        fi
    done <<< "$files"
}

run_backend_validate() {
    echo "==> Composer validate"
    (
        cd apps/api
        composer validate --no-check-publish
    )
}

run_frontend_build() {
    echo "==> Nuxt production build"
    (
        cd apps/web
        npm run build
    )
}

case "$CHECK_MODE" in
    syntax-only)
        run_php_lint_changed
        ;;

    backend)
        run_php_lint_changed
        run_backend_validate
        ;;

    frontend-build)
        run_frontend_build
        ;;

    full)
        run_php_lint_changed
        run_backend_validate
        run_frontend_build
        git diff --check "$BASE_BRANCH"...HEAD
        ;;

    default)
        run_php_lint_changed
        run_backend_validate
        run_frontend_build
        ;;

    *)
        echo "ERROR: unknown CHECK_MODE=$CHECK_MODE"
        exit 1
        ;;
esac
