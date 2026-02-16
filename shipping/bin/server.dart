import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:redis/redis.dart';
import 'package:uuid/uuid.dart';

final uuid = Uuid();

class ShippingService {
  final RedisConnection _redis;

  ShippingService(this._redis);

  Router get router {
    final router = Router();

    router.get('/health', (shelf.Request request) {
      return shelf.Response.ok(
        jsonEncode({'status': 'ok', 'service': 'shipping'}),
        headers: {'Content-Type': 'application/json'},
      );
    });

    router.post('/shipments', (shelf.Request request) async {
      final body = jsonDecode(await request.readAsString());
      final id = uuid.v4();
      final shipment = {
        'id': id,
        'order_id': body['order_id'],
        'address': body['address'],
        'status': 'LABEL_CREATED',
        'carrier': body['carrier'] ?? 'standard',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      final command = await _redis.open();
      await command.send_object(['SET', 'shipment:$id', jsonEncode(shipment)]);
      await command.send_object(['LPUSH', 'shipments:${body['order_id']}', id]);

      return shelf.Response(201,
        body: jsonEncode(shipment),
        headers: {'Content-Type': 'application/json'},
      );
    });

    router.get('/shipments/<id>', (shelf.Request request, String id) async {
      final command = await _redis.open();
      final result = await command.send_object(['GET', 'shipment:$id']);
      if (result == null) {
        return shelf.Response.notFound(
          jsonEncode({'error': 'shipment not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
      return shelf.Response.ok(result,
        headers: {'Content-Type': 'application/json'},
      );
    });

    router.patch('/shipments/<id>/status', (shelf.Request request, String id) async {
      final body = jsonDecode(await request.readAsString());
      final command = await _redis.open();
      final existing = await command.send_object(['GET', 'shipment:$id']);
      if (existing == null) {
        return shelf.Response.notFound(jsonEncode({'error': 'not found'}));
      }
      final shipment = jsonDecode(existing as String);
      shipment['status'] = body['status'];
      await command.send_object(['SET', 'shipment:$id', jsonEncode(shipment)]);
      return shelf.Response.ok(jsonEncode(shipment),
        headers: {'Content-Type': 'application/json'},
      );
    });

    return router;
  }
}

void main() async {
  final redisHost = Platform.environment['REDIS_HOST'] ?? 'localhost';
  final redisPort = int.parse(Platform.environment['REDIS_PORT'] ?? '6379');
  final port = int.parse(Platform.environment['PORT'] ?? '3011');

  final redis = RedisConnection();
  await redis.connect(redisHost, redisPort);

  final service = ShippingService(redis);
  final server = await io.serve(service.router, '0.0.0.0', port);
  print('Shipping service listening on :${server.port}');
}
