// Copyright 2026 The Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// PDF date format parser.
//
// PDF dates use the format: D:YYYYMMDDHHmmSSOHH'mm'
//   D:     — optional prefix
//   YYYY   — 4-digit year (required)
//   MM     — 2-digit month (01–12), default 01
//   DD     — 2-digit day (01–31), default 01
//   HH     — 2-digit hour (00–23), default 00
//   mm     — 2-digit minute (00–59), default 00
//   SS     — 2-digit second (00–59), default 00
//   O      — timezone offset sign: '+', '-', or 'Z'
//   HH'mm' — UTC offset hours and minutes (quoted), e.g. "05'30'" for +05:30
//
// Real-world PDFs deviate: the D: prefix may be missing, the string may be
// truncated after any component, and the offset separator is sometimes ':'.

import 'pdf_types.dart';

/// Parses PDF date strings into [PdfDate] values.
///
/// This is a hand-rolled parser because Dart's [DateTime.parse] does not
/// handle the PDF date format `D:YYYYMMDDHHmmSSOHH'mm'`.
///
/// The parser is tolerant of real-world deviations:
/// - Missing `D:` prefix.
/// - Truncation after any component (year is the minimum required).
/// - `Z` for UTC timezone instead of a signed offset.
/// - Offset separator as `'` or `:`.
class PdfDateParser {
  // Private constructor — all methods are static.
  // coverage:ignore-next-line
  const PdfDateParser._();

  /// Parses [raw] into a [PdfDate].
  ///
  /// If [raw] is empty or `null`, returns `null`. If parsing fails, returns a
  /// [PdfDate] with [PdfDate.value] set to `null` and [PdfDate.raw] set to
  /// the original string so callers can inspect or log it.
  static PdfDate? parse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return PdfDate(raw: raw, value: _tryParse(raw));
  }

  /// Attempts to parse a PDF date string, returning `null` on failure.
  static DateTime? _tryParse(String raw) {
    // Remove the optional 'D:' prefix (case-insensitive for robustness).
    String s = raw;
    if (s.startsWith('D:') || s.startsWith('d:')) {
      s = s.substring(2);
    }

    // Remove any trailing whitespace or null characters that some tools add.
    s = s.trim();

    // The year (4 digits) is the minimum required component.
    if (s.length < 4) return null;

    try {
      // Parse each date/time component with fallback defaults.
      final year = _parseInt(s, 0, 4);
      if (year == null) return null;

      final month = s.length >= 6 ? (_parseInt(s, 4, 6) ?? 1) : 1;
      final day = s.length >= 8 ? (_parseInt(s, 6, 8) ?? 1) : 1;
      final hour = s.length >= 10 ? (_parseInt(s, 8, 10) ?? 0) : 0;
      final minute = s.length >= 12 ? (_parseInt(s, 10, 12) ?? 0) : 0;
      final second = s.length >= 14 ? (_parseInt(s, 12, 14) ?? 0) : 0;

      // Validate ranges to catch obviously invalid dates.
      if (month < 1 || month > 12) return null;
      if (day < 1 || day > 31) return null;
      if (hour > 23 || minute > 59 || second > 59) return null;

      // Parse the optional UTC offset starting at position 14.
      // The offset character is '+', '-', or 'Z'.
      //
      // We always produce a UTC DateTime. The approach:
      //   1. Build the time as UTC.namedConstructor(year, month, day, ...).
      //   2. Subtract the offset to convert from local-zone to UTC.
      //      e.g. 12:00 +05:30 → subtract 5h30m → 06:30 UTC.
      //      e.g. 12:00 -08:00 → subtract -8h   → 20:00 UTC.
      Duration offset = Duration.zero;
      if (s.length > 14) {
        final sign = s[14];
        if (sign == 'Z' || sign == 'z') {
          // Explicit UTC — offset is zero; the components are already UTC.
          offset = Duration.zero;
        } else if (sign == '+' || sign == '-') {
          // Parse offset hours and minutes. The format is OHH'mm' or OHH:mm.
          // After the sign character, we expect up to 4 more digits with an
          // optional separator (apostrophe or colon) between hours and minutes.
          final offsetStr = s.substring(15); // everything after the sign
          final offsetHours = _parseOffsetComponent(offsetStr, 0);
          final offsetMinutes = _parseOffsetComponent(offsetStr, 2);
          final totalMinutes = (offsetHours ?? 0) * 60 + (offsetMinutes ?? 0);
          // A +05:30 offset means the local time is 5h30m ahead of UTC,
          // so we subtract the offset to get UTC.
          offset = Duration(
            minutes: sign == '+' ? totalMinutes : -totalMinutes,
          );
        }
        // Unknown sign character → treat as UTC (best-effort).
      }

      // Build the parsed components as a UTC DateTime, then subtract the
      // local-to-UTC offset. Using DateTime.utc() avoids the host timezone
      // being applied, which would produce incorrect results on machines in
      // non-UTC timezones.
      final asUtc = DateTime.utc(year, month, day, hour, minute, second);
      return asUtc.subtract(offset);
    } catch (_) {
      // Any out-of-range component (e.g. day 32, month 13) will cause
      // DateTime() to throw — catch all and return null.
      return null;
    }
  }

  /// Parses a decimal integer from [s] at character positions [start]..[end-1].
  ///
  /// Returns `null` if the substring contains non-digit characters.
  static int? _parseInt(String s, int start, int end) {
    if (end > s.length) end = s.length;
    if (start >= end) return null;
    final sub = s.substring(start, end);
    return int.tryParse(sub);
  }

  /// Parses an offset component (hours or minutes) from a substring.
  ///
  /// The offset string has the form `HH'mm'` or `HH:mm` or just `HH`. This
  /// method skips any non-digit separator character and reads 2 digits at the
  /// given [position] within the effective digit sequence.
  ///
  /// For [position] 0 → reads characters 0–1 (hours).
  /// For [position] 2 → reads characters after the separator (minutes).
  static int? _parseOffsetComponent(String s, int position) {
    // Build a digit-only version of the offset string by filtering separators.
    // e.g. "05'30'" → "0530", "05:30" → "0530", "0530" → "0530"
    final digits = s.replaceAll(RegExp(r"[^0-9]"), '');
    return _parseInt(digits, position, position + 2);
  }
}
