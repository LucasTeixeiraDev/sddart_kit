const _accents = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', //
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', //
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', //
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', //
  'ç': 'c', 'ñ': 'n',
};

final _nonAlnum = RegExp('[^a-z0-9]+');

/// Slug ASCII em minúsculas, com hífens, até [maxLength] caracteres
/// (cortado em limite de palavra quando possível).
String slugify(String title, {int maxLength = 50}) {
  final ascii = title
      .toLowerCase()
      .split('')
      .map((c) => _accents[c] ?? c)
      .join();
  var slug = ascii
      .replaceAll(_nonAlnum, '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (slug.length > maxLength) {
    final cut = slug.substring(0, maxLength);
    final lastDash = cut.lastIndexOf('-');
    slug = lastDash > maxLength ~/ 2 ? cut.substring(0, lastDash) : cut;
  }
  return slug.replaceAll(RegExp(r'-+$'), '');
}
