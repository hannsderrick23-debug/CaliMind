import 'package:flutter/material.dart';
import 'package:calimind/presentation/views/auth/auth_form_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const AuthFormScreen(isRegister: false);
}
