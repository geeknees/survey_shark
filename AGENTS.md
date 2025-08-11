# Repository Guidelines

## Project Structure & Module Organization
- `app/`: Rails code — models, controllers, views, jobs, mailers.
- `app/services/`: Domain services (`interview/`, `llm/`, `pii/`, `security/`, `analysis/`).
- `app/javascript/`: Stimulus controllers and JS services.
- `config/`, `db/`, `public/`, `lib/`: Standard Rails folders.
- `test/`: Minitest suites (models/controllers/services/system, etc.).
- `docs/`: Specs, architecture, deployment, refactoring notes.

## Build, Test, and Development Commands
- Run dev server: `bin/dev` (Rails + CSS/JS build).
- Setup DB: `bin/rails db:setup` (create, migrate, seed).
- Run tests: `bin/rails test` (all), or `bin/rails test:system`.
- Coverage: `COVERAGE=true bin/rails test`.
- Static analysis: `bundle exec brakeman`; lint: `bundle exec rubocop`.
- Deploy (Kamal): `kamal setup && kamal deploy` (see `docs/DEPLOYMENT.md`).

## Coding Style & Naming Conventions
- Ruby/ERB: 2-space indent; files `snake_case.rb`; classes `CamelCase`.
- Stimulus: `app/javascript/controllers/*_controller.js`; services in `app/javascript/services/`.
- Prefer service objects for orchestration; keep controllers thin.
- Linting: RuboCop (Rails Omakase). Fix offenses before PRs.

## Testing Guidelines
- Framework: Minitest (+ Capybara for system tests).
- Place tests in matching `test/<type>/` paths; name files like `thing_test.rb`.
- Write unit tests for services and models; add system tests for critical flows (invite → chat → finish).

## Commit & Pull Request Guidelines
- Commits: short imperative subject, focused changes, reference issues (e.g., `Fix chat skip button (#123)`).
- PRs: clear description, screenshots for UI changes, test coverage for new logic, and notes on risks/rollbacks.
- Keep PRs small and reviewable; update docs (`docs/`) when behavior or ops change.

## Security & Configuration Tips
- Secrets via env: `OPENAI_API_KEY`, `RAILS_MASTER_KEY`. Do not commit .env files.
- PII: rely on `PII::Detector`; avoid logging raw user content. Use masked values in logs.
