import 'dart:io';

import 'package:sharely_core/src/pairing/lan_address.dart';
import 'package:sharely_core/src/security/tls_identity.dart';
import 'package:sharely_core/src/server/pairing_request_handler.dart';
import 'package:sharely_core/src/server/request_authenticator.dart';
import 'package:sharely_core/src/server/transfer_receiver.dart';
import 'package:sharely_core/src/server/transfer_sender.dart';
import 'package:sharely_core/src/transfer/transfer_paths.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

const defaultSharelyPort = 53891;

/// Unauthenticated: the laptop's public identity, for finding it by code.
const helloPath = '/v1/hello';

/// Routes that only paired devices may use.
typedef TransferRoutes = ({
  TransferReceiver receiver,
  TransferSender sender,
  PairedDeviceLookup findPairedDevice,
});

/// The laptop's embedded HTTPS server, bound to one LAN address only.
class SharelyServer {
  new _(this._server);

  final HttpServer _server;

  InternetAddress get address => _server.address;

  int get port => _server.port;

  /// Starts on [preferredPort], or any free port if that one is taken;
  /// the QR code carries whichever port was actually bound.
  static Future<SharelyServer> start({
    required InternetAddress address,
    required PairingRequestHandler pairingHandler,
    required TlsIdentity identity,
    TransferRoutes? transfers,
    int preferredPort = defaultSharelyPort,
  }) async {
    final router = Router()
      ..get(helloPath, pairingHandler.handleHello)
      ..post('/v1/pair', pairingHandler.handle);
    if (transfers != null) _addTransferRoutes(router, transfers);
    final handler = const Pipeline()
        .addMiddleware(_localNetworkOnly)
        .addMiddleware(_noStoreHeaders)
        .addHandler(router.call);
    HttpServer server;
    try {
      server = await _serve(handler, address, preferredPort, identity);
    } on SocketException {
      server = await _serve(handler, address, 0, identity);
    }
    return SharelyServer._(server);
  }

  Future<void> stop() => _server.close(force: true);

  static Future<HttpServer> _serve(
    Handler handler,
    InternetAddress address,
    int port,
    TlsIdentity identity,
  ) async {
    final server = await shelf_io.serve(
      handler,
      address,
      port,
      securityContext: identity.createServerContext(),
      poweredByHeader: null,
    );
    server.idleTimeout = const Duration(seconds: 30);
    return server;
  }
}

void _addTransferRoutes(Router router, TransferRoutes transfers) {
  final pairedOnly = const Pipeline().addMiddleware(
    requirePairedDevice(transfers.findPairedDevice),
  );
  router
    ..get(
      controlChannelPath,
      pairedOnly.addHandler(transfers.receiver.hub.handleUpgrade),
    )
    ..put(
      '/v1/transfers/<transferId>/<fileIndex>',
      pairedOnly.addHandler(transfers.receiver.handleUpload),
    )
    ..get(
      '/v1/transfers/<transferId>/<fileIndex>/offset',
      pairedOnly.addHandler(transfers.receiver.handleOffset),
    )
    ..get(
      '/v1/transfers/<transferId>/<fileIndex>',
      pairedOnly.addHandler(transfers.sender.handleDownload),
    );
}

Handler _localNetworkOnly(Handler inner) {
  return (request) {
    final connection = request.context['shelf.io.connection_info'];
    if (connection is HttpConnectionInfo &&
        !isLocalNetworkPeer(connection.remoteAddress)) {
      return Response.forbidden(null);
    }
    return inner(request);
  };
}

Handler _noStoreHeaders(Handler inner) {
  return (request) async {
    final response = await inner(request);
    return response.change(headers: {'cache-control': 'no-store'});
  };
}
