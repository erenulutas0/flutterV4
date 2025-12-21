// Stub file for non-web platforms
// This file is used when dart:js is not available

class JsObject {
  JsObject(dynamic constructor, List<dynamic> args);
  dynamic callMethod(String method, [List<dynamic>? args]) => null;
  static JsObject jsify(dynamic object) => JsObject(null, []);
}

class JsContext {
  dynamic operator [](String key) => null;
  void operator []=(String key, dynamic value) {}
  dynamic callMethod(String method, [List<dynamic>? args]) => null;
}

final context = JsContext();

dynamic allowInterop(Function f) => f;

