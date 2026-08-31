# Nexus AI Ecosystem (Initial Draft)

This repository contains multiple apps. For v1.0, the iOS app is the participant-facing product and the primary delivery surface for the "Nexus AI Ecosystem" experience. The `web/` app is being restructured as an event landing page for discovery, same-day information, and guidance to the iOS app.

The product boundary is recorded in [Work item #7](https://gitlab.com/11h27m/nexus-mobile/-/work_items/7). The landing-page implementation, including its public routes, API usage, and QR behavior, is tracked in [Work item #81](https://gitlab.com/11h27m/nexus-mobile/-/work_items/81).

The goal is not to build a single feature, but to establish a reusable, safety-aware, operations-friendly foundation for agent-like copilots that can act as a user's "right arm" across domains.

## North Star

- A copilot-style agent that supports real work with:
  - clear capabilities (tools/actions)
  - reliable knowledge (source-controlled, versioned)
  - safe behavior (policy + human handoff)
  - measurable quality (logs + eval)

## Principles (Early-Stage Constraints)

- Template-first, rule-first:
  - Prefer fixed templates and deterministic flows for correctness and operational cost.
  - Use generation only for minor tone adjustments / summarization, not for facts.
- Knowledge is data, not training:
  - Update by replacing knowledge packs (JSON/CSV), not by re-training.
  - Keep each pack versioned and deployable independently.
- Never "complete" the experience with AI alone:
  - Provide a short overview and a clear next step (visit the exhibit / ask staff).
  - For incidents, always provide a fast escalation path.
- Offline-friendly and privacy-aware:
  - Minimize personally identifiable data.
  - Prefer on-device state and explicit consent for any sensitive signal.

## Ecosystem Layers

### 1) UX Layer

- A single "Support" entrypoint (chat-like UI) available from the participant-facing iOS experience.
- Supports:
  - Exhibit Q&A (overview + where to go + what to ask onsite)
  - Troubleshooting (guided decision tree + escalation)

The existing support UI and knowledge packs under `web/` are prototype assets and possible reuse sources. They are not committed landing-page features; reuse is decided within Work item #81.

### 2) Orchestration Layer

- An "intent router" that maps user actions to:
  - a template response
  - a set of app actions (open map, select spot, apply filters, show handoff UI)
- Deterministic by default.
- LLM integration is optional and must be behind a strict contract (e.g., "tone rewrite only").

### 3) Knowledge Packs

- Source-controlled, versioned, replaceable datasets:
  - `exhibits.v1.json`: exhibit overview + onsite prompts + map linkage
  - `troubles.v1.json`: safe decision trees + escalation triggers
- Each pack must include:
  - `version`, `updatedAt`, `owner` (ops contact), `source` (doc/link id)

### 4) Tool/Action Interface

- A small set of app-native actions that the agent can trigger:
  - `openMap`
  - `selectSpot(spotId)`
  - `startSupportPickMode`
  - `requestHandoff(reason, urgency)`

### 5) Human Handoff

- Always visible and one-tap reachable.
- Handoff modes can evolve:
  - Phase 0: guidance to nearby staff /受付 + "map jump"
  - Phase 1: internal chat to operators (admin console)
  - Phase 2: ticketing / incident workflow integration

### 6) Observability & Evaluation

- Minimal event logs:
  - intent selected
  - flow node transitions
  - handoff requested
  - knowledge pack versions used
- Evaluation harness (later):
  - scripted test prompts
  - expected intent + required safety behavior

## Phased Roadmap (Suggested)

### Phase 0 (Now): iOS "Experience Support AI"

- Exhibit Q&A:
  - select exhibit by name or map tap
  - show overview only + encourage onsite questions
- Troubleshooting:
  - guided branching for:
    - device issues
    - lost / cannot find location
    - health concerns
  - immediate escalation button
- No model retraining. Knowledge packs are swapped.

### Phase 1: Operator Console + Knowledge Ops

- Admin UI for updating packs (or importing CSV).
- Operator chat/handoff channel.
- Metrics dashboard for top questions and unresolved intents.

### Phase 2: Multi-Workflow Copilot

- Connect to more tools:
  - schedules, reservations, announcements, incident triage
- Approval gates for any impactful action.

### Phase 3: Agentic Automation With Guardrails

- Multi-step workflows with:
  - plans
  - human approval points
  - audit logs
  - rollback strategies

