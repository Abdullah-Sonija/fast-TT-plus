# System Architecture & Technical Design

This document details the architectural decisions, data flow models, and optimization strategies employed in **FastTT+**.

---

## 1. Architectural Problem & Strategic Shift

### Legacy Architecture: Runtime Relational Joins & Live Scraping
In the initial design, every search query executed relational SQL joins across 10 normalized tables (`schedule`, `courses`, `teachers`, `rooms`, `sections`, `departments`, `slots`, etc.), coupled with periodic live scraping from upstream spreadsheets.

**Bottlenecks identified in production:**
- **Relational Overhead:** Joining 10+ tables for simple substring queries created CPU spikes during semester registration surges.
- **Serverless Edge Timeouts:** Remote MySQL connection handshakes and query execution occasionally approached Vercel's 10-second serverless execution limits.
- **Upstream Layout Fragility:** Live scraping broke whenever upstream administrators formatted columns or renamed headers.

---

### Modern Architecture: JSON-First Ingestion Pipeline
To decouple timetable searching from database I/O, the read pathway was separated from the write/auth pathway:

```
┌────────────────────────────────────────────────────────┐
│               1. Offline Ingestion Pipeline             │
│  Raw PDF / Markdown ──► Parser Script ──► timetable.json│
└────────────────────────────────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────┐
│               2. Serverless Read Path (Fast)           │
│  Client Request ──► In-Memory JSON Filter (sub-50ms)   │
└────────────────────────────────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────┐
│               3. Database Write Path (Secure)          │
│  User Auth, Saved Schedules & Analytics ──► MySQL (SSL)│
└────────────────────────────────────────────────────────┘
```

**Key Advantages:**
1. **Sub-50ms Query Latency:** Timetable lookups are resolved in-memory with zero SQL join latency.
2. **Deterministic Data Contracts:** Data schema is validated during build/ingestion time.
3. **High Concurrency Resilience:** Millions of read requests can be served without database connection pool exhaustion.

---

## 2. Progressive Web App (PWA) & Offline Strategy

The client-side PWA architecture ensures students can view their schedules even inside campus basements with intermittent connectivity:

```
[Browser Request] ──► [Service Worker (sw.js)]
                            │
              ┌─────────────┴─────────────┐
              ▼                           ▼
        [Static Cache]              [Dynamic API Cache]
        (HTML, CSS, JS)             (Timetable Queries)
              │                           │
              └─────────────┬─────────────┘
                            ▼
                     [Render UI Instantly]
```

### Cache Management & Cache-Busting
- **Static Assets:** Cached on install using a versioned static cache identifier (`fast-tt-v65-static`).
- **Dynamic API Responses:** Successful GET requests to `/api/timetable/*` are cached on the fly with network-first fallback.
- **Automated Client Invalidation:** When a new service worker version is deployed, the client listens to the `controllerchange` event and reloads the window automatically to eliminate stale code.

---

## 3. Background Preloading Optimization

Classroom availability lookups require querying 15 permutations (5 days $\times$ 3 room types: Classrooms, Labs, All). 

Rather than fetching on user click (which causes layout shifts and loading spinners):
1. Upon initial page load, a non-blocking background preloader runs asynchronously.
2. All 15 permutations are prefetched and stored in an in-memory application cache.
3. Subsequent tab switches between days or room types execute with **0ms latency**.

---

## 4. Multi-Slot Time Overlap Algorithm

Laboratories at FAST-NUCES span 3 continuous 50-minute periods (e.g. 08:00 AM – 10:40 AM).

To compute clashes accurately without runtime string parsing overhead:
1. All start times $T_{start}$ and end times $T_{end}$ are normalized to minutes from midnight ($M = \text{hours} \times 60 + \text{minutes}$).
2. Two class sessions $A$ and $B$ on the same day clash if and only if:

$$\text{Clash}(A, B) = (A_{start} < B_{end}) \land (B_{start} < A_{end})$$

3. Self-conflicts (same course and same section across consecutive slots) are excluded to allow continuous lab tracking.
