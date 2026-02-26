/// CSV parse/serialize helpers. RFC 4180 style: quote fields containing comma, newline, or ".
library;

/// Escape and quote a field if it contains comma, newline, or double-quote.
String escapeCsvField(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n') || value.contains('\r')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

/// Parse one CSV row (handles quoted fields).
List<String> parseCsvRow(String line) {
  final result = <String>[];
  var i = 0;
  while (i < line.length) {
    if (line[i] == '"') {
      final sb = StringBuffer();
      i++;
      while (i < line.length) {
        if (line[i] == '"') {
          i++;
          if (i < line.length && line[i] == '"') {
            sb.write('"');
            i++;
          } else {
            break;
          }
        } else {
          sb.write(line[i]);
          i++;
        }
      }
      result.add(sb.toString());
    } else {
      final end = line.indexOf(',', i);
      if (end == -1) {
        result.add(line.substring(i).trim());
        break;
      }
      result.add(line.substring(i, end).trim());
      i = end + 1;
    }
  }
  return result;
}

/// Build CSV string from header and list of row maps. Keys of [header] define column order.
String mapListToCsv(List<String> header, List<Map<String, dynamic>> rows) {
  final sb = StringBuffer();
  sb.writeln(header.map(escapeCsvField).join(','));
  for (final row in rows) {
    sb.writeln(header.map((k) => escapeCsvField(row[k]?.toString() ?? '')).join(','));
  }
  return sb.toString();
}

/// Parse CSV string into list of maps. First line = header.
List<Map<String, dynamic>> csvToMapList(String csv) {
  final lines = csv.split(RegExp(r'\r?\n'));
  if (lines.isEmpty) return [];
  final header = parseCsvRow(lines[0]);
  final result = <Map<String, dynamic>>[];
  for (var i = 1; i < lines.length; i++) {
    final line = lines[i];
    if (line.trim().isEmpty) continue;
    final values = parseCsvRow(line);
    final map = <String, dynamic>{};
    for (var j = 0; j < header.length && j < values.length; j++) {
      map[header[j]] = values[j];
    }
    result.add(map);
  }
  return result;
}
