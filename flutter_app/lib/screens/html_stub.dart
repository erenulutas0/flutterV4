// Stub file for non-web platforms
class Blob {
  Blob(List<dynamic> data, [String? type]);
}

class Url {
  static String createObjectUrlFromBlob(Blob blob) => '';
  static void revokeObjectUrl(String url) {}
}

