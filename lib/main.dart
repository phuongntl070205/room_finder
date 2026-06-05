import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'data/services/deep_link_service.dart';
import 'firebase_options.dart';
import 'presentation/pages/auth_wrapper.dart';
import 'presentation/pages/post_deep_link_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Room Finder Social',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
      onGenerateRoute: (settings) {
        final postId = DeepLinkService.postIdFromRouteName(settings.name);
        if (postId != null) {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => PostDeepLinkPage(postId: postId),
          );
        }
        return null;
      },
    );
  }
}
