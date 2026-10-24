# Nexus AI Ecosystem (Initial Draft)

> This document describes a future product vision and phased roadmap. It does not add requirements to v1.0 by itself. The normative v1.0 product boundary, required outcomes, exclusions, and release criteria are defined in [Nexus v1.0 Scope](v1.0-scope.md).

This repository contains multiple apps. For v1.0, the iOS app is the participant-facing product and the primary delivery surface for the "Nexus AI Ecosystem" experience. The `web/` app is a public site for announcing the iOS app, development status, server status, and technical write-ups (decided 2026-10-25, part of v1.0); it does not provide participant app features.

The decision history for the iOS-only participant experience is recorded in [Work item #7](https://github.com/m0o9l0v3/NexusMobile/issues/7). The public site, including its pages, data sources, hosting, and QR behavior, is tracked in [GitHub Issue #131](https://github.com/m0o9l0v3/NexusMobile/issues/131), which replaced the earlier landing-page item #81.

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

The prototype support UI and knowledge packs that lived under `web/` were removed on 2026-10-25 together with the old PWA; they remain in git history. They are not v1.0 features.

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

