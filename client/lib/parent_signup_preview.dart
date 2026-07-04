import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'main.dart' show GiggoApp;
import 'screens/parent_signup_screen.dart';
import 'services/gig_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final repository = GigRepository();
  runApp(
    GiggoApp(
      homeOverride: ParentSignUpScreen(
        repository: repository,
        parentEmail: 'parent@example.com',
        approvalToken: 'PREVIEW-TOKEN',
        childName: 'Sample Child',
        onAuthenticated: () {},
      ),
    ),
  );
}
