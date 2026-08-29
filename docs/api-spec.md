# REST API Specification

This document details the RESTful API endpoints, request/response models, authentication headers, and rate-limiting policies for the **FastTT+ Backend API**.

- **Base URL:** `https://fast-tt-backend.vercel.app/api` (Production) | `http://localhost:5000/api` (Local)

---

## 1. Authentication & User Management

### `POST /auth/register`
Registers a new user and initiates the 2-hour email verification workflow.

**Request Body:**
```json
{
  "name": "Abdullah Sonija",
  "email": "k240013@nu.edu.pk",
  "password": "strongPassword123"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "pending_verification": true,
  "email": "k240013@nu.edu.pk",
  "message": "Verification email sent! Please check your inbox and click the link to activate your account (valid for 2 hours)."
}
```

---

### `GET /auth/verify-email`
Verifies the cryptographic token delivered via email, moves the user into active MySQL records, and issues a 30-day JWT.

**Query Parameters:**
- `token` (string, required): 64-character hex verification token.

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Email verified successfully! Welcome to FAST TT+.",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "role": "student",
  "name": "Abdullah Sonija",
  "email": "k240013@nu.edu.pk",
  "user_id": 142
}
```

---

### `POST /auth/login`
Authenticates an active user with email and password.

**Request Body:**
```json
{
  "email": "k240013@nu.edu.pk",
  "password": "strongPassword123"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "role": "student",
  "name": "Abdullah Sonija",
  "email": "k240013@nu.edu.pk",
  "user_id": 142
}
```

---

### `POST /auth/forgot-password`
Generates a cryptographically secure 6-digit OTP valid for 15 minutes.

**Request Body:**
```json
{
  "email": "k240013@nu.edu.pk"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Password reset code sent to your email."
}
```

---

## 2. Timetable & Schedule Search

### `GET /timetable/search`
Performs substring search across sections, courses, faculty, and classrooms.

**Query Parameters:**
- `q` (string, required): Search query (e.g. `BCS-4A`, `Calculus`, `Farooq`).
- `day` (string, optional): Filter by day (`Monday`, `Tuesday`, etc.).

**Response (200 OK):**
```json
{
  "success": true,
  "count": 4,
  "data": [
    {
      "day": "Monday",
      "slot_number": 1,
      "start_time": "08:00 AM",
      "end_time": "08:50 AM",
      "course_code": "CS2001",
      "course_name": "Data Structures",
      "section_name": "BCS-4A",
      "teacher_name": "Dr. Farooq",
      "room_code": "C-301",
      "room_type": "Classroom"
    }
  ]
}
```

---

### `GET /timetable/free-rooms`
Calculates unoccupied classrooms and computer laboratories for a given day and period.

**Query Parameters:**
- `day` (string, required): `Monday` | `Tuesday` | `Wednesday` | `Thursday` | `Friday`
- `type` (string, optional): `all` | `classroom` | `lab`

**Response (200 OK):**
```json
{
  "success": true,
  "day": "Monday",
  "type": "all",
  "total_free_slots": 42,
  "data": [
    {
      "room_code": "E-401",
      "room_type": "Classroom",
      "free_slots": ["08:00 AM - 08:50 AM", "11:35 AM - 12:25 PM"]
    }
  ]
}
```

---

## 3. Clash Detection & Solver

### `POST /timetable/smart-clash-solver`
Identifies schedule clashes among a student's selected courses and suggests conflict-free alternative sections.

**Request Body:**
```json
{
  "selected_sections": ["BCS-4A", "BCS-4B", "BAI-4A"]
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "has_clash": true,
  "clash_details": [
    {
      "day": "Monday",
      "time": "08:00 AM - 08:50 AM",
      "conflict": "Data Structures (BCS-4A) clashes with Operating Systems (BCS-4B)"
    }
  ],
  "suggested_alternatives": [
    {
      "course": "Operating Systems",
      "replace_with": "BCS-4C",
      "reason": "Resolves Monday 08:00 AM clash without creating new conflicts"
    }
  ]
}
```

---

## 4. Rate Limiting & Security Headers

| Endpoint Category | Window | Max Requests | Action on Exceed |
|---|---|---|---|
| Password Reset (`/auth/forgot-password`) | 15 minutes | 5 per IP | HTTP 429 Too Many Requests |
| Auth Endpoints (`/auth/login`, `/auth/reset-password`) | 15 minutes | 10 per IP | HTTP 429 Too Many Requests |
| Public Timetable Queries | Standard | Unlimited | Cached via Service Worker |
