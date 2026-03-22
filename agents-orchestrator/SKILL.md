---
name: agents-orchestrator
description: Full multi-agent orchestration with UI/UX Pro MAX design-system generation and planning-first execution. Use when a task is complex, spans multiple domains (frontend, backend, database, security, testing, mobile, DevOps, SEO, performance), or involves UI/UX design work. Triggers on "build", "create", "implement", "design", "refactor", "review", "orchestrate", or any multi-domain request.
version: 1.0.0
skills: plan-writing, intelligent-routing, frontend-design, parallel-agents, behavioral-modes
---

# Agents Orchestrator

> **Learned from:** `cursor/rules/GEMINI.md` · `cursor/workflows/orchestrate.md` · `cursor/workflows/ui-ux-pro-max.md` · `cursor/skills/plan-writing/SKILL.md` · `cursor/skills/frontend-design/SKILL.md` · `cursor/skills/intelligent-routing/SKILL.md`

---

## Quick Navigation

- [Step 0 – Pre-flight & Clarification](#-step-0--pre-flight--clarification)
- [Step 1 – Request Classification](#-step-1--request-classification)
- [Step 2 – Planning-First Gate](#-step-2--planning-first-gate)
- [Step 3 – UI/UX Pro MAX (design tasks)](#-step-3--uiux-pro-max-design-tasks-only)
- [Step 4 – Agent Selection Matrix](#-step-4--agent-selection-matrix)
- [Step 5 – Orchestration Protocol](#-step-5--orchestration-protocol)
- [Step 6 – Synthesis Report](#-step-6--synthesis-report)
- [Agent Roster & Boundaries](#-agent-roster--boundaries)
- [Exit Gate](#-exit-gate)

---

## 🔴 STEP 0 – Pre-flight & Clarification

Before ANY agent is invoked:

### 0a. Read existing context

```
Read {task-slug}.md (project root) if it exists.
Read design-system/MASTER.md if it exists.
```

If a plan file already exists and user approved it → skip to [Step 4](#-step-4--agent-selection-matrix).

### 0b. Socratic Gate (mandatory for vague requests)

If the request is open-ended or missing key information, ask at most 3 focused questions before proceeding. Required answers:

| Unknown | Ask |
|---------|-----|
| **Scope** | "Full app / specific module / single file?" |
| **Stack** | "Which tech stack? (Flutter/React/Next.js/Node/other?)" |
| **Design style** | "Preferred visual style? (minimal/bold/elegant/other — or should I decide?)" |
| **Priority** | "What matters most? (speed / security / features / design?)" |

> **Do NOT over-ask.** If the request is reasonably clear, start working.

---

## 🔍 STEP 1 – Request Classification

Silently classify the request before responding:

| Type | Keywords | Tiers Active | Output |
|------|----------|-------------|--------|
| **Question** | "what is", "how does", "explain" | TIER 0 only | Text reply |
| **Survey / intel** | "analyze", "list files", "overview" | TIER 0 + explorer-agent | Session intel |
| **Simple code** | "fix", "add", "change" (single file) | TIER 0 + 1 agent | Inline edit |
| **Complex code** | "build", "create", "implement", "refactor" | Full orchestration | `{task-slug}.md` required |
| **Design / UI** | "design", "UI", "screen", "dashboard" | Full orchestration + UI/UX Pro MAX | `{task-slug}.md` required |
| **Multi-domain** | 2+ domain keywords detected | Full orchestration | `{task-slug}.md` required |

For **Simple code** tasks → invoke a single matching agent directly, no plan file needed.
For **Complex / Design / Multi-domain** → continue from Step 2.

---

## 📝 STEP 2 – Planning-First Gate

> Source rules: [`cursor/skills/plan-writing/SKILL.md`](../plan-writing/SKILL.md)

### When a plan is required

A plan is required for: complex code, design/UI, multi-domain, and any task touching 3+ files.

### Plan file rules

| Rule | Detail |
|------|--------|
| **Location** | Project ROOT (not `docs/`, not `.cursor/`) |
| **Naming** | `{task-slug}.md` — 2-3 keywords, lowercase, hyphen-separated. E.g. "add login" → `login-feature.md` |
| **Length** | Max 1 page. If longer, split into separate plans |
| **Tasks** | 5-10 tasks max. Each task: specific action + verifiable outcome |

### Minimal plan structure

```
# {Task Name}

## Goal
One sentence: what are we building/fixing?

## Tasks
- [ ] Task 1: {specific action} → Verify: {how to check}
- [ ] Task 2: {specific action} → Verify: {how to check}
...

## Done When
- [ ] {main success criterion}
```

### Approval checkpoint

After the plan is created, ask:

```
Plan created: {task-slug}.md

Approve to start implementation? (Y to proceed / N to revise)
```

> Do NOT invoke specialist agents until the user approves the plan.

---

## 🎨 STEP 3 – UI/UX Pro MAX (design tasks only)

> Source rules: [`cursor/workflows/ui-ux-pro-max.md`](../../workflows/ui-ux-pro-max.md) · [`cursor/skills/frontend-design/SKILL.md`](../frontend-design/SKILL.md)

**Activate this step only when the task involves UI, screens, dashboards, landing pages, or any visual design work.**

### 3a. Check Python

```bash
python3 --version || python --version
# Windows:
python --version
```

### 3b. Generate design system (always run first)

```bash
python3 cursor/shared/ui-ux-pro-max/scripts/search.py "<product_type> <industry> <keywords>" --design-system -p "<Project Name>"
```

This returns: UI style, color palette, typography, layout pattern, effects, and anti-patterns.

**Stack default:** `html-tailwind` if user does not specify. Available stacks: `html-tailwind`, `react`, `nextjs`, `vue`, `svelte`, `flutter`, `react-native`, `shadcn`, `swiftui`, `jetpack-compose`.

### 3c. Persist for multi-session projects

```bash
python3 cursor/shared/ui-ux-pro-max/scripts/search.py "<query>" --design-system --persist -p "<Project Name>"
# Per-page override:
python3 cursor/shared/ui-ux-pro-max/scripts/search.py "<query>" --design-system --persist -p "<Project Name>" --page "<page-name>"
```

Creates `design-system/MASTER.md` and `design-system/pages/<page>.md`.

### 3d. Supplement searches (as needed)

```bash
python3 cursor/shared/ui-ux-pro-max/scripts/search.py "<keyword>" --domain <domain>
# Available domains: product, style, typography, color, landing, chart, ux, react, web, prompt
python3 cursor/shared/ui-ux-pro-max/scripts/search.py "<keyword>" --stack <stack>
```

### 3e. Design constraints from frontend-design skill

Before implementing any UI, apply the following from [`cursor/skills/frontend-design/SKILL.md`](../frontend-design/SKILL.md):

- **Ask about constraints first**: timeline, brand, tech stack, audience — if not specified
- **60-30-10 color rule**: 60% background / 30% secondary / 10% accent
- **8-point grid**: all spacing in multiples of 8px
- **Typography pairing**: contrast + harmony; 45-75 char line length for body
- **Avoid AI default tendencies**: no mesh gradients, no purple-everything, no bento grids by default, no Vercel-clone layouts
- **Emotional design**: visceral → behavioral → reflective

### 3f. Merge into plan

Add a `## Design System` section to the plan file before implementation begins.

---

## 🤖 STEP 4 – Agent Selection Matrix

> Source rules: [`cursor/skills/intelligent-routing/SKILL.md`](../intelligent-routing/SKILL.md)

Silently detect all domains in the request, then select agents:

| Domain Detected | Primary Agent | Support Agent |
|-----------------|--------------|---------------|
| **UI/UX / Frontend** | `frontend-specialist` | `seo-specialist`, `performance-optimizer` |
| **Mobile screens** | `mobile-developer` | — |
| **Backend / API** | `backend-specialist` | `database-architect` |
| **Database / Schema** | `database-architect` | `backend-specialist` |
| **Security / Auth** | `security-auditor` | `penetration-tester` |
| **Testing** | `test-engineer` | `qa-automation-engineer` |
| **DevOps / Deploy** | `devops-engineer` | — |
| **Bug / Error** | `debugger` | `explorer-agent` |
| **Performance** | `performance-optimizer` | — |
| **SEO** | `seo-specialist` | — |
| **Planning** | `project-planner` | `explorer-agent` |
| **Documentation** | `documentation-writer` | — (only if explicitly requested) |
| **Game** | `game-developer` | — |
| **Multi-domain** | `orchestrator` → all relevant | minimum 3 agents |

**Routing rules:**
- Single domain, single file → 1 agent, no orchestration
- 2+ domains → minimum 3 agents (orchestration required)
- Mobile project → `mobile-developer` only, never `frontend-specialist`
- Web project → `frontend-specialist`, never `mobile-developer`

### Agent boundary enforcement

| Agent | CAN do | CANNOT do |
|-------|--------|-----------|
| `frontend-specialist` | Components, UI, styles, hooks | Test files, API routes, DB |
| `backend-specialist` | API, server logic, DB queries | UI components, styles |
| `test-engineer` | Test files, mocks, coverage | Production code |
| `mobile-developer` | RN/Flutter components, mobile UX | Web components |
| `database-architect` | Schema, migrations, queries | UI, API logic |
| `security-auditor` | Audit, vulnerabilities, auth review | Feature code, UI |
| `devops-engineer` | CI/CD, deployment, infra config | Application code |
| `documentation-writer` | Docs, README, comments | Code logic, auto-invoke without explicit request |
| `project-planner` | Plan file, task breakdown | Code files |
| `explorer-agent` | Codebase discovery | Write operations |

---

## ⚙️ STEP 5 – Orchestration Protocol

> Source rules: [`cursor/workflows/orchestrate.md`](../../workflows/orchestrate.md)

### Minimum agent requirement

> **ORCHESTRATION = MINIMUM 3 DIFFERENT AGENTS**
> Fewer than 3 agents = delegation, not orchestration.

### Two-phase execution

#### Phase 1 – Planning (sequential, no specialist agents yet)

| Step | Agent | Action |
|------|-------|--------|
| 1 | `project-planner` | Create `{task-slug}.md` in project root |
| 2 (optional) | `explorer-agent` | Codebase discovery if needed |

Stop after plan. Wait for user approval.

#### Phase 2 – Implementation (parallel after approval)

Invoke agents in logical order; independent agents can run in parallel:

| Wave | Agents |
|------|--------|
| Foundation | `database-architect`, `security-auditor` |
| Core | `backend-specialist`, `frontend-specialist` / `mobile-developer` |
| Polish | `test-engineer`, `devops-engineer` |

### Context passing (mandatory)

When invoking any sub-agent, always include:

```
CONTEXT:
- User Request: {full original request}
- Decisions Made: {all Socratic answers}
- Previous Agent Work: {summary of what prior agents did}
- Current Plan: {task-slug}.md contents
- Design System: design-system/MASTER.md (if UI task)
```

> Omitting context = agent will make wrong assumptions — this is a violation.

### Verification scripts

After all agents complete, the last agent must run:

```bash
python cursor/skills/vulnerability-scanner/scripts/security_scan.py .
python cursor/skills/lint-and-validate/scripts/lint_runner.py .
```

---

## 📊 STEP 6 – Synthesis Report

After all agents complete, produce:

```markdown
## 🎼 Orchestration Report

### Task
{original task summary}

### Plan File
{task-slug}.md

### Design System (if UI task)
design-system/MASTER.md

### Agents Invoked (minimum 3)
| # | Agent | Domain | Status |
|---|-------|--------|--------|
| 1 | project-planner | Planning | ✅ |
| 2 | frontend-specialist | UI/UX | ✅ |
| 3 | test-engineer | Testing | ✅ |

### Verification Scripts
- [x] security_scan.py → Pass/Fail
- [x] lint_runner.py → Pass/Fail

### Key Findings
1. **{Agent}**: {finding}
2. **{Agent}**: {finding}
3. **{Agent}**: {finding}

### Deliverables
- [ ] Plan file created and approved
- [ ] Code implemented
- [ ] Design system generated (if UI)
- [ ] Tests passing
- [ ] Scripts verified

### Summary
{One paragraph synthesis of all agent work}
```

---

## 📋 Agent Roster & Boundaries

Full list of available agents:

| Agent | Domain | Trigger Keywords |
|-------|--------|-----------------|
| `orchestrator` | Multi-agent coordination | "comprehensive", "multi-perspective" |
| `project-planner` | Planning, task breakdown | "plan", "roadmap", "milestones" |
| `explorer-agent` | Codebase discovery | "explore", "map", "structure" |
| `frontend-specialist` | Web UI/UX | "React", "UI", "components", "Next.js", "Tailwind" |
| `mobile-developer` | iOS, Android, RN, Flutter | "mobile", "screen", "Flutter", "React Native" |
| `backend-specialist` | API, server, business logic | "API", "server", "Node.js", "FastAPI", "Express" |
| `database-architect` | Schema, SQL, migrations | "schema", "Prisma", "migration", "SQL" |
| `security-auditor` | Security compliance | "security", "auth", "vulnerabilities", "OWASP" |
| `penetration-tester` | Offensive security | "pentest", "red team", "exploit" |
| `test-engineer` | Unit, E2E, coverage | "tests", "coverage", "TDD", "Jest", "Playwright" |
| `qa-automation-engineer` | E2E pipelines | "E2E", "automation", "CI testing" |
| `devops-engineer` | CI/CD, Docker, deployment | "deploy", "CI/CD", "Docker", "infrastructure" |
| `performance-optimizer` | Speed, Web Vitals | "slow", "optimize", "Lighthouse", "profiling" |
| `seo-specialist` | SEO, meta, rankings | "SEO", "meta tags", "search ranking" |
| `debugger` | Root cause analysis | "bug", "error", "not working", "crash" |
| `documentation-writer` | Docs, README | "write docs", "create README" (explicit only) |
| `code-archaeologist` | Legacy code, refactoring | "legacy", "refactor", "spaghetti code" |
| `game-developer` | Game logic, scenes | "game", "Unity", "Godot", "Phaser" |
| `product-manager` | Requirements, user stories | "requirements", "user story", "backlog" |
| `product-owner` | Strategy, backlog, MVP | "MVP", "strategy", "backlog" |

---

## 🚦 Exit Gate

Before marking orchestration complete, verify all:

| Check | Requirement | Action if failed |
|-------|------------|-----------------|
| **Plan exists** | `{task-slug}.md` in project root | Create it with project-planner |
| **Agent count** | `invoked_agents >= 3` | Invoke more agents |
| **Scripts ran** | `security_scan.py` + `lint_runner.py` | Run them |
| **Report generated** | Orchestration Report with all agents | Generate it |
| **Design system** | `design-system/MASTER.md` exists (UI tasks only) | Run UI/UX Pro MAX step |

> If any check fails, do not mark orchestration complete.

---

## Reference files

| File | Purpose |
|------|---------|
| [`cursor/rules/GEMINI.md`](../../rules/GEMINI.md) | Global workspace rules (P0 — highest priority) |
| [`cursor/workflows/orchestrate.md`](../../workflows/orchestrate.md) | Multi-agent workflow + 2-phase protocol |
| [`cursor/workflows/ui-ux-pro-max.md`](../../workflows/ui-ux-pro-max.md) | Design system generation workflow |
| [`cursor/skills/plan-writing/SKILL.md`](../plan-writing/SKILL.md) | Plan file rules, naming, structure |
| [`cursor/skills/frontend-design/SKILL.md`](../frontend-design/SKILL.md) | UI/UX principles, color, typography, animation |
| [`cursor/skills/intelligent-routing/SKILL.md`](../intelligent-routing/SKILL.md) | Domain detection + agent selection matrix |
| [`cursor/skills/parallel-agents/SKILL.md`](../parallel-agents/SKILL.md) | Multi-agent invocation patterns |
| [`cursor/agents/orchestrator.md`](../../agents/orchestrator.md) | Orchestrator agent persona |
| [`cursor/agents/project-planner.md`](../../agents/project-planner.md) | Project planner agent persona |
| [`cursor/shared/ui-ux-pro-max/`](../../shared/ui-ux-pro-max/) | UI/UX Pro MAX data + search scripts |
