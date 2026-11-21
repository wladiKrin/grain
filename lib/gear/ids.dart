/// Lower-case [s]; every run of characters outside `[a-z0-9.]` becomes `-`;
/// leading/trailing `-` are trimmed; at most 64 characters.
String slugify(String s) {
  var out = s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9.]+'), '-');
  out = out.replaceAll(RegExp(r'^-+|-+$'), '');
  if (out.length > 64) {
    out = out.substring(0, 64).replaceAll(RegExp(r'-+$'), '');
  }
  return out;
}

/// [base] if free, else `base-2`, `base-3`, ... (the first free one).
String uniqueId(String base, Set<String> taken) {
  if (!taken.contains(base)) return base;
  for (var n = 2; ; n++) {
    final id = '$base-$n';
    if (!taken.contains(id)) return id;
  }
}
