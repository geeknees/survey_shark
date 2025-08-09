# Refactoring Plan Update (2025-08)

This document summarizes the delta from prior proposals based on the current codebase.

Key observations
- JS services and mixins already exist (chat_event_manager, form_validator, LoadingStateMixin). Update plan items to mark them done and focus on adoption.
- hello_controller.js is unused; remove it and add a check in CI to prevent reintroduction.
- Tone definitions are inconsistent between Project validations and PromptBuilder. Unify via a single constant and mapping.
- Orchestrator remains too large; proceed with StateMachine/ResponseGenerator/TurnManager extraction.
- Token generation is fragmented; centralize in Security::TokenGenerator and replace call sites.
- Conversation model lacks helpful query/limit methods; add concerns.

Proposed Sprint Breakdown
- Sprint 1
  1. Remove hello_controller.js and update controllers index (confirm no references) – add eslint rule or grep check in CI.
  2. Introduce Security::TokenGenerator; wire invite token + anon hash; tests.
  3. Tone constants: Project::TONES and PromptBuilder mapping; add validation tests.
  4. UI feedback guideline: avoid className full replacement; audit and fix occurrences (copy button done); add linter/grep rule to flag `.className =` in controllers.
  5. Apply LoadingStateMixin to chat_composer and others; add thin tests.
- Sprint 2
  6. Extract Interview::StateMachine, ResponseGenerator, TurnManager; reduce orchestrator.
  7. Conversation concerns: conversation_state_machine.rb, conversation_progress.rb (remaining_turns, at_turn_limit?, should_finish?).
  8. Adopt chat_event_manager/form_validator across controllers; remove duplication.

Acceptance checklist
- All tests green; new unit tests for token generator, tone mapping, conversation concerns.
- grep shows no hello_controller.js; no `.className =` in controllers (except allowed places).
- Orchestrator reduced by >40% LOC; responsibilities isolated.
- Invite link copy UX animated and accessible.
