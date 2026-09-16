/**
 * Utility for detecting and filtering out emojis and pictographic symbols.
 */

const EMOJI_RANGE_REGEX = /\p{Extended_Pictographic}/gu;

/**
 * Checks if a string contains any emoji character.
 * @param {string} str 
 * @returns {boolean}
 */
export function containsEmoji(str) {
  if (!str) return false;
  try {
    return /\p{Extended_Pictographic}/u.test(str);
  } catch {
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
  } catch {
    return str.replace(/[\uD800-\uDBFF][\uDC00-\uDFFF]|[\u2600-\u27BF]/g, '');
  }
}
