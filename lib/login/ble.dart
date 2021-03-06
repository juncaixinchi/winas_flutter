import 'dart:io' show Platform;
import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:connectivity/connectivity.dart';

const LOCAL_AUTH_SERVICE = '60000000-0182-406c-9221-0a6680bd0943';
const LOCAL_AUTH_SERVICE_INDICATE = '60000002-0182-406c-9221-0a6680bd0943';
const LOCAL_AUTH_SERVICE_WRITE = '60000003-0182-406c-9221-0a6680bd0943';
const NET_SETTING_SERVICE = '70000000-0182-406c-9221-0a6680bd0943';
const NET_SETTING_SERVICE_INDICATE = '70000002-0182-406c-9221-0a6680bd0943';
const NET_SETTING_SERVICE_WRITE = '70000003-0182-406c-9221-0a6680bd0943';
const CLOUD_SERVICE = '80000000-0182-406c-9221-0a6680bd0943';
const CLOUD_SERVICE_INDICATE = '80000002-0182-406c-9221-0a6680bd0943';
const CLOUD_SERVICE_WRITE = '80000003-0182-406c-9221-0a6680bd0943';

/// action of ble device
///
/// wifi: settting wifi
///
/// bind: bind new device
enum Action { wifi, bind }

/// get phone's current wifi's ssid
Future<String> getWifiSSID() async {
  if (Platform.isIOS) {
    LocationAuthorizationStatus status =
        await Connectivity().getLocationServiceAuthorization();
    if (status != LocationAuthorizationStatus.authorizedAlways &&
        status != LocationAuthorizationStatus.authorizedWhenInUse) {
      LocationAuthorizationStatus result =
          await Connectivity().requestLocationServiceAuthorization();
      if (result != LocationAuthorizationStatus.authorizedAlways &&
          result != LocationAuthorizationStatus.authorizedWhenInUse) {
        return null;
      }
    }
  }

  String ssid = await (Connectivity().getWifiName());
  if (ssid == '<unknown ssid>') throw 'Get Wifi SSID Failed';
  return ssid;
}

/// GetLocalAuth
///
/// Command to get color code: '{"action":"req","seq":1}';
///
/// Command to get auth token: '{"action":"auth","seq":2}';
Future getLocalAuth(BluetoothDevice device, String command) async {
  List<BluetoothService> services = await device.discoverServices();
  final localAuthService = services.firstWhere(
    (s) => s.uuid.toString() == LOCAL_AUTH_SERVICE,
    orElse: () => null,
  );

  final localAuthNotify = localAuthService.characteristics.firstWhere(
    (c) => c.uuid.toString() == LOCAL_AUTH_SERVICE_INDICATE,
    orElse: () => null,
  );

  final localAuthWrite = localAuthService.characteristics.firstWhere(
    (c) => c.uuid.toString() == LOCAL_AUTH_SERVICE_WRITE,
    orElse: () => null,
  );

  await localAuthNotify.setNotifyValue(true);

  final res = await writeDataAsync(
    command,
    device,
    localAuthNotify,
    localAuthWrite,
  );

  return res;
}

/// ConnectWifi
///
/// '{"action":"addAndActive", "seq": 123, "token": "0bf6abac423c54540a713870d54b16446fc8442a65e3a3bd2a1d7126f139b95c04368c83988381627284f7c561809ea2", "body":{"ssid":"Naxian800", "pwd":"vpai1228"}}';
Future connectWifi(BluetoothDevice device, String command) async {
  List<BluetoothService> services = await device.discoverServices();
  final localAuthService = services.firstWhere(
    (s) => s.uuid.toString() == NET_SETTING_SERVICE,
    orElse: () => null,
  );

  final localAuthNotify = localAuthService.characteristics.firstWhere(
    (c) => c.uuid.toString() == NET_SETTING_SERVICE_INDICATE,
    orElse: () => null,
  );

  final localAuthWrite = localAuthService.characteristics.firstWhere(
    (c) => c.uuid.toString() == NET_SETTING_SERVICE_WRITE,
    orElse: () => null,
  );

  await localAuthNotify.setNotifyValue(true);

  final json = await writeDataAsync(
    command,
    device,
    localAuthNotify,
    localAuthWrite,
  );

  return json;
}

class BleRes {
  Stream<List<int>> stream;
  Function onData;
  Function onError;
  StreamSubscription sub;

  BleRes(this.onData, this.onError);

  addStream(Stream<List<int>> s) {
    stream = s;
    sub = stream.listen(onData, onError: onError);
  }

  cancel() {
    sub?.cancel();
  }
}

Future<void> connectWifiAndBind(
    BluetoothDevice device, String command, BleRes bleRes) async {
  List<BluetoothService> services = await device.discoverServices();
  final netService = services.firstWhere(
    (s) => s.uuid.toString() == NET_SETTING_SERVICE,
    orElse: () => null,
  );

  final netNotify = netService.characteristics.firstWhere(
    (c) => c.uuid.toString() == NET_SETTING_SERVICE_INDICATE,
    orElse: () => null,
  );

  final netWrite = netService.characteristics.firstWhere(
    (c) => c.uuid.toString() == NET_SETTING_SERVICE_WRITE,
    orElse: () => null,
  );
  await netNotify.setNotifyValue(true);

  bleRes.addStream(netNotify.changedValue);

  await netWrite.write(command.codeUnits);
}

/// write data to BLE Characteristic
void writeData(
  String data,
  BluetoothDevice device,
  BluetoothCharacteristic notifyCharact,
  BluetoothCharacteristic writeCharact,
  Function callback,
) {
  bool fired = false;
  StreamSubscription<List<int>> listener;

  listener = notifyCharact.changedValue.listen((value) {
    if (!fired) {
      // filter noise value
      if (value is! List || value.length == 0) return;

      fired = true;
      listener.cancel();

      var res;
      try {
        if (value is! List || value.length == 0) {
          res = null;
        } else {
          res = jsonDecode(String.fromCharCodes(value));
        }
      } catch (e) {
        callback(e, null);
      }
      callback(null, res);
    }
  });

  writeCharact.write(data.codeUnits).catchError((error) {
    if (!fired) {
      fired = true;
      callback(error, null);
    }
  });
}

/// async funtion of writeData
Future writeDataAsync(
  String data,
  BluetoothDevice device,
  BluetoothCharacteristic notifyCharact,
  BluetoothCharacteristic writeCharact,
) async {
  Completer c = Completer();
  writeData(data, device, notifyCharact, writeCharact, (error, value) {
    if (error != null) {
      c.completeError(error);
    } else {
      c.complete(value);
    }
  });
  return c.future;
}
