/**
 * @file search-matcher.js
 * @description Substring and multi-token search matching algorithm used in FastTT+.
 * Handles section code variations, lab identifiers, and academic title normalization.
 */

'use strict';

// Common academic prefixes and post-nominals stripped during tokenization
const ACADEMIC_TITLES_REGEX = /^(dr\.?|engr\.?|prof\.?|mr\.?|ms\.?|mrs\.?|lecturer)\s+/i;
const ACADEMIC_SUFFIX_REGEX = /(,\s*(phd|ms|m\.phil|bsc|msc|postdoc))+$/i;

/**
 * Normalizes an instructor's name by stripping titles and excess whitespace.
 *
 * @param {string} rawName - Raw faculty string (e.g. "Dr. Kamran Ali, PhD")
 * @returns {string} Clean normalized string (e.g. "kamran ali")
 */
function normalizeFacultyName(rawName) {
  if (!rawName) return '';
  return rawName
    .trim()
    .replace(ACADEMIC_TITLES_REGEX, '')
    .replace(ACADEMIC_SUFFIX_REGEX, '')
    .toLowerCase()
    .replace(/\s+/g, ' ');
}

/**
 * Matches a query against a faculty member's name using multi-token matching.
 * Requires at least 2 distinct matching tokens if multiple names share a common first name.
 *
 * @param {string} facultyName - Target teacher name
 * @param {string} query - User search term
 * @param {number} [minTokens=1] - Minimum number of matching name tokens required
 * @returns {boolean} True if query matches the faculty member
 */
function matchFaculty(facultyName, query, minTokens = 1) {
  if (!facultyName || !query) return false;

  const normalizedFaculty = normalizeFacultyName(facultyName);
  const normalizedQuery = normalizeFacultyName(query);

  // Exact substring match
  if (normalizedFaculty.includes(normalizedQuery)) {
    return true;
  }

  const queryTokens = normalizedQuery.split(' ').filter(Boolean);
  const facultyTokens = normalizedFaculty.split(' ').filter(Boolean);

  let matchedTokenCount = 0;
  for (const qToken of queryTokens) {
    if (facultyTokens.some(fToken => fToken.startsWith(qToken) || fToken === qToken)) {
      matchedTokenCount++;
    }
  }

  return matchedTokenCount >= Math.min(minTokens, queryTokens.length);
}

/**
 * Matches section codes (e.g. "BCS-4A", "BAI-6B", "Lab-4") with hyphen sensitivity.
 *
 * @param {string} sectionName - Actual section code (e.g. "BCS-4A")
 * @param {string} query - User input
 * @returns {boolean} True if matching
 */
function matchSection(sectionName, query) {
  if (!sectionName || !query) return false;

  const cleanSection = sectionName.trim().toLowerCase();
  const cleanQuery = query.trim().toLowerCase();

  return cleanSection.includes(cleanQuery);
}

/**
 * Universal timetable search filter evaluating a query against all class fields.
 *
 * @param {Object} classEntry - Schedule item
 * @param {string} query - User search input
 * @returns {boolean} True if the class entry satisfies the query
 */
function filterTimetableEntry(classEntry, query) {
  if (!query) return true;

  const q = query.trim().toLowerCase();

  return (
    matchSection(classEntry.section_name, q) ||
    (classEntry.course_code && classEntry.course_code.toLowerCase().includes(q)) ||
    (classEntry.course_name && classEntry.course_name.toLowerCase().includes(q)) ||
    matchFaculty(classEntry.teacher_name, q) ||
    (classEntry.room_code && classEntry.room_code.toLowerCase().includes(q))
  );
}

module.exports = {
  normalizeFacultyName,
  matchFaculty,
  matchSection,
  filterTimetableEntry,
};
