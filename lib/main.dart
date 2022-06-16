import 'package:flutter/material.dart';
import 'package:flutter_web3/controllers/walletconnect_controller.dart';
import 'package:flutter_web3/screens/homescreen.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<WalletConnectController>(
          create: (_) => WalletConnectController(),
        ),
      ],
      child: const App(),
    ),
  );
}

class App extends StatelessWidget {
  const App({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const Homescreen(title: 'Flutter Demo Home Page'),
    );
  }
}
