// Stub file for non-web platforms
// This file is used when dart:html is not available

class Blob {
  Blob(List<dynamic> data, [String? type]);
}

class Url {
  static String createObjectUrlFromBlob(Blob blob) => '';
  static void revokeObjectUrl(String url) {}
}

