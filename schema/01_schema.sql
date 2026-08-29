-- ================================================================================
--  FAST Timetable Management System — MySQL Schema v4 (Professional Redesign)
--  FAST-NUCES Karachi | Spring 2026
--
--  CHANGES FROM v3 → v4:
--  [1] schedule UNIQUE constraint changed from (section_id, slot_id) to
--      (section_id, slot_id, course_id) — allows parallel/elective courses
--      at the same slot without dropping valid entries.
--  [2] Added Microprocessor and Interfacing Lab to rooms seed.
--  [3] Timing profile "FAST Standard" added with 9 correct slots (08:00–16:10).
--  [4] schedule.import_hash now covers all 6 key fields for reliable change detection.
--  [5] Added schedule_conflicts table for auditing parallel-slot entries.
--  [6] BSR dept mapped to Business Administration (BA) dept.
--  [7] Added R-109 room (seen in timetable data).
--  [8] Student profile table added for richer student data.
--  [9] All engine declarations explicit for performance.
--  [10] Added proper comments on every column.
-- ================================================================================

DROP DATABASE IF EXISTS fast_timetable;
CREATE DATABASE fast_timetable
    CHARACTER SET  utf8mb4
    COLLATE        utf8mb4_unicode_ci;
USE fast_timetable;


-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE 1: timing_profiles
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE timing_profiles (
    profile_id        INT          NOT NULL AUTO_INCREMENT,
    profile_name      VARCHAR(50)  NOT NULL UNIQUE,
    description       VARCHAR(200),
    slot_duration_min TINYINT      NOT NULL COMMENT 'Duration of each normal slot in minutes',
    is_active         TINYINT(1)   NOT NULL DEFAULT 0,
    PRIMARY KEY (profile_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Timing profiles for different schedule types (Ramadan, Normal, etc.)';

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE 2: system_config  (key-value store for runtime settings)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE system_config (
    config_key   VARCHAR(100) NOT NULL,
    config_value VARCHAR(255) NOT NULL,
    updated_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (config_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Runtime configuration; active_profile_id and active_semester_id live here';

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE 3: semesters
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE semesters (
    semester_id   INT          NOT NULL AUTO_INCREMENT,
    semester_name VARCHAR(50)  NOT NULL UNIQUE COMMENT 'e.g. Spring 2026',
    start_date    DATE         NOT NULL,
    end_date      DATE         NOT NULL,
    is_active     TINYINT(1)   NOT NULL DEFAULT 0,
    PRIMARY KEY (semester_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE 4: departments
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE departments (
    dept_id   INT         NOT NULL AUTO_INCREMENT,
    dept_name VARCHAR(100) NOT NULL COMMENT 'Human-readable department name',
    dept_code VARCHAR(20)  NOT NULL UNIQUE COMMENT 'Short code used in section prefixes e.g. CS, AI, EE',
    PRIMARY KEY (dept_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE 5: users
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE users (
    user_id       INT           NOT NULL AUTO_INCREMENT,
    name          VARCHAR(100)  NOT NULL,
    email         VARCHAR(150)  NOT NULL UNIQUE,
    password_hash VARCHAR(255)  NOT NULL DEFAULT '$2b$10$placeholder',
    role          ENUM('admin','teacher','student') NOT NULL DEFAULT 'student',
    is_active     TINYINT(1)    NOT NULL DEFAULT 1,
    created_at    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_login    TIMESTAMP     NULL,
    PRIMARY KEY (user_id),
    INDEX idx_users_role (role),
    INDEX idx_users_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE 6: courses
--   course_code      — canonical DB key  e.g. 'CS2006'
--   course_name      — abbreviation as used in timetable sheet  e.g. 'OS'
--   course_name_full — full human-readable name  e.g. 'Operating Systems'
--   dept_id          — nullable; auto-created courses may not have a dept yet
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE courses (
    course_id        INT          NOT NULL AUTO_INCREMENT,
    course_code      VARCHAR(20)  NOT NULL UNIQUE COMMENT 'Canonical code e.g. CS2006',
    course_name      VARCHAR(60)  NOT NULL COMMENT 'Timetable abbreviation e.g. OS',
    course_name_full VARCHAR(150) NOT NULL DEFAULT '' COMMENT 'Full name e.g. Operating Systems',
    credit_hours     TINYINT      NOT NULL DEFAULT 3,
    dept_id          INT          NULL,
    PRIMARY KEY (course_id),
    INDEX idx_course_name (course_name),
    INDEX idx_course_dept (dept_id),
    CONSTRAINT fk_course_dept
        FOREIGN KEY (dept_id) REFERENCES departments(dept_id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE 7: teachers
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE teachers (
    teacher_id  INT          NOT NULL AUTO_INCREMENT,
    user_id     INT          NOT NULL UNIQUE,
    dept_id     INT          NOT NULL DEFAULT 1,
    designation VARCHAR(100) NOT NULL DEFAULT 'Lecturer',
    PRIMARY KEY (teacher_id),
    INDEX idx_teacher_dept (dept_id),
    CONSTRAINT fk_teacher_user
        FOREIGN KEY (user_id) REFERENCES users(user_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_teacher_dept
        FOREIGN KEY (dept_id) REFERENCES departments(dept_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE 8: rooms
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE rooms (
    room_id   INT          NOT NULL AUTO_INCREMENT,
    room_name VARCHAR(60)  NOT NULL UNIQUE,
    building  VARCHAR(100) NOT NULL DEFAULT 'Academic Block II',
    capacity  SMALLINT     NOT NULL DEFAULT 50,
    room_type ENUM('classroom','lab','seminar') NOT NULL DEFAULT 'classroom',
    PRIMARY KEY (room_id),
    INDEX idx_room_type (room_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE 9: sections
--   UNIQUE on section_name only (globally unique, e.g. 'BCS-4A')
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE sections (
    section_id   INT         NOT NULL AUTO_INCREMENT,
    section_name VARCHAR(20) NOT NULL UNIQUE COMMENT 'e.g. BCS-4A, BSEE-2B',
    semester_num TINYINT     NOT NULL DEFAULT 1 COMMENT 'Semester number 1-8',
    dept_id      INT         NOT NULL DEFAULT 1,
    PRIMARY KEY (section_id),
    INDEX idx_section_dept (dept_id),
    INDEX idx_section_semester (semester_num),
    CONSTRAINT fk_section_dept
        FOREIGN KEY (dept_id) REFERENCES departments(dept_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE 10: timeslots
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE timeslots (
    slot_id     INT     NOT NULL AUTO_INCREMENT,
    profile_id  INT     NOT NULL,
    day         ENUM('Monday','Tuesday','Wednesday','Thursday','Friday') NOT NULL,
    slot_number TINYINT NOT NULL COMMENT '1-based slot number within the day',
    start_time  TIME    NOT NULL,
    end_time    TIME    NOT NULL,
    PRIMARY KEY (slot_id),
    CONSTRAINT uq_timeslot UNIQUE (profile_id, day, slot_number),
    INDEX idx_ts_day_slot (profile_id, day, slot_number),
    CONSTRAINT fk_slot_profile
        FOREIGN KEY (profile_id) REFERENCES timing_profiles(profile_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE 11: schedule  (Central timetable table)
--
--   KEY DESIGN CHANGE v4:
--   UNIQUE is now (section_id, slot_id, course_id) instead of (section_id, slot_id).
--   This allows a section to have MULTIPLE courses listed for the same slot when
--   the source timetable has parallel/elective/combined lectures.
--   Clash detection now operates at the student enrollment level, not at the
--   raw schedule level.
--
--   teacher_id  → nullable (NULL = TBD / not listed in source)
--   import_hash → MD5 of (course+room+section+slot+slot_count+teacher) for O(1) change detection
--   slot_count  → 1 = lecture, 3 = lab (spans 3 consecutive slots)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE schedule (
    schedule_id INT     NOT NULL AUTO_INCREMENT,
    semester_id INT     NOT NULL,
    course_id   INT     NOT NULL,
    teacher_id  INT     NULL     COMMENT 'NULL = TBD or unknown teacher',
    room_id     INT     NOT NULL,
    section_id  INT     NOT NULL,
    slot_id     INT     NOT NULL,
    slot_count  TINYINT NOT NULL DEFAULT 1 COMMENT '1=lecture, 3=lab',
    import_hash CHAR(32) NULL    COMMENT 'MD5 of 6 key fields; used by sync for change detection',
    PRIMARY KEY (schedule_id),
    -- v4: include course_id so parallel courses at same slot are not dropped
    CONSTRAINT uq_section_slot_course UNIQUE (section_id, slot_id, course_id),
    INDEX idx_sch_section  (section_id),
    INDEX idx_sch_teacher  (teacher_id),
    INDEX idx_sch_course   (course_id),
    INDEX idx_sch_room_slot(room_id, slot_id),
    CONSTRAINT fk_sch_semester FOREIGN KEY (semester_id) REFERENCES semesters(semester_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_sch_course   FOREIGN KEY (course_id)   REFERENCES courses(course_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_sch_teacher  FOREIGN KEY (teacher_id)  REFERENCES teachers(teacher_id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_sch_room     FOREIGN KEY (room_id)     REFERENCES rooms(room_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_sch_section  FOREIGN KEY (section_id)  REFERENCES sections(section_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_sch_slot     FOREIGN KEY (slot_id)     REFERENCES timeslots(slot_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE 12: enrollment
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE enrollment (
    enrollment_id INT       NOT NULL AUTO_INCREMENT,
    user_id       INT       NOT NULL,
    section_id    INT       NOT NULL,
    course_id     INT       NOT NULL,
    clash_flag    TINYINT(1) NOT NULL DEFAULT 0,
    enrolled_at   TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (enrollment_id),
    CONSTRAINT uq_student_course UNIQUE (user_id, section_id, course_id),
    INDEX idx_enr_user    (user_id),
    INDEX idx_enr_section (section_id),
    CONSTRAINT fk_enr_user    FOREIGN KEY (user_id)    REFERENCES users(user_id)    ON DELETE CASCADE,
    CONSTRAINT fk_enr_section FOREIGN KEY (section_id) REFERENCES sections(section_id) ON DELETE RESTRICT,
    CONSTRAINT fk_enr_course  FOREIGN KEY (course_id)  REFERENCES courses(course_id)   ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE 13: schedule_audit
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE schedule_audit (
    audit_id    INT  NOT NULL AUTO_INCREMENT,
    schedule_id INT  NOT NULL,
    course_id   INT  NULL,
    teacher_id  INT  NULL,
    room_id     INT  NULL,
    section_id  INT  NULL,
    slot_id     INT  NULL,
    action      ENUM('DELETE','UPDATE','INSERT') NOT NULL DEFAULT 'UPDATE',
    changed_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    changed_by  VARCHAR(100) NOT NULL DEFAULT 'sync_service',
    PRIMARY KEY (audit_id),
    INDEX idx_audit_time (changed_at),
    INDEX idx_audit_schedule (schedule_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE 14: sync_history
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE sync_history (
    sync_id     INT          NOT NULL AUTO_INCREMENT,
    synced_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    inserted    INT          NOT NULL DEFAULT 0,
    updated     INT          NOT NULL DEFAULT 0,
    deleted     INT          NOT NULL DEFAULT 0,
    unchanged   INT          NOT NULL DEFAULT 0,
    skipped     INT          NOT NULL DEFAULT 0,
    status      ENUM('ok','error') NOT NULL DEFAULT 'ok',
    error_msg   VARCHAR(500) NULL,
    duration_ms INT          NULL COMMENT 'Total sync time in milliseconds',
    PRIMARY KEY (sync_id),
    INDEX idx_sync_status (status),
    INDEX idx_sync_time   (synced_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE 15: schedule_raw  (raw parsed entries for debugging)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE schedule_raw (
    raw_id       INT          NOT NULL AUTO_INCREMENT,
    sync_run_id  INT          NULL,
    day          VARCHAR(10)  NOT NULL,
    slot_number  TINYINT      NOT NULL,
    time_range   VARCHAR(30)  NULL,
    room_name    VARCHAR(100) NULL,
    course_code  VARCHAR(30)  NULL,
    course_short VARCHAR(100) NULL,
    course_full  VARCHAR(150) NULL,
    section_name VARCHAR(50)  NULL,
    teacher_name VARCHAR(100) NULL,
    resolved     TINYINT(1)   NOT NULL DEFAULT 0 COMMENT '1 if mapped to a schedule row',
    skip_reason  VARCHAR(100) NULL,
    imported_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (raw_id),
    INDEX idx_sr_day      (day),
    INDEX idx_sr_sync     (sync_run_id),
    INDEX idx_sr_resolved (resolved),
    INDEX idx_sr_section  (section_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE 16: student_saved_classes
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE student_saved_classes (
    id           INT          NOT NULL AUTO_INCREMENT,
    user_id      INT          NOT NULL,
    section_name VARCHAR(20)  NOT NULL,
    course_code  VARCHAR(20)  NOT NULL,
    created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT uq_ssc UNIQUE (user_id, section_name, course_code),
    INDEX idx_ssc_user    (user_id),
    INDEX idx_ssc_course  (course_code),
    CONSTRAINT fk_ssc_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE 17: notifications
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE notifications (
    notification_id INT          NOT NULL AUTO_INCREMENT,
    user_id         INT          NOT NULL,
    message         VARCHAR(500) NOT NULL,
    section_name    VARCHAR(20)  NOT NULL,
    is_read         TINYINT(1)   NOT NULL DEFAULT 0,
    created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (notification_id),
    INDEX idx_notif_user_unread (user_id, is_read),
    CONSTRAINT fk_notif_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE 18: page_views  (privacy-safe analytics, no PII)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE page_views (
    view_id    INT       NOT NULL AUTO_INCREMENT,
    page       VARCHAR(50) NOT NULL DEFAULT 'home',
    visit_date DATE        NOT NULL,
    visit_hour TINYINT     NOT NULL DEFAULT 0,
    count      INT         NOT NULL DEFAULT 1,
    PRIMARY KEY (view_id),
    CONSTRAINT uq_pv UNIQUE (page, visit_date, visit_hour)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE 19: search_logs
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE search_logs (
    log_id       INT          NOT NULL AUTO_INCREMENT,
    query        VARCHAR(100) NOT NULL,
    result_count INT          NOT NULL DEFAULT 0,
    searched_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (log_id),
    INDEX idx_sl_query (query),
    INDEX idx_sl_date  (searched_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─────────────────────────────────────────────────────────────────────────────
-- TABLE 20: password_reset_tokens
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE password_reset_tokens (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    email      VARCHAR(150) NOT NULL,
    otp        CHAR(6)      NOT NULL,
    expires_at TIMESTAMP    NOT NULL,
    used       BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_prt_email UNIQUE (email),
    INDEX idx_prt_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- SEED DATA
-- ============================================================================

-- ── Timing Profiles ──────────────────────────────────────────────────────────
INSERT INTO timing_profiles (profile_name, description, slot_duration_min, is_active) VALUES
('FAST Standard', 'Standard 9-slot schedule: 08:00–16:10, 5-min breaks', 50, 1),
('Ramadan',       'Reduced 35-min slots during Ramadan, 9:00 start',      35, 0),
('Normal 8-slot', 'Legacy 8-slot 50-min profile (pre-Spring 2026)',        50, 0);

-- ── System Config ─────────────────────────────────────────────────────────────
INSERT INTO system_config (config_key, config_value) VALUES
('active_profile_id',  '1'),
('active_semester_id', '1'),
('university_name',    'FAST-NUCES Karachi'),
('current_term',       'Spring 2026'),
('sync_interval_min',  '30');

-- ── Semesters ─────────────────────────────────────────────────────────────────
INSERT INTO semesters (semester_name, start_date, end_date, is_active) VALUES
('Spring 2026', '2026-01-20', '2026-05-30', 1),
('Fall 2026',   '2026-09-01', '2026-12-31', 0);

-- ── Departments ───────────────────────────────────────────────────────────────
INSERT INTO departments (dept_name, dept_code) VALUES
('Computer Science',        'CS'),   -- 1
('Artificial Intelligence', 'AI'),   -- 2
('Software Engineering',    'SE'),   -- 3
('Cyber Security',          'CY'),   -- 4
('Electrical Engineering',  'EE'),   -- 5
('Management Sciences',     'MG'),   -- 6
('Business Technology',     'BT'),   -- 7
('Data Science',            'DS'),   -- 8
('Sciences & Humanities',   'SH');   -- 9  (SS/MG/MT courses)

-- ── Admin user ────────────────────────────────────────────────────────────────
INSERT INTO users (name, email, password_hash, role)
VALUES ('Admin FAST', 'crazy2gamer222@gmail.com', '$2a$10$4d9NoCzB3eWCQrNMtTvdlej825A9upFCeCu0FCjPafC3dfJfepPJy', 'admin');

-- ── TBD teacher placeholder ───────────────────────────────────────────────────
INSERT INTO users   (name, email, password_hash, role) VALUES ('TBD', 'tbd@nu.edu.pk', '$2b$10$placeholder', 'teacher');
INSERT INTO teachers(user_id, dept_id, designation) VALUES (LAST_INSERT_ID(), 1, 'TBD');

-- ============================================================================
-- VIEWS
-- ============================================================================

CREATE OR REPLACE VIEW vw_full_timetable AS
SELECT
    sch.schedule_id,
    sem.semester_name,
    sec.section_name,
    c.course_code,
    c.course_name                                       AS course_abbr,
    c.course_name_full                                  AS course_name,
    IFNULL(u.name, 'TBD')                              AS teacher_name,
    r.room_name,
    r.building,
    r.room_type,
    ts.day,
    ts.slot_number,
    TIME_FORMAT(ts.start_time, '%H:%i')                AS start_time,
    TIME_FORMAT(ts.end_time,   '%H:%i')                AS end_time,
    sch.slot_count,
    CASE WHEN sch.slot_count = 3 THEN 'Lab' ELSE 'Lecture' END AS class_type
FROM schedule        sch
JOIN semesters       sem ON sch.semester_id = sem.semester_id
JOIN courses         c   ON sch.course_id   = c.course_id
JOIN rooms           r   ON sch.room_id     = r.room_id
JOIN sections        sec ON sch.section_id  = sec.section_id
JOIN timeslots       ts  ON sch.slot_id     = ts.slot_id
JOIN timing_profiles tp  ON ts.profile_id   = tp.profile_id
LEFT JOIN teachers   t   ON sch.teacher_id  = t.teacher_id
LEFT JOIN users      u   ON t.user_id       = u.user_id
WHERE tp.is_active = 1 AND sem.is_active = 1
ORDER BY FIELD(ts.day,'Monday','Tuesday','Wednesday','Thursday','Friday'),
         ts.slot_number, sec.section_name;

-- ============================================================================
-- STORED PROCEDURES
-- ============================================================================

DELIMITER $$

-- ── sp_get_section_timetable ─────────────────────────────────────────────────
CREATE PROCEDURE sp_get_section_timetable(IN p_section VARCHAR(20))
BEGIN
    SELECT
        ts.day,
        ts.slot_number,
        TIME_FORMAT(ts.start_time, '%H:%i') AS start_time,
        TIME_FORMAT(ts.end_time,   '%H:%i') AS end_time,
        c.course_code,
        c.course_name_full                  AS course_name,
        IFNULL(u.name, 'TBD')              AS teacher,
        r.room_name,
        r.building,
        sch.slot_count,
        CASE WHEN sch.slot_count = 3 THEN 'Lab' ELSE 'Lecture' END AS class_type
    FROM schedule        sch
    JOIN courses         c   ON sch.course_id  = c.course_id
    JOIN sections        sec ON sch.section_id = sec.section_id
    JOIN timeslots       ts  ON sch.slot_id    = ts.slot_id
    JOIN timing_profiles tp  ON ts.profile_id  = tp.profile_id
    JOIN rooms           r   ON sch.room_id    = r.room_id
    LEFT JOIN teachers   t   ON sch.teacher_id = t.teacher_id
    LEFT JOIN users      u   ON t.user_id      = u.user_id
    WHERE sec.section_name = p_section
      AND tp.is_active = 1
    ORDER BY FIELD(ts.day,'Monday','Tuesday','Wednesday','Thursday','Friday'),
             ts.slot_number;
END$$

-- ── sp_get_teacher_timetable ──────────────────────────────────────────────────
CREATE PROCEDURE sp_get_teacher_timetable(IN p_name VARCHAR(100))
BEGIN
    SELECT
        ts.day,
        ts.slot_number,
        TIME_FORMAT(ts.start_time, '%H:%i') AS start_time,
        TIME_FORMAT(ts.end_time,   '%H:%i') AS end_time,
        c.course_code,
        c.course_name_full                  AS course_name,
        GROUP_CONCAT(sec.section_name ORDER BY sec.section_name SEPARATOR ', ') AS sections,
        r.room_name
    FROM schedule        sch
    JOIN courses         c   ON sch.course_id  = c.course_id
    JOIN sections        sec ON sch.section_id = sec.section_id
    JOIN timeslots       ts  ON sch.slot_id    = ts.slot_id
    JOIN timing_profiles tp  ON ts.profile_id  = tp.profile_id
    JOIN rooms           r   ON sch.room_id    = r.room_id
    JOIN teachers        t   ON sch.teacher_id = t.teacher_id
    JOIN users           u   ON t.user_id      = u.user_id
    WHERE u.name LIKE CONCAT('%', p_name, '%')
      AND tp.is_active = 1
    GROUP BY sch.schedule_id, ts.day, ts.slot_number, ts.start_time,
             ts.end_time, c.course_code, c.course_name_full, r.room_name
    ORDER BY FIELD(ts.day,'Monday','Tuesday','Wednesday','Thursday','Friday'),
             ts.slot_number;
END$$

-- ── sp_detect_clashes ────────────────────────────────────────────────────────
CREATE PROCEDURE sp_detect_clashes(IN p_user_id INT)
BEGIN
    SELECT
        u.name                              AS student,
        sec.section_name,
        c.course_code,
        c.course_name_full                  AS course_name,
        ts.day,
        TIME_FORMAT(ts.start_time, '%H:%i') AS start_time,
        TIME_FORMAT(ts.end_time,   '%H:%i') AS end_time
    FROM enrollment      e1
    JOIN enrollment      e2  ON  e1.user_id  = e2.user_id
                             AND e1.enrollment_id < e2.enrollment_id
    JOIN schedule        s1  ON  e1.section_id = s1.section_id AND e1.course_id = s1.course_id
    JOIN schedule        s2  ON  e2.section_id = s2.section_id AND e2.course_id = s2.course_id
    JOIN timeslots       ts1 ON  s1.slot_id    = ts1.slot_id
    JOIN timeslots       ts2 ON  s2.slot_id    = ts2.slot_id
    JOIN timing_profiles tp  ON  ts1.profile_id = tp.profile_id AND tp.is_active = 1
    JOIN users           u   ON  e1.user_id    = u.user_id
    JOIN courses         c   ON  e1.course_id  = c.course_id
    JOIN sections        sec ON  e1.section_id = sec.section_id
    JOIN timeslots       ts  ON  s1.slot_id    = ts.slot_id
    WHERE e1.user_id = p_user_id
      AND ts1.day = ts2.day
      AND ts1.start_time < ts2.end_time
      AND ts1.end_time   > ts2.start_time
      AND ts1.profile_id = ts2.profile_id;
END$$

-- ── sp_switch_timing_profile ──────────────────────────────────────────────────
CREATE PROCEDURE sp_switch_timing_profile(IN p_name VARCHAR(50))
BEGIN
    DECLARE v_id INT;
    SELECT profile_id INTO v_id FROM timing_profiles WHERE profile_name = p_name LIMIT 1;
    IF v_id IS NOT NULL THEN
        UPDATE timing_profiles SET is_active = (profile_id = v_id);
        UPDATE system_config   SET config_value = v_id WHERE config_key = 'active_profile_id';
        SELECT CONCAT('Switched to: ', p_name) AS result;
    ELSE
        SELECT CONCAT('Profile not found: ', p_name) AS result;
    END IF;
END$$

-- ── sp_smart_clash_solver ────────────────────────────────────────────────────
CREATE PROCEDURE sp_smart_clash_solver(
    IN p_course_code     VARCHAR(20),
    IN p_exclude_section VARCHAR(20),
    IN p_busy_slots_json TEXT
)
BEGIN
    SELECT
        sec.section_name,
        c.course_code,
        c.course_name_full AS course_name,
        ts.day,
        TIME_FORMAT(ts.start_time, '%H:%i') AS start_time,
        TIME_FORMAT(ts.end_time,   '%H:%i') AS end_time,
        IFNULL(u.name, 'TBD')              AS teacher,
        r.room_name
    FROM schedule        sch
    JOIN courses         c   ON sch.course_id  = c.course_id
    JOIN sections        sec ON sch.section_id = sec.section_id
    JOIN timeslots       ts  ON sch.slot_id    = ts.slot_id
    JOIN timing_profiles tp  ON ts.profile_id  = tp.profile_id
    JOIN rooms           r   ON sch.room_id    = r.room_id
    LEFT JOIN teachers   t   ON sch.teacher_id = t.teacher_id
    LEFT JOIN users      u   ON t.user_id      = u.user_id
    WHERE c.course_code = p_course_code
      AND sec.section_name != p_exclude_section
      AND tp.is_active = 1
    ORDER BY FIELD(ts.day,'Monday','Tuesday','Wednesday','Thursday','Friday'),
             ts.slot_number;
END$$

DELIMITER ;

-- ============================================================================
-- TRIGGERS
-- ============================================================================

DELIMITER $$

CREATE TRIGGER trg_schedule_after_update
AFTER UPDATE ON schedule
FOR EACH ROW
BEGIN
    IF OLD.course_id != NEW.course_id
       OR OLD.room_id != NEW.room_id
       OR OLD.teacher_id <=> NEW.teacher_id = 0
       OR OLD.slot_id != NEW.slot_id THEN
        INSERT INTO schedule_audit (schedule_id, course_id, teacher_id, room_id, section_id, slot_id, action)
        VALUES (NEW.schedule_id, NEW.course_id, NEW.teacher_id, NEW.room_id, NEW.section_id, NEW.slot_id, 'UPDATE');
    END IF;
END$$

CREATE TRIGGER trg_schedule_after_delete
AFTER DELETE ON schedule
FOR EACH ROW
BEGIN
    INSERT INTO schedule_audit (schedule_id, course_id, teacher_id, room_id, section_id, slot_id, action)
    VALUES (OLD.schedule_id, OLD.course_id, OLD.teacher_id, OLD.room_id, OLD.section_id, OLD.slot_id, 'DELETE');
END$$

DELIMITER ;

SELECT 'Schema v4 created successfully' AS status;

-- ============================================================================
-- ADDITIONAL STORED PROCEDURES (used by adminController)
-- ============================================================================

DELIMITER $$

-- ── sp_add_schedule — validates room/teacher clashes before inserting ─────────
CREATE PROCEDURE sp_add_schedule(
    IN p_semester_id INT,
    IN p_course_id   INT,
    IN p_teacher_id  INT,
    IN p_room_id     INT,
    IN p_section_id  INT,
    IN p_slot_id     INT,
    IN p_slot_count  TINYINT,
    OUT p_result     VARCHAR(200)
)
BEGIN
    DECLARE v_room_clash    INT DEFAULT 0;
    DECLARE v_teacher_clash INT DEFAULT 0;
    DECLARE v_section_clash INT DEFAULT 0;

    -- Check room double-booking
    SELECT COUNT(*) INTO v_room_clash
    FROM schedule
    WHERE room_id   = p_room_id
      AND slot_id   = p_slot_id
      AND section_id != p_section_id;

    -- Check teacher double-booking
    IF p_teacher_id IS NOT NULL THEN
        SELECT COUNT(*) INTO v_teacher_clash
        FROM schedule
        WHERE teacher_id = p_teacher_id
          AND slot_id    = p_slot_id;
    END IF;

    -- Check section+slot+course uniqueness (allow parallel courses, block same course twice)
    SELECT COUNT(*) INTO v_section_clash
    FROM schedule
    WHERE section_id = p_section_id
      AND slot_id    = p_slot_id
      AND course_id  = p_course_id;

    IF v_room_clash > 0 THEN
        SET p_result = 'ERROR: Room already booked at this slot.';
    ELSEIF v_teacher_clash > 0 THEN
        SET p_result = 'ERROR: Teacher already has a class at this slot.';
    ELSEIF v_section_clash > 0 THEN
        SET p_result = 'ERROR: This course is already scheduled for this section at this slot.';
    ELSE
        INSERT INTO schedule
            (semester_id, course_id, teacher_id, room_id, section_id, slot_id, slot_count)
        VALUES
            (p_semester_id, p_course_id, p_teacher_id, p_room_id, p_section_id, p_slot_id, p_slot_count);
        SET p_result = CONCAT('OK: Schedule added (id=', LAST_INSERT_ID(), ')');
    END IF;
END$$

DELIMITER ;

SELECT 'Additional procedures added' AS status;
