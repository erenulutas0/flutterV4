import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../utils/backend_config.dart';

/// Service for checking grammar using backend JLanguageTool integration
class GrammarService {
  static final String _baseUrl = '${BackendConfig.baseUrl}/api/grammar';
  
  /// Check grammar for a single sentence
  /// 
  /// Returns a [GrammarCheckResult] with errors and suggestions
  /// 
  /// Example:
  /// ```dart
  /// final result = await GrammarService.checkGrammar("I goes to school");
  /// if (result.hasErrors) {
  ///   print("Found ${result.errors.length} errors");
  /// }
  /// ```
  static Future<GrammarCheckResult> checkGrammar(String sentence) async {
    if (sentence.trim().isEmpty) {
      return GrammarCheckResult.noError();
    }
    
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/check'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'sentence': sentence}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return GrammarCheckResult.fromJson(jsonDecode(response.body));
      } else {
        print('Check grammar failed: ${response.statusCode}');
        return GrammarCheckResult(
          hasErrors: false, 
          errorCount: 0, 
          errors: [], 
          message: 'Server error: ${response.statusCode}'
        );
      }
    } catch (e) {
      print('Check grammar error: $e');
      return GrammarCheckResult(
        hasErrors: false, 
        errorCount: 0, 
        errors: [], 
        message: 'Connection error' // Detay vermiyoruz UI bozulmasın
      );
    }
  }
  
  /// Check grammar for multiple sentences
  /// 
  /// Returns a map of sentence to list of errors
  static Future<Map<String, List<GrammarError>>> checkMultipleSentences(
    List<String> sentences,
  ) async {
    if (sentences.isEmpty) {
      return {};
    }
    
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/check-multiple'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'sentences': sentences}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final results = <String, List<GrammarError>>{};
        
        data.forEach((sentence, errors) {
          if (errors is List) {
            results[sentence] = errors
                .map((e) => GrammarError.fromJson(e as Map<String, dynamic>))
                .toList();
          }
        });
        
        return results;
      } else {
        return {};
      }
    } catch (e) {
      print('Multiple grammar check error: $e');
      return {};
    }
  }
  
  /// Get grammar checker status
  static Future<Map<String, dynamic>> getStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/status'),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('Grammar status check error: $e');
    }
    
    return {'enabled': false, 'error': 'Failed to get status'};
  }
}

/// Result of a grammar check operation
class GrammarCheckResult {
  final bool hasErrors;
  final int errorCount;
  final List<GrammarError> errors;
  final String? message;

  GrammarCheckResult({
    required this.hasErrors,
    required this.errorCount,
    required this.errors,
    this.message,
  });

  factory GrammarCheckResult.fromJson(Map<String, dynamic> json) {
    return GrammarCheckResult(
      hasErrors: json['hasErrors'] as bool? ?? false,
      errorCount: json['errorCount'] as int? ?? 0,
      errors: (json['errors'] as List?)
          ?.map((e) => GrammarError.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      message: json['message'] as String?,
    );
  }

  factory GrammarCheckResult.noError() {
    return GrammarCheckResult(
      hasErrors: false,
      errorCount: 0,
      errors: [],
    );
  }
  
  /// Check if result is valid (not a timeout or error)
  bool get isValid => message == null || !message!.contains('failed');
}

/// Represents a single grammar error
class GrammarError {
  final String message;
  final String shortMessage;
  final int fromPos;
  final int toPos;
  final List<String> suggestions;

  GrammarError({
    required this.message,
    required this.shortMessage,
    required this.fromPos,
    required this.toPos,
    required this.suggestions,
  });

  factory GrammarError.fromJson(Map<String, dynamic> json) {
    return GrammarError(
      message: json['message'] as String? ?? '',
      shortMessage: json['shortMessage'] as String? ?? '',
      fromPos: json['fromPos'] as int? ?? 0,
      toPos: json['toPos'] as int? ?? 0,
      suggestions: (json['suggestions'] as List?)
          ?.map((e) => e.toString())
          .toList() ?? [],
    );
  }
  
  /// Get the primary suggestion (first one)
  String? get primarySuggestion => 
      suggestions.isNotEmpty ? suggestions.first : null;
  
  /// Get display message (short if available, otherwise full)
  String get displayMessage => 
      shortMessage.isNotEmpty ? shortMessage : message;
  
  /// Length of the error span
  int get length => toPos - fromPos;
}

/// Debouncer for grammar checking
/// 
/// Usage:
/// ```dart
/// final debouncer = GrammarDebouncer(milliseconds: 1000);
/// 
/// textController.addListener(() {
///   debouncer.run(() async {
///     final result = await GrammarService.checkGrammar(textController.text);
///     // Handle result
///   });
/// });
/// ```
class GrammarDebouncer {
  final int milliseconds;
  Timer? _timer;

  GrammarDebouncer({this.milliseconds = 1000});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }
  
  void cancel() {
    _timer?.cancel();
  }
}

/// Callback type for void functions
typedef VoidCallback = void Function();
