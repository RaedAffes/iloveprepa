/// Maps a folder name to its asset icon. Unknown folders get the
/// generic folder image.
String folderIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('math')) return 'assets/icon/math.png';
  if (n.contains('physique')) return 'assets/icon/physique.png';
  if (n.contains('chimie')) return 'assets/icon/chimie.png';
  if (n.contains('info')) return 'assets/icon/info.png';
  if (n.contains('langage') || n.contains('langue') || n.contains('fran')) {
    return 'assets/icon/langage.png';
  }
  if (n.contains('sta')) return 'assets/icon/sta.png';
  if (n.contains('resume') || n.contains('résumé')) {
    return 'assets/icon/resume.png';
  }
  return 'assets/folder.png';
}