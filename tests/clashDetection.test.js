import { describe, it, expect } from 'vitest';
import { timesOverlap, detectClashes, getEffectiveEndTime } from '../utils/clashUtils';

describe('Multi-Slot Lab & Class Clash Detection', () => {
  const labMonday = {
    course_code: 'SL1012',
    course_name: 'Functional English - Lab',
    section_name: 'BCS-1A',
    day: 'Monday',
    slot_number: 1,
    start_time: '08:00',
    end_time: '08:50',
    slot_count: 3, // Spans Slot 1 (08:00-08:50), Slot 2 (08:55-09:45), Slot 3 (09:50-10:40)
  };

  it('calculates effective end time of a 3-slot lab accurately', () => {
    const effectiveEnd = getEffectiveEndTime(labMonday);
    expect(effectiveEnd).toBe('10:40');
  });

  it('detects clash when a lecture starts at 08:00 AM (Slot 1 - same start time)', () => {
    const classSlot1 = {
      course_code: 'CS1002',
      course_name: 'Programming Fundamentals',
      section_name: 'BCS-1B',
      day: 'Monday',
      slot_number: 1,
      start_time: '08:00',
      end_time: '08:50',
      slot_count: 1,
    };

    expect(timesOverlap(labMonday, classSlot1)).toBe(true);
    expect(timesOverlap(classSlot1, labMonday)).toBe(true);

    const clashing = detectClashes([labMonday, classSlot1]);
    expect(clashing.size).toBe(2);
  });

  it('detects clash when a lecture starts at 08:55 AM (Slot 2 - middle of the lab)', () => {
    const classSlot2 = {
      course_code: 'MT1004',
      course_name: 'Linear Algebra',
      section_name: 'BCS-1C',
      day: 'Monday',
      slot_number: 2,
      start_time: '08:55',
      end_time: '09:45',
      slot_count: 1,
    };

    expect(timesOverlap(labMonday, classSlot2)).toBe(true);
    expect(timesOverlap(classSlot2, labMonday)).toBe(true);

    const clashing = detectClashes([labMonday, classSlot2]);
    expect(clashing.size).toBe(2);
  });

  it('detects clash when a lecture starts at 09:50 AM (Slot 3 - last slot of the lab)', () => {
    const classSlot3 = {
      course_code: 'CS2005',
      course_name: 'Database Systems',
      section_name: 'BCS-1D',
      day: 'Monday',
      slot_number: 3,
      start_time: '09:50',
      end_time: '10:40',
      slot_count: 1,
    };

    expect(timesOverlap(labMonday, classSlot3)).toBe(true);
    expect(timesOverlap(classSlot3, labMonday)).toBe(true);

    const clashing = detectClashes([labMonday, classSlot3]);
    expect(clashing.size).toBe(2);
  });

  it('does NOT flag a clash when a lecture starts at 10:45 AM (Slot 4 - after lab finishes)', () => {
    const classSlot4 = {
      course_code: 'CS2006',
      course_name: 'Operating Systems',
      section_name: 'BCS-1A',
      day: 'Monday',
      slot_number: 4,
      start_time: '10:45',
      end_time: '11:35',
      slot_count: 1,
    };

    expect(timesOverlap(labMonday, classSlot4)).toBe(false);
    expect(timesOverlap(classSlot4, labMonday)).toBe(false);

    const clashing = detectClashes([labMonday, classSlot4]);
    expect(clashing.size).toBe(0);
  });

  it('does NOT clash classes on different days', () => {
    const tuesdayClass = {
      course_code: 'CS1002',
      course_name: 'Programming Fundamentals',
      section_name: 'BCS-1B',
      day: 'Tuesday',
      slot_number: 1,
      start_time: '08:00',
      end_time: '08:50',
      slot_count: 1,
    };

    expect(timesOverlap(labMonday, tuesdayClass)).toBe(false);
  });

  it('does NOT clash consecutive periods of the same course and same section', () => {
    const sameSectionPart1 = {
      course_code: 'CS2005',
      section_name: 'BAI-5A',
      day: 'Wednesday',
      slot_number: 1,
      start_time: '08:00',
      end_time: '08:50',
      slot_count: 1,
    };
    const sameSectionPart2 = {
      course_code: 'CS2005',
      section_name: 'BAI-5A',
      day: 'Wednesday',
      slot_number: 1,
      start_time: '08:00',
      end_time: '08:50',
      slot_count: 1,
    };

    expect(timesOverlap(sameSectionPart1, sameSectionPart2)).toBe(false);
  });
});

describe('New Timetable Format — Pre-Computed Lab end_time', () => {
  // New format: end_time is already the full 3-slot duration, NOT a single-slot end.
  const labNewFormat = {
    course_code: 'AL3002',
    course_name: 'Machine Learning - Lab',
    section_name: 'BAI-5A',
    day: 'Thursday',
    slot_number: 1,
    start_time: '08:00',
    end_time: '10:40', // pre-computed full lab end time
    slot_count: 3,
  };

  it('returns end_time as-is when it is already the pre-computed multi-slot end (new format)', () => {
    const effectiveEnd = getEffectiveEndTime(labNewFormat);
    expect(effectiveEnd).toBe('10:40'); // Should NOT become 16:10
  });

  it('old single-slot format still computes correctly (08:50 with slot_count=3 → 10:40)', () => {
    const labOldFormat = {
      course_code: 'SL1012',
      course_name: 'Functional English - Lab',
      section_name: 'BCS-1A',
      day: 'Monday',
      slot_number: 1,
      start_time: '08:00',
      end_time: '08:50', // single slot end time (old format)
      slot_count: 3,
    };
    const effectiveEnd = getEffectiveEndTime(labOldFormat);
    expect(effectiveEnd).toBe('10:40');
  });

  it('detects clash when a lecture at 08:55 overlaps with new-format lab (08:00 - 10:40)', () => {
    const lectureSlot2 = {
      course_code: 'CS2005',
      course_name: 'Database Systems',
      section_name: 'BAI-5B',
      day: 'Thursday',
      slot_number: 2,
      start_time: '08:55',
      end_time: '09:45',
      slot_count: 1,
    };
    expect(timesOverlap(labNewFormat, lectureSlot2)).toBe(true);
  });

  it('does NOT flag clash when a lecture starts at 10:45 (after new-format lab ends at 10:40)', () => {
    const lectureSlot4 = {
      course_code: 'CS2009',
      course_name: 'Design and Analysis of Algorithms',
      section_name: 'BAI-5A',
      day: 'Thursday',
      slot_number: 4,
      start_time: '10:45',
      end_time: '11:35',
      slot_count: 1,
    };
    expect(timesOverlap(labNewFormat, lectureSlot4)).toBe(false);
  });
});

