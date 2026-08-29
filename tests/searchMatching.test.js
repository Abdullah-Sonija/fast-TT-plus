import { describe, it, expect } from 'vitest';

describe('Exact Case-Insensitive Substring Search', () => {
  const sampleClasses = [
    {
      course_code: 'CS2005',
      course_name: 'Database Systems',
      section_name: 'BAI-5A',
      teacher_name: 'Dr. Kamran Ali',
      room_name: 'LAB-4 (CS Building)',
      combined_sections: 'BAI-5A,BAI-5B',
    },
    {
      course_code: 'CL2001',
      course_name: 'Data Structures - Lab',
      section_name: 'BCS-3G',
      teacher_name: 'Izzah',
      room_name: 'LAB-6 (EE Building)',
      combined_sections: 'BCS-3G',
    }
  ];

  function search(classes, query) {
    if (!query) return classes;
    const qLow = query.trim().toLowerCase();
    return classes.filter(c =>
      (c.course_code || '').toLowerCase().includes(qLow) ||
      (c.course_name || '').toLowerCase().includes(qLow) ||
      (c.section_name || '').toLowerCase().includes(qLow) ||
      (c.teacher_name || '').toLowerCase().includes(qLow) ||
      (c.room_name || '').toLowerCase().includes(qLow)
    );
  }

  it('matches exact section with case variations (bai-5a, BAI-5A, Bai-5a)', () => {
    expect(search(sampleClasses, 'bai-5a').length).toBe(1);
    expect(search(sampleClasses, 'BAI-5A').length).toBe(1);
    expect(search(sampleClasses, 'Bai-5a').length).toBe(1);
  });

  it('does NOT match section when hyphen is missing or replaced with space (bai 5a, bai5a)', () => {
    expect(search(sampleClasses, 'bai 5a').length).toBe(0);
    expect(search(sampleClasses, 'bai5a').length).toBe(0);
  });

  it('matches exact lab with case variations (lab-4, LAB-4)', () => {
    expect(search(sampleClasses, 'lab-4').length).toBe(1);
    expect(search(sampleClasses, 'LAB-4').length).toBe(1);
    expect(search(sampleClasses, 'Lab-4').length).toBe(1);
  });

  it('does NOT match lab when hyphen is missing or replaced with space (lab4, lab 4)', () => {
    expect(search(sampleClasses, 'lab4').length).toBe(0);
    expect(search(sampleClasses, 'lab 4').length).toBe(0);
  });

  it('matches course code case-insensitively (cs2005, CS2005)', () => {
    expect(search(sampleClasses, 'cs2005').length).toBe(1);
    expect(search(sampleClasses, 'CS2005').length).toBe(1);
  });

  it('matches teacher name case-insensitively (kamran, Dr. Kamran Ali)', () => {
    expect(search(sampleClasses, 'kamran').length).toBe(1);
    expect(search(sampleClasses, 'DR. KAMRAN ALI').length).toBe(1);
  });
});
