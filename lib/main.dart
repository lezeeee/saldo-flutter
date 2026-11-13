import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SaldoApp());
}

// Configuração imutável: o estado financeiro pertence à HomeScreen.
class SaldoApp extends StatelessWidget {
  const SaldoApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Saldo • Seu dinheiro, com direção',
    debugShowCheckedModeBanner: false,
    locale: const Locale('pt', 'BR'),
    supportedLocales: const [Locale('pt', 'BR')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: appTheme,
    home: const HomeScreen(),
  );
}
