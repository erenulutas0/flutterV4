// Stub file for non-web platforms
// This file provides empty implementations for web-only functions

dynamic initializeWebRTCForWeb(
  dynamic socket,
  String roomId,
  String? role,
  Function setState,
  dynamic context,
  bool mounted,
  Function(String) updateConnectionState,
  Function(bool) updateRemoteVideoReady,
) async {
  return null;
}

dynamic callWebRTCMethod(dynamic manager, String method, [List<dynamic>? args]) {
  return null;
}

dynamic jsifyForWeb(dynamic obj) {
  return obj;
}

