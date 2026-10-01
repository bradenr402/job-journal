# AGENTS.md

Notes for coding agents working on JobJournal, a privacy-first job search tracker. `README.md` covers features and setup; this file only covers what costs agents time when they don't know it. Treat it as defaults: the engineer directing you can override anything here.

**Keep this file current.** When your change makes anything here wrong or incomplete (commands, ports, versions, file paths, conventions, traps), update this file in the same change. Always tell the user explicitly when you edit this file, and state EXACTLY what changed: quote each removed or replaced line and its replacement (or show the diff). Never update it silently.

## Hard rules

1. **No GitHub writes** (`git push`, PRs, issues, comments, via any channel) without an explicit instruction. **Pushing to `main` deploys to production** on Fly.io (`.github/workflows/fly.yml`). Read operations are always fine.
2. **Never kill Ruby processes by name**; stop only the PID you started.
3. **Scope every record lookup through `Current.user`** (`Current.user.job_leads.find(...)`), never `JobLead.find`.

## Behavior

- State assumptions; if multiple interpretations exist, present them. Push back when a simpler approach exists.
- Minimum code that solves the problem. No speculative abstractions or error handling for impossible cases.
- Surgical changes: touch only what you must, match the style of the file you're in, no drive-by reformatting. Remove code your change made unused; mention pre-existing dead code instead of deleting it.
- If evidence contradicts something you said, retract it plainly.

## Dev environment

- Ruby and Rails versions: `.ruby-version` and `Gemfile.lock` are the source of truth (Ruby 4.0, Rails 8.1 with 8.1 defaults at time of writing).
- SQLite everywhere, including production (Fly volume at `/mnt/sqlite`). Production has four databases — primary, cache, queue, cable — with separate migration dirs (`db/cache_migrate`, `db/queue_migrate`, `db/cable_migrate`).
- Propshaft + importmap (no Node bundler), Tailwind v4 via `tailwindcss-rails`, Turbo + Stimulus, Solid Queue/Cache/Cable.
- `bin/setup`, then `bin/dev` (foreman with `Procfile`: web + `tailwindcss:watch`). The app runs on port 3001.
- `bin/rails db:seed` creates a demo account: `demo@jobjournal.app` / `password`.
- Bullet is active in development: fix N+1 warnings your change introduces. Mail opens via `letter_opener`.
- Deploy is Fly.io only (`fly.toml`, `lib/tasks/fly.rake`). `config/deploy.yml` / `.kamal/` are unused Kamal boilerplate — don't edit them as if they were live.
- Production SMTP reads Gmail credentials from `Rails.application.credentials`.

## Architecture map

- Auth: Rails 8 built-in auth (`app/controllers/concerns/authentication.rb`, `Session`, `Current`). Sessions track device info (`app/lib/device_info.rb`).
- Core models: `JobLead` (statuses lead → applied → interview → offer → rejected/accepted, with `*_at` timestamps and `archived_at`), `Interview`, polymorphic `Note` (`notable`), `Tag`/`Tagging`, `User`, `LandingDemo`.
- Beyond the Rails defaults:
  - `app/filters/` — `JobLeadFilters.new(params, user:, use_settings: true).apply(scope)` and siblings.
  - `app/queries/search_query.rb` — universal search.
  - `app/services/` — `.call`-style services returning results with `success?` (e.g. `JobLeadAutofillFromUrl`), CSV import/export, `PageFetcher`, and `parsers/` (Indeed, LinkedIn) using **Nokolexbor**, not Nokogiri.
  - `lib/dashboard_demo/` + `lib/tasks/demo.rake` regenerate landing-page demo data and screenshots (`SCREENSHOTS=0/1`).

## Tests

- Minitest, pinned to 5.x in the Gemfile (Minitest 6 breaks `minitest/mock`). Don't bump it.
- `bin/rails test` for unit/integration; `bin/rails test:system` separately (Selenium headless Chrome, 1400x1400).
- Fixtures in `test/fixtures/` plus builders in `test/test_helper.rb`: `build_/create_job_lead`, `build_/create_interview`, `build_/create_note`, `unique_application_url` (application URLs are unique), `sign_in_as(user)`.
- Parser tests use `parse_page_fixture(parser_class, dir, name)` to read stored HTML from `test/fixtures/files/` instead of the network.
- `test/documentation/readme_test.rb` tests the README — README edits can break the suite.
- Style: `test "should ..." do`, `assert` / `assert_not` / `assert_includes`.
- CI (`.github/workflows/ci.yml`): `bin/brakeman --no-pager`, `bin/importmap audit`, `bin/rubocop`, `bin/rails db:test:prepare test test:system`. Run the relevant ones before calling work done.

## Manual testing

- Run the app and click through every page your change affects, at desktop and mobile widths, including the PWA/iOS variants when touching layout.
- Think about UI/UX flow, not just correctness; follow existing design conventions. Show the user before and after screenshots for UI changes.

## Code style

- `rubocop-rails-omakase` with double quotes enforced (`.rubocop.yml`). Spaces inside array brackets: `[ :show, :edit ]`.
- Modern Ruby is the norm here:
  - `it` for single-argument blocks (`rows.select { it.action == :skip }`); not `_1`, not `|x|`.
  - Hash shorthand (`render json: { fields: }`).
  - Endless methods for one-liners, as long as the endless method does not harm readability.
  - `%w[]` / `%i[]` for word and symbol arrays, `%()` for strings needing quotes, `%r{}` for regexes.
  - `.pluck("attr")` over `.map { it["attr"] }`.
  - `casecmp?` over `downcase ==`.
  - No single-letter variable names except conventional ones (`i`, `n`).
  - Parentheses:
    - Always on `def` with parameters: `def rename_to(name)`.
    - Omit for DSL/macro and statement-style calls: `before_action :set_job_lead`, `validates :name, presence: true`, `redirect_to job_leads_path, success: "..."`, `raise Error, "..."`, `assert_includes tags, tag`.
    - Use them when the call is nested in another call's arguments, chained, or used in a condition or ternary: `tag.span(quote(rating_text), class: "...")`, `input.is_a?(Hash)`.
    - Use them for multi-line argument lists: `link_to(` … `)`.
- Models are organized under section comments (`# Constants`, `# Associations`, `# Normalizations`, `# Validations`, `# Callbacks`); use `normalizes`, scopes, and frozen documented constants as `JobLead` does. User concerns live in `app/models/concerns/user/`.
- Controllers: RESTful with `# GET /job_leads/1` style action comments, custom member actions where needed, `rate_limit` on expensive endpoints. Flash types: `:success`, `:error`.
- Views: conditional classes with `class_names(...)` in ERB; inside Rails tag helpers pass an array (`class: [ "base", "active": active? ]`) instead. Reuse partials in `app/views/shared/` and `app/views/components/`; icons via `icon` (which internally uses `inline_svg`).
- Tailwind: tokens live in the `@theme` block of `app/assets/tailwind/application.css` (`primary-*` scale, `neutral-925`). Use them instead of raw colors. Tailwind only sees literal class names — don't build class names dynamically.
- Layout classes go on `<body>`, not `<html>`, so they survive Turbo visits.
- Stimulus: `snake_case_controller.js`, header comment `// Connects to data-controller="..."`, `static targets`/`static classes`. JS uses **single quotes and semicolons**.
- Comments explain why, never what. Fail loudly: rescue only specific error classes.
- Keep temporary scripts, notes and screenshots out of the repo.

## Git & commits

- Small imperative commits with capitalized descriptive titles, no prefixes, no trailing period, each a working state: "Add CSV import for job leads".
- Wrap code references in backticks: "Remove obsolete `brakeman.ignore` entry".
