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

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd sync
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
