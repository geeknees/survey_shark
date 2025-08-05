# Contributor Guide

## Dev Environment Tips
- Use `bin/dev` to start the development server (Foreman + Procfile.dev)
- Run `bundle install` to install Ruby dependencies after pulling changes
- Use `bin/rails generate` to create new controllers, models, or other Rails components
- Check `Gemfile` for project dependencies and their versions
- Use `bin/rails console` for interactive debugging and testing
- Database operations: `bin/rails db:migrate`, `bin/rails db:seed`, `bin/rails db:reset`

## Testing Instructions
- Find the CI plan in the `.github/workflows/ci.yml` file
- Run `bin/rails test` to execute all unit tests
- Run `bin/rails test:system` to execute system/integration tests
- Run `bin/rails db:test:prepare` to prepare the test database
- To focus on specific tests, use: `bin/rails test test/models/user_test.rb`
- Security scanning: `bin/brakeman --no-pager` for Rails vulnerabilities
- JavaScript dependency audit: `bin/importmap audit`
- Code style: `bin/rubocop -f github` for consistent Ruby styling
- Fix any test or lint errors until the whole suite passes
- Add or update tests for the code you change, even if nobody asked

## Documentation Guidelines
- Create or update documentation in the `docs/` directory when implementing new features
- Use descriptive Markdown filenames (e.g., `email_notification_system.md`, `api_integration_guide.md`)
- Include implementation details, usage examples, and troubleshooting tips
- Document API endpoints, configuration options, and architectural decisions
- Update existing docs when changing functionality they describe
- Reference related docs in code comments when appropriate

## Project Structure
- **Rails 8** application with Hotwire (Turbo + Stimulus)
- **SQLite** database for development and testing
- **OpenAI integration** for AI-powered feedback analysis
- **Tailwind CSS** for styling
- **Importmap** for JavaScript module management (no Node.js build step required)

## Development Workflow
1. Create a new branch with an English name: `git checkout -b feature/your-feature-name` (avoid Japanese words in branch names)
2. Make your changes and add tests
3. Document new features or changes in `docs/` directory if needed
4. Run the full test suite: `bin/rails test test:system`
5. Check code quality: `bin/rubocop` and `bin/brakeman`
6. Commit and push your changes
7. Create a pull request - CI will run automatically

## Environment Setup
- Ruby version is specified in `.ruby-version`
- Required system packages: build-essential, git, libyaml-dev, pkg-config
- For system tests: Google Chrome is required
- Environment variables: Check `.env.example` if available

## Test-Driven Development (TDD)

- Follow test-driven development (TDD) as a guiding principle.
- Create tests first based on expected inputs and outputs.
- Do not write implementation code yet; only write tests.
- Run the tests and confirm that they fail.
- Commit once you are confident the tests are correct.
- Next, implement code to make the tests pass.
- While implementing, keep the tests unchanged and adjust the code instead.
- Repeat until all tests pass.

