import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web3/models/wallet_connect_registry_listing.dart';
import 'package:flutter_web3/utils/constants.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:walletconnect_dart/walletconnect_dart.dart';
import 'package:walletconnect_secure_storage/walletconnect_secure_storage.dart';

class WalletConnectController extends ChangeNotifier {
  late WalletConnect walletConnect;
  late String account;
  late int chainId;
  late BlockchainFlavor blockchainFlavor;
  String statusMessage = 'Initialized';
  late WalletConnectRegistryListing walletListing;

  Future<void> initWalletConnect() async {
    // Wallet Connect Session Storage - So we can persist connections
    final sessionStorage = WalletConnectSecureStorage();
    final session = await sessionStorage.getSession();

    // Create a connector
    walletConnect = WalletConnect(
      bridge: 'https://bridge.walletconnect.org',
      session: session,
      sessionStorage: sessionStorage,
      clientMeta: const PeerMeta(
        name: 'Flutter Rarible Demo',
        description: 'Flutter Rarible Protocol Demo App',
        url: 'https://www.rarible.org',
      ),
    );

    // Did we restore a session?
    if (session != null) {
      logger.w(
          "WalletConnect - Restored  v${session.version} session: ${session.accounts.length} account(s), bridge: ${session.bridge} connected: ${session.connected}, clientId: ${session.clientId}");

      if (session.connected) {
        logger.w(
            'WalletConnect - Attempting to reuse existing connection for chainId ${session.chainId} and wallet address ${session.accounts[0]}.');

        account = session.accounts[0];
        chainId = session.chainId;
        blockchainFlavor = BlockchainFlavorExtention.fromChainId(chainId);
        notifyListeners();
      }
    } else {
      logger.w(
          'WalletConnect - No existing sessions.  User needs to connect to a wallet.');
    }

    walletConnect.registerListeners(
      onConnect: (status) {
        // Status is updated, but session.peerinfo is not yet available.
        logger.d(
            'WalletConnect - onConnect - Established connection with  Wallet app: ${walletConnect.session.peerMeta?.name} -${walletConnect.session.peerMeta?.description}');

        statusMessage =
            'WalletConnect session established with ${walletConnect.session.peerMeta?.name} - ${walletConnect.session.peerMeta?.description}.';
        notifyListeners();
        // Did the user select a new chain?
        if (chainId != status.chainId) {
          logger.d(
              'WalletConnect - onConnect - Selected blockchain has changed: chainId: $chainId <- ${status.chainId})');

          chainId = status.chainId;
          blockchainFlavor = BlockchainFlavorExtention.fromChainId(chainId);
          notifyListeners();
        }

        // Did the user select a new wallet address?
        if (account != status.accounts[0]) {
          logger.d(
              'WalletConnect - onConnect - Selected wallet has changed: minter: $account <- ${status.accounts[0]}');

          account = status.accounts[0];
          notifyListeners();
        }
      },
      onSessionUpdate: (status) {
        // What information is available?
        //print('WalletConnect - Updated session. $status');

        logger.d(
            'WalletConnect - onSessionUpdate - Wallet ${walletConnect.session.peerMeta?.name} - ${walletConnect.session.peerMeta?.description}');

        statusMessage =
            'WalletConnect - SessionUpdate received with chainId ${status.chainId} and account ${status.accounts[0]}.';
        notifyListeners();

        // Did the user select a new chain?
        if (chainId != status.chainId) {
          logger.d(
              'WalletConnect - onSessionUpdate - Selected blockchain has changed: chainId: $chainId <- ${status.chainId}');

          chainId = status.chainId;
          blockchainFlavor = BlockchainFlavorExtention.fromChainId(chainId);
          notifyListeners();
        }

        // Did the user select a new wallet address?
        if (account != status.accounts[0]) {
          logger.d(
              'WalletConnect - onSessionUpdate - Selected wallet has changed: minter: $account <- ${status.accounts[0]}');

          account = status.accounts[0];
          notifyListeners();
        }
      },
      onDisconnect: () async {
        logger.d(
            'WalletConnect - onDisconnect - minter: $account <- "Please Connect Wallet"');

        account = 'Please Connect Wallet';
        statusMessage = 'WalletConnect session disconnected.';
        notifyListeners();
        await initWalletConnect();
      },
    );
  }

  Future<void> createWalletConnectSession(BuildContext context) async {
    // Create a new session
    if (walletConnect.connected) {
      statusMessage =
          'Already connected to ${walletConnect.session.peerMeta?.name} \n${walletConnect.session.peerMeta?.description}\n${walletConnect.session.peerMeta?.url}';
      logger.d(
          'createWalletConnectSession - WalletConnect Already connected to ${walletConnect.session.peerMeta?.name} with minter: $account, chainId $chainId. Ignored.');
      return;
    }

    // IOS users will need to be prompted which wallet to use.
    // if (Platform.isIOS) {
    //   List<WalletConnectRegistryListing> listings =
    //       await readWalletRegistry(limit: 4);

    //   await showModalBottomSheet(
    //     context: context,
    //     builder: (context) {
    //       return showIOSWalletSelectionDialog(
    //           context, listings, setWalletListing);
    //     },
    //     isScrollControlled: true,
    //     isDismissible: false,
    //     shape:
    //         RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
    //   );
    // }

    logger.d('createWalletConnectSession');
    SessionStatus session;
    try {
      session = await walletConnect.createSession(
          chainId: 1,
          onDisplayUri: (uri) async {
            // _displayUri = uri;
            logger.d('_displayUri updated with $uri');

            // Open any registered wallet via wc: intent
            bool? result;

            // IOS users have already chosen wallet, so customize the launcher
            if (Platform.isIOS) {
              uri =
                  '${walletListing.mobile.universal}/wc?uri=${Uri.encodeComponent(uri)}';
            }
            // Else
            // - Android users will choose their walled from the OS prompt

            logger.d('launching uri: $uri');
            try {
              result = await launchUrl(Uri.parse(uri),
                  mode: LaunchMode.externalApplication);
              if (result == false) {
                // launch alternative method
                logger.e(
                    'Initial launchuri failed. Fallback launch with forceSafariVC true');
                result = await launchUrl(Uri.parse(uri));
                if (result == false) {
                  logger.e('Could not launch $uri');
                }
              }
              if (result) {
                statusMessage = 'Launched wallet app, requesting session.';
                notifyListeners();
              }
            } on PlatformException catch (e) {
              if (e.code == 'ACTIVITY_NOT_FOUND') {
                logger.w('No wallets available - do nothing!');

                statusMessage =
                    'ERROR - No WalletConnect compatible wallets found.';
                notifyListeners();
                return;
              }
              logger.e('launch returned $result');
              logger.e(
                  'Unexpected PlatformException error: ${e.message}, code: ${e.code}, details: ${e.details}');
            } on Exception catch (e) {
              logger.e('launch returned $result');
              logger.e('url launcher other error e: $e');
            }
          });
    } catch (e) {
      logger.e('Unable to connect - killing the session on our side.');
      statusMessage = 'Unable to connect - killing the session on our side.';
      walletConnect.killSession();
      return;
    }
    if (session.accounts.isEmpty) {
      statusMessage =
          'Failed to connect to wallet.  Bridge Overloaded? Could not Connect?';

      // wc:f54c5bca-7712-4187-908c-9a92aa70d8db@1?bridge=https%3A%2F%2Fz.bridge.walletconnect.org&key=155ca05ffc2ab197772a5bd56a5686728f9fcc2b6eee5ffcb6fd07e46337888c
      logger.e(
          'Failed to connect to wallet.  Bridge Overloaded? Could not Connect?');
    }
  }
}
