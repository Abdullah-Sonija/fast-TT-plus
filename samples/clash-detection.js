/**
 * @file clash-detection.js
 * @description Core interval arithmetic and multi-slot overlap detection engine for FastTT+.
 * Handles both standard 50-minute lectures and multi-slot continuous laboratory sessions.
 */

'use strict';

/**
 * Converts a 12-hour formatted time string to minutes from midnight.
 *
 * @param {string} timeStr - Time string formatted as "08:00 AM" or "02:30 PM"
 * @returns {number} Minutes from midnight (e.g. "08:30 AM" -> 510)
 */
function parseTimeToMinutes(timeStr) {
  if (!timeStr) return 0;
  const parts = timeStr.trim().split(/[:\s]/);
  if (parts.length < 3) return 0;

  let hours = parseInt(parts[0], 10);
  const minutes = parseInt(parts[1], 10);
  const period = parts[2].toUpperCase();

  if (period === 'PM' && hours !== 12) hours += 12;
  if (period === 'AM' && hours === 12) hours = 0;

  return hours * 60 + minutes;
}

/**
 * Calculates the effective end time for a course entry, handling pre-computed multi-slot labs.
 *
 * @param {Object} classEntry - Schedule entry object
 * @param {string} classEntry.start_time - e.g. "08:00 AM"
 * @param {string} classEntry.end_time - e.g. "08:50 AM" or "10:40 AM"
 * @param {number} [classEntry.slot_count=1] - Number of continuous 50-minute slots
 * @returns {number} Effective end time in minutes from midnight
 */
function getEffectiveEndMinutes(classEntry) {
  const startMin = parseTimeToMinutes(classEntry.start_time);
  const slotCount = classEntry.slot_count || 1;

  // Multi-slot laboratory computation (3 slots = 160 minutes including inter-slot breaks)
  if (slotCount > 1) {
    const totalDurationMinutes = slotCount * 50 + (slotCount - 1) * 5;
    return startMin + totalDurationMinutes;
  }

  return parseTimeToMinutes(classEntry.end_time);
}

/**
 * Determines whether two scheduled classes conflict with each other.
 *
 * @param {Object} classA - First schedule entry
 * @param {Object} classB - Second schedule entry
 * @returns {boolean} True if the classes overlap in time on the same day
 */
function checkClassesClash(classA, classB) {
  // Different days cannot clash
  if (!classA.day || !classB.day || classA.day !== classB.day) {
    return false;
  }

  // Same section & same course occurring across consecutive periods is a continuous block, not a clash
  if (
    classA.course_code === classB.course_code &&
    classA.section_name === classB.section_name
  ) {
    return false;
  }

  const startA = parseTimeToMinutes(classA.start_time);
  const endA = getEffectiveEndMinutes(classA);

  const startB = parseTimeToMinutes(classB.start_time);
  const endB = getEffectiveEndMinutes(classB);

  // Standard interval overlap condition: (StartA < EndB) && (StartB < EndA)
  return startA < endB && startB < endA;
}

/**
 * Detects all pairwise clashes in an array of enrolled course sections.
 *
 * @param {Array<Object>} enrolledClasses - Array of schedule objects
 * @returns {Array<Object>} Array of clash conflict descriptors
 */
function detectAllScheduleClashes(enrolledClasses) {
  const conflicts = [];

  for (let i = 0; i < enrolledClasses.length; i++) {
    for (let j = i + 1; j < enrolledClasses.length; j++) {
      const classA = enrolledClasses[i];
      const classB = enrolledClasses[j];

      if (checkClassesClash(classA, classB)) {
        conflicts.push({
          day: classA.day,
          course_1: `${classA.course_name} (${classA.section_name})`,
          course_2: `${classB.course_name} (${classB.section_name})`,
          time_1: `${classA.start_time} - ${classA.end_time}`,
          time_2: `${classB.start_time} - ${classB.end_time}`,
        });
      }
    }
  }

  return conflicts;
}

module.exports = {
  parseTimeToMinutes,
  getEffectiveEndMinutes,
  checkClassesClash,
  detectAllScheduleClashes,
};
