# HPG-PWB Integration Documentation

This folder contains research, analysis, and implementation plans for integrating HousePriceGuess (HPG) as an external frontend powered by PWB's backend API.

## Documents

| # | Document | Description |
|---|----------|-------------|
| 01 | [Codebase Research](01_CODEBASE_RESEARCH.md) | Detailed analysis of existing PWB patterns and reference files |
| 02 | [Data Model Design](02_DATA_MODEL_DESIGN.md) | New tables, models, and their relationships |
| 03 | [API Design](03_API_DESIGN.md) | Endpoint specifications, request/response shapes, caching strategy |
| 04 | [Implementation Plan](04_IMPLEMENTATION_PLAN.md) | Phase-by-phase build order, file inventory, and verification steps |
| 05 | [Design Decisions](05_DESIGN_DECISIONS.md) | Key architectural choices and their rationale |

## Context

- **HPG** is being rebuilt as an Astro.js + React frontend
- It currently calls a legacy backend at `hpg-scoot.homestocompare.com` using `/api_public/v4/` paths
- None of those endpoints exist in PWB yet
- PWB already has: multi-tenancy, `api_public/v1` namespace, a simple price game feature, and SPP integration as a reference pattern
- **Goal:** Build the game engine API in PWB under `api_public/v1/hpg/` so the HPG frontend can use PWB as its backend

## Date

2026-02-12
