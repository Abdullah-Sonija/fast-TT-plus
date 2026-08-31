The technology stack used in **FAST TT+**:

### 1. **Frontend**
| Technology | Purpose |
| :--- | :--- |
| **React 18** | UI library for component-based reactive interface |
| **Vite 5** | Next-generation frontend build tool and development server |
| **React Router v6** | Client-side routing and page navigation |
| **Axios** | HTTP client for interacting with backend REST APIs |
| **Vanilla CSS3** | Custom design system with glassmorphism, responsive flex/grid layouts, animations, and dark mode |
| **React Helmet Async** | Dynamic SEO management, canonical URLs, and OpenGraph/Twitter card meta tags |
| **Google Identity Services (GSI)** | Client-side "Sign-In with Google" OAuth authentication |

---

### 2. **Progressive Web App (PWA) & Offline Capabilities**
| Technology | Purpose |
| :--- | :--- |
| **Custom Service Worker (`sw.js`)** | Background caching layer with versioned static asset precaching, network-first navigation, and stale-while-revalidate for API requests |
| **Web App Manifest (`manifest.json`)** | Allows students and faculty to install FAST TT+ as a native-like app on Android, iOS, Windows, and macOS |
| **Browser `localStorage`** | Fast client-side persistence for saved classes (`fasttt_classes_v3`), theme settings, and cached timetable versioning |

---

### 3. **Backend**
| Technology | Purpose |
| :--- | :--- |
| **Node.js** | JavaScript server runtime |
| **Express.js 4** | RESTful API framework handling routes, controllers, and middleware |
| **JSON-Driven Core Architecture** | In-memory indexing and MD5 content-hashed `timetable.json` for lightning-fast sub-millisecond timetable searches |
| **MySQL2 (`mysql2/promise`)** | Connection pooling and querying for persistent relational user accounts, notifications, and cloud sync |
| **JSON Web Tokens (`jsonwebtoken`)** | Stateless, secure user authentication and role-based authorization (Student, Teacher, Admin) |
| **bcryptjs** | Salted hashing for secure user password storage |
| **Express Rate Limit** | Protection against brute-force and spam requests |
| **Nodemailer** | SMTP integration for email verification, alerts, and notifications |
| **Node-Cron** | Scheduled background jobs and sync routines |
| **XLSX (SheetJS)** | Spreadsheet processing and schedule import utility |

---

### 4. **Data Extraction & Ingestion Scripts**
| Technology | Purpose |
| :--- | :--- |
| **Python 3** | Data pipeline and automated processing |
| **pdfplumber / PyPDF2** | Parsing raw university timetable PDF schedules into structured tables |
| **Pandas / OpenPyXL** | Spreadsheet extraction, room normalization, course code mapping, and JSON generation |

---

### 5. **Testing & Quality Assurance**
| Technology | Purpose |
| :--- | :--- |
| **Vitest** | Blazing-fast test runner with Vite integration |
| **React Testing Library** | Component and UI interaction testing |
| **JSDOM** | Browser DOM simulation for headless unit tests |

---

### 6. **Hosting & Deployment**
| Technology | Purpose |
| :--- | :--- |
| **Vercel** | Production hosting and continuous deployment for both Frontend (Static CDN/Edge) and Backend (Serverless Node.js functions) |
| **Cloud MySQL Database (TiDB / Aiven)** | Managed cloud relational database for persistent storage |
| **Git & GitHub** | Source code management and version control |
