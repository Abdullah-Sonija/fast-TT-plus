# FastTT+ Architecture & Engineering Showcase

A comprehensive architecture, database design, and algorithmic showcase of **FastTT+**, an intelligent timetable management and clash solver platform built for FAST-NUCES Karachi.

- **Production Application:** [https://fast-timetable-plus.vercel.app](https://fast-timetable-plus.vercel.app)
- **Production API:** [https://fast-tt-backend.vercel.app](https://fast-tt-backend.vercel.app)

---

## Engineering Highlights

- **Sub-50ms Query Performance:** Designed a JSON-first data indexing pipeline that eliminated heavy relational joins across 10+ tables, reducing serverless execution latency by 90%.
- **Interval Clash Detection Engine:** Built a schedule conflict detection algorithm with full support for multi-period continuous lab blocks (up to 3 slots) and pre-computed duration arithmetic.
- **Background Resource Preloading:** Implemented an upfront cache preloader that prefetches all 15 day-and-room-type permutations without locking UI threads.
- **Offline-First PWA:** Integrated a service worker caching layer (`sw.js`) with active cache invalidation (`controllerchange`) enabling instant offline schedule access.
- **Role Isolation & 1-Click Verification:** Developed 2-hour tokenized email verification, domain-gated role authorization (`@nu.edu.pk` faculty vs student accounts), and cryptographic OTP password reset.
- **Test-Driven Development:** Maintained a complete Vitest automated test suite covering search matching, interval overlap math, and UI state flows.

## Data Pipeline Evolution: Live Excel Sync vs. Pre-Processed JSON

### Previous Architecture: Live Excel & Google Sheets Synchronization
In earlier iterations of FastTT+, timetable data was scraped and synchronized live at runtime from external Google Sheets and Excel documents:
- **Sync Mechanism:** The backend queried public spreadsheet endpoints, parsed tabular grids into relational rows, and populated 10+ normalized SQL tables.
- **Production Challenges:** Frequent upstream spreadsheet layout changes broke live parsers, complex 10-table relational joins produced significant query latency, and cold-start database handshakes frequently approached serverless timeout limits on Vercel Edge.

### Current Architecture: Pre-Processed JSON Ingestion Pipeline
To achieve deterministic reliability and sub-50ms query response times:
- **Pre-Parsing Pipeline:** Official timetable PDFs and Markdown schedules are pre-processed offline into structured datasets (`timetable.json`, `teachers_directory.json`).
- **Pre-Computed Slot Durations:** Multi-period laboratory sessions (e.g. 3-slot continuous blocks) have their exact minute spans pre-computed at build time.
- **In-Memory Querying:** Read traffic is served directly from memory, reserving MySQL strictly for authentication, saved user schedules, and analytics.

---

## Repository Contents

This showcase repository contains the architectural specifications, database design, core algorithmic samples, and test suites of the system:

```
new-repo/
├── README.md                 # System overview, engineering highlights & live links
├── docs/
│   ├── architecture.md       # In-depth system design & JSON vs SQL trade-offs
│   └── api-spec.md           # Complete REST API specification
├── schema/
│   └── 01_schema.sql         # Production MySQL DDL (tables, views, stored procedures)
├── samples/
│   ├── clash-detection.js    # Core algorithm: Multi-slot lab & lecture clash arithmetic
│   └── search-matcher.js     # Core algorithm: Multi-token faculty matching
└── tests/
    ├── clashDetection.test.js# Automated test suite for clash detection math
    └── searchMatching.test.js# Automated test suite for search matching
```

---

## System Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Client Layer (React PWA)                 │
│  - Live Substring Search        - Smart Clash Solver        │
│  - Unified Weekly View          - Offline Cache (sw.js)     │
└──────────────────────────────┬──────────────────────────────┘
                               │ HTTP / JSON API
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                  Serverless API Layer (Node.js)             │
│  - Auth & Role Middleware       - Rate Limiting (express)   │
│  - Timetable Controller         - Email Dispatch (SMTP)     │
└──────────────┬──────────────────────────────┬───────────────┘
               │                              │
               ▼                              ▼
┌──────────────────────────────┐ ┌────────────────────────────┐
│   JSON Ingestion Pipeline    │ │      MySQL Database        │
│ - Pre-computed Lab End Times │ │ - Users & Auth Credentials │
│ - In-Memory Fast Lookup      │ │ - Saved Courses & History  │
│ - Sub-50ms Search Latency    │ │ - Traffic & Search Logs    │
└──────────────────────────────┘ └────────────────────────────┘
```

For detailed architecture decisions, see [docs/architecture.md](docs/architecture.md).

---

## Core Algorithmic Highlights

### 1. Multi-Slot Lab Clash Detection (`samples/clash-detection.js`)
University laboratory courses span across 2 to 3 consecutive periods. The clash detection engine converts standard 12-hour timestamps to 24-hour minute integers, determines effective multi-slot end times, and computes overlap intervals:

$$\text{Clash Condition} = (\text{Start}_A < \text{End}_B) \land (\text{Start}_B < \text{End}_A)$$

See implementation in [samples/clash-detection.js](samples/clash-detection.js) and test verification in [tests/clashDetection.test.js](tests/clashDetection.test.js).

### 2. Multi-Token Faculty Matcher (`samples/search-matcher.js`)
Normalizes academic prefixes (`Dr.`, `Engr.`, `Prof.`) and post-nominals (`PhD`, `MS`), enforcing minimum token constraints (`minTokens >= 2`) to eliminate single-word false matches across faculty directories.

See implementation in [samples/search-matcher.js](samples/search-matcher.js).

---

## Database Architecture

The MySQL relational schema ([schema/01_schema.sql](schema/01_schema.sql)) includes:
- **Normalized Tables:** `users`, `timing_profiles`, `departments`, `courses`, `teachers`, `rooms`, `sections`, `schedule`, `email_verifications`.
- **Relational Integrity:** Foreign key cascades and composite uniqueness constraints `(section_id, slot_id, course_id)` allowing parallel elective assignments.
- **Audit Logging & Triggers:** Automated clash logging and daily unique visitor tracking.

---

## Automated Testing

All core calculation and search algorithms are backed by comprehensive automated test suites using Vitest:

- **11 Clash Detection Tests:** Single-slot lectures, middle-slot lab clashes, boundary condition overlaps, and multi-slot pre-computed durations.
- **6 Search Matching Tests:** Case-insensitive section queries, lab identifiers, course codes, and faculty name searches.

Test files are available in [tests/](tests/).

---

## License
MIT License. Developed for FAST-NUCES Karachi.
