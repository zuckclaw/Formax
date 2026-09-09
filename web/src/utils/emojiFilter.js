/**
 * Utility for detecting and filtering out emojis and pictographic symbols.
 */

const EMOJI_RANGE_REGEX = /[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F1E0}-\u{1F1FF}\u{1F900}-\u{1F9FF}\u{1FA70}-\u{1FAFF}\u{2600}-\u{27BF}\u{2300}-\u{23FF}\u{2B00}-\u{2BFF}\u{200D}\u{FE0F}]/gu;

/**
 * Checks if a string contains any emoji character.
 * @param {string} str 
 * @returns {boolean}
 */
export function containsEmoji(str) {
  if (!str) return false;
  try {
    return /\p{Extended_Pictographic}/u.test(str) || /[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F1E0}-\u{1F1FF}\u{1F900}-\u{1F9FF}\u{1FA70}-\u{1FAFF}\u{2600}-\u{27BF}\u{2300}-\u{23FF}\u{2B00}-\u{2BFF}\u{200D}\u{FE0F}]/u.test(str);
  } catch (e) {
    return /[\uD800-\uDBFF][\uDC00-\uDFFF]|[\u2600-\u27BF]/.test(str);
  }
}

/**
 * Removes all emojis and pictographic symbols from a string.
 * @param {string} str 
 * @returns {string}
 */
export function removeEmojis(str) {
  if (!str) return '';
  try {
    let result = str.replace(/\p{Extended_Pictographic}/gu, '');
    result = result.replace(EMOJI_RANGE_REGEX, '');
    return result;
  } catch (e) {
    return str.replace(/[\uD800-\uDBFF][\uDC00-\uDFFF]|[\u2600-\u27BF]/g, '');
  }
}
