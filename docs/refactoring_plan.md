# Survey Shark Refactoring Plan

## Goals
- Reduce coupling across interview flow, LLM prompts, and UI updates.
- Clarify state transitions and data ownership (conversation meta vs. project limits).
- Improve reliability of streaming and polling fallbacks.
- Make test coverage align with critical user paths.

## Scope Overview
- Interview pipeline: state machine, orchestrators, prompt builder, must-ask manager.
- UI updates: Turbo streams, polling refresh, completion CTA, progress header.
- Limits and counters: max_turns, max_deep, must_ask followups.
- Background jobs and error handling: streaming, fallback, analysis, PII.

## Priority Plan

### High Priority (next sprint)
1) Interview state and meta consolidation
   - Consolidate deepening and must-ask counters into a single meta schema.
   - Define a single source of truth for limits resolution (string vs. symbol keys).
   - Add a state migration strategy for existing conversations.

2) Streaming vs. non-streaming orchestration alignment
   - Extract shared behavior prompt assembly into a common helper.
   - Ensure completion broadcasts happen after all state updates in all paths.
   - Document the state transition contract used by both orchestrators.

3) Turn limit and completion logic
   - Centralize turn-limit exceptions (summary confirmation, must-ask overage).
   - Ensure UI and controller logic use the same allow/deny rules.

### Medium Priority (near-term)
4) Prompt and response layering
   - Separate system prompt policy from per-state behavior prompts.
   - Add a small templating layer for placeholders to avoid duplicate gsub logic.
   - Normalize prompt content to reflect actual state flow.

5) UI refresh and Turbo fallbacks
   - Expand poll responses to include all state-dependent UI (progress, completion).
   - Add a single DOM update entrypoint for fallback refreshes.

6) LLM client resiliency
   - Move retry and response truncation behaviors into shared mixins.
   - Standardize error mapping and logging format.

### Low Priority (backlog)
7) Service and model responsibilities
   - Split Project limits and status logic into concerns.
   - Move reporting and KPI logic out of controllers.

8) View and helper cleanup
   - Extract reusable partials for project and insights views.
   - Split helpers by domain boundaries.

9) Testing and tooling
   - Add reusable helpers for interview tests.
   - Add JS tests for Turbo/polling fallbacks and form reset flows.

## Risks and Mitigations
- Risk: state drift between streaming and non-streaming paths.
  - Mitigation: shared state transition helper, integration tests for both flows.
- Risk: limits not applied due to mixed key types.
  - Mitigation: single limit accessor used everywhere; add unit tests for both key types.
- Risk: UI not updated after async state changes.
  - Mitigation: broadcast after state updates; poll response includes completion and progress.

## Deliverables
- Refactoring checklist with owners and dependencies.
- A single interview flow contract doc (states, transitions, meta keys).
- Consolidated helper for limits and prompt assembly.

## Acceptance Criteria
- Deepening count respects max_deep across all flows.
- Must-ask exits after max followups and transitions to summary.
- UI reflects completion without page reload.
- Tests cover both streaming and non-streaming state transitions.
