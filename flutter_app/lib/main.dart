import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'providers/word_provider.dart';
import 'providers/sentence_provider.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';
import 'utils/backend_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Emülatör tespitini başlat
  await BackendConfig.initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => WordProvider(apiService: ApiService()),
        ),
        ChangeNotifierProvider(
          create: (_) => SentenceProvider(apiService: ApiService()),
        ),
      ],
      child: MaterialApp(
        title: 'VocabMaster',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const HomeScreen(),
      ),
    );
  }
}

