import 'dart:async';
import 'package:dbus/dbus.dart';

class VenomNotification {
  final int id;
  final String appName;
  final String summary;
  final String body;
  final DateTime time;

  VenomNotification({
    required this.id,
    required this.appName,
    required this.summary,
    required this.body,
    required this.time,
  });
}

class VenomNotificationServer extends DBusObject {
  final StreamController<VenomNotification> _notificationStream = StreamController.broadcast();
  int _nextId = 1;

  VenomNotificationServer() : super(DBusObjectPath('/org/freedesktop/Notifications'));

  Stream<VenomNotification> get onNotification => _notificationStream.stream;

  @override
  // ignore: override_on_non_overriding_member
  List<DBusIntrospectInterface> get introspectInterfaces {
    return [
      DBusIntrospectInterface('org.freedesktop.Notifications', methods: [
        DBusIntrospectMethod('Notify', args: [
          // لاحظ استخدام .in_ بدلاً من .in
          DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.in_, name: 'app_name'),
          DBusIntrospectArgument(DBusSignature('u'), DBusArgumentDirection.in_, name: 'replaces_id'),
          DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.in_, name: 'app_icon'),
          DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.in_, name: 'summary'),
          DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.in_, name: 'body'),
          DBusIntrospectArgument(DBusSignature('as'), DBusArgumentDirection.in_, name: 'actions'),
          DBusIntrospectArgument(DBusSignature('a{sv}'), DBusArgumentDirection.in_, name: 'hints'),
          DBusIntrospectArgument(DBusSignature('i'), DBusArgumentDirection.in_, name: 'expire_timeout'),
          // لاحظ استخدام .out_ بدلاً من .out
          DBusIntrospectArgument(DBusSignature('u'), DBusArgumentDirection.out, name: 'id'),
        ]),
        DBusIntrospectMethod('GetCapabilities', args: [
          DBusIntrospectArgument(DBusSignature('as'), DBusArgumentDirection.out, name: 'caps'),
        ]),
        DBusIntrospectMethod('GetServerInformation', args: [
          DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.out, name: 'name'),
          DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.out, name: 'vendor'),
          DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.out, name: 'version'),
          DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.out, name: 'spec_version'),
        ]),
        DBusIntrospectMethod('CloseNotification', args: [
          DBusIntrospectArgument(DBusSignature('u'), DBusArgumentDirection.in_, name: 'id'),
        ]),
      ])
    ];
  }

  @override
  // ignore: avoid_renaming_method_parameters
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall method) async {
    if (method.interface == 'org.freedesktop.Notifications') {
      if (method.name == 'Notify') {
        return _handleNotify(method);
      } else if (method.name == 'GetCapabilities') {
        return DBusMethodSuccessResponse([DBusArray.string(['body', 'summary', 'actions'])]);
      } else if (method.name == 'GetServerInformation') {
        return DBusMethodSuccessResponse([
          DBusString('Venom Notification Server'),
          DBusString('VenomDE'),
          DBusString('1.0'),
          DBusString('1.2')
        ]);
      }
    }
    return DBusMethodErrorResponse.unknownMethod();
  }

  DBusMethodResponse _handleNotify(DBusMethodCall method) {
    final args = method.values;
    // يجب التأكد من أن القيم ليست فارغة قبل الوصول إليها لتجنب الأخطاء
    final appName = args.isNotEmpty && args[0] is DBusString ? (args[0] as DBusString).value : 'System';
    final summary = args.length > 3 && args[3] is DBusString ? (args[3] as DBusString).value : 'Notification';
    final body = args.length > 4 && args[4] is DBusString ? (args[4] as DBusString).value : '';
    
    final notification = VenomNotification(
      id: _nextId++,
      appName: appName.isEmpty ? 'System' : appName,
      summary: summary,
      body: body,
      time: DateTime.now(),
    );

    _notificationStream.add(notification);

    return DBusMethodSuccessResponse([DBusUint32(notification.id)]);
  }
}

Future<VenomNotificationServer> startNotificationServer() async {
  final client = DBusClient.session();
  final server = VenomNotificationServer();
  await client.registerObject(server);
  await client.requestName('org.freedesktop.Notifications', flags: {DBusRequestNameFlag.replaceExisting});
  return server;
}