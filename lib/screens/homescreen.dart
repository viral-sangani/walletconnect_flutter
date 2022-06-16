import 'package:flutter/material.dart';
import 'package:flutter_web3/controllers/walletconnect_controller.dart';
import 'package:flutter_web3/utils/constants.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class Homescreen extends StatefulWidget {
  const Homescreen({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen> with WidgetsBindingObserver {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<WalletConnectController>().initWalletConnect();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    WalletConnectController controller =
        context.read<WalletConnectController>();
    DateFormat dateFormat = DateFormat("HH:mm:ss");
    String dateString = dateFormat.format(DateTime.now());
    logger.d("$dateString AppLifecycleState: ${state.toString()}.");
    if (state == AppLifecycleState.resumed && mounted) {
      // If we have a configured connection but the websocket is down try once to reconnect
      if (controller.walletConnect.connected &&
          controller.walletConnect.bridgeConnected == false) {
        logger.w(
            '$dateString  Wallet connected, but transport is down.  Attempt to recover.');
        controller.walletConnect.reconnect();
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
    // Remove observer for app lifecycle changes.
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  Widget build(BuildContext context) {
    WalletConnectController controller =
        context.watch<WalletConnectController>();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              controller.statusMessage,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              "Connected Account - ${controller.account}",
              textAlign: TextAlign.center,
            ),
            TextButton(
              onPressed: () {
                controller.createWalletConnectSession(context);
              },
              child: const Text('Connect'),
            ),
            TextButton(
              onPressed: () {
                if (controller.walletConnect.connected) {
                  logger.d('Killing session');
                  controller.walletConnect.killSession();
                  setState(() {
                    controller.statusMessage = 'Wallet Disconnected';
                  });
                }
              },
              child: const Text("Disconnect"),
            )
          ],
        ),
      ),
    );
  }
}
