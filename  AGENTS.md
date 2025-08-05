# Contributor Guide

## Dev Environment Tips
- Use `bin/dev` to start the development server (Foreman + Procfile.dev)
- Run `bundle install` to install Ruby dependencies after pulling changes
- Use `bin/rails generate` to create new controllers, models, or other Rails components
- Check `Gemfile` for project dependencies and their versions
- Use `bin/rails console` for interactive debugging and testing
- Database operations: `bin/rails db:migrate`, `bin/rails db:seed`, `bin/rails db:reset`
- Background jobs are handled by Solid Queue (no separate Redis/Sidekiq setup needed)
- View system architecture: See `docs/system_architecture.md` for detailed overview

## Testing Instructions
- Find the CI plan in the `.github/workflows/ci.yml` file
- Run `bin/rails test` to execute all unit tests
- Run `bin/rails test:system` to execute system/integration tests
- Run `bin/rails db:test:prepare` to prepare the test database
- To focus on specific tests, use: `bin/rails test test/models/project_test.rb`
- Test specific service objects: `bin/rails test test/services/interview/orchestrator_test.rb`
- Security scanning: `bin/brakeman --no-pager` for Rails vulnerabilities
- JavaScript dependency audit: `bin/importmap audit`
- Code style: `bin/rubocop -f github` for consistent Ruby styling
- Fix any test or lint errors until the whole suite passes
- Add or update tests for the code you change, even if nobody asked

### Test Structure
- Unit tests in `test/models/`, `test/services/`, `test/jobs/`
- Integration tests in `test/controllers/`, `test/integration/`
- System tests in `test/system/`
- Test fixtures and helpers in `test/fixtures/`, `test/support/`

## Documentation Guidelines
- Create or update documentation in the `docs/` directory when implementing new features
- Use descriptive Markdown filenames (e.g., `email_notification_system.md`, `api_integration_guide.md`)
- Include implementation details, usage examples, and troubleshooting tips
- Document API endpoints, configuration options, and architectural decisions
- Update existing docs when changing functionality they describe
- Reference related docs in code comments when appropriate

### Available Documentation
- `docs/system_architecture.md` - Complete system architecture overview
- `docs/refactoring_proposals.md` - Code improvement recommendations
- `docs/spec.md` - Technical specifications
- `docs/DEPLOYMENT.md` - Deployment instructions
- `docs/prompt_plan.md` - Development planning document

## Project Structure
- **Rails 8.0.2** application with Hotwire (Turbo + Stimulus)
- **Ruby 3.4.5** runtime environment
- **SQLite** database for development and testing
- **OpenAI integration** for AI-powered interview conversations
- **Tailwind CSS** for responsive styling
- **Importmap** for JavaScript module management (no Node.js build step required)
- **Solid Queue/Cache/Cable** for background jobs, caching, and real-time features
- **Kamal** for containerized deployment

### Key Components
- **Interview System**: AI-driven conversation orchestration with state management
- **Project Management**: Admin interface for creating and managing interview projects
- **Analysis Pipeline**: Automated conversation analysis and insight extraction
- **Participant Experience**: Public interface for interview participation via invite links

## Development Workflow
1. Create a new branch with an English name: `git checkout -b feature/your-feature-name` (avoid Japanese words in branch names)
2. Make your changes and add tests
3. Document new features or changes in `docs/` directory if needed
4. Run the full test suite: `bin/rails test test:system`
5. Check code quality: `bin/rubocop` and `bin/brakeman`
6. Commit and push your changes
7. Create a pull request - CI will run automatically

## Environment Setup
- Ruby version 3.4.5 is specified in `.ruby-version`
- Required system packages: build-essential, git, libyaml-dev, pkg-config
- For system tests: Google Chrome is required
- Environment variables: Check `.env.example` if available
- OpenAI API key required for LLM integration (set OPENAI_API_KEY environment variable)

## Test-Driven Development (TDD)

- Follow test-driven development (TDD) as a guiding principle.
- Create tests first based on expected inputs and outputs.
- Do not write implementation code yet; only write tests.
- Run the tests and confirm that they fail.
- Commit once you are confident the tests are correct.
- Next, implement code to make the tests pass.
- While implementing, keep the tests unchanged and adjust the code instead.
- Repeat until all tests pass.

## Project-Specific Guidelines

### Interview System Development
- LLM interactions should always have fallback mechanisms
- Use fake LLM clients in tests for deterministic behavior
- Follow the state machine pattern for conversation management
- Document prompt engineering decisions in code comments

### Service Objects
- Follow single responsibility principle for service classes
- Place business logic in services, not controllers or models
- Use the `call` method pattern for service objects
- Test services independently with mock dependencies

### Background Jobs
- Use Solid Queue for async processing (analysis, notifications)
- Jobs should be idempotent and handle failures gracefully
- Test jobs with job adapters in test environment
- Monitor job performance and failures in production

### Security Considerations
- Validate all user inputs, especially for LLM prompts
- Use anonymous participant identification (anon_hash)
- Implement rate limiting for public endpoints
- Regular security scanning with Brakeman

