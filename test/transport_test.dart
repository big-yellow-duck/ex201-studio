import 'dart:async';

import 'package:bluez/bluez.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ex201_studio/domain/protocol.dart';
import 'package:ex201_studio/infrastructure/bluez_transport.dart';

class FakeCharacteristic implements BlueZGattCharacteristic {
  @override
  BlueZUUID get uuid => BlueZUUID.fromString(controlChannel);
  @override
  Set<BlueZGattCharacteristicFlag> get flags => {
    BlueZGattCharacteristicFlag.read,
    BlueZGattCharacteristicFlag.write,
  };
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeService implements BlueZGattService {
  @override
  BlueZUUID get uuid => BlueZUUID.fromString(controlService);
  @override
  List<BlueZGattCharacteristic> get characteristics => [FakeCharacteristic()];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDevice implements BlueZDevice {
  bool state;
  int connects = 0, disconnects = 0;
  final events = StreamController<List<String>>.broadcast();
  FakeDevice(this.state);
  @override
  String get address => 'DE:00:00:00:00:01';
  @override
  String get name => 'EX201';
  @override
  bool get connected => state;
  @override
  bool get servicesResolved => true;
  @override
  List<BlueZGattService> get gattServices => [FakeService()];
  @override
  Stream<List<String>> get propertiesChanged => events.stream;
  @override
  Future<void> connect() async {
    connects++;
    state = true;
  }

  @override
  Future<void> disconnect() async {
    disconnects++;
    state = false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeClient implements BlueZClient {
  final FakeDevice device;
  FakeClient(this.device);
  @override
  Future<void> connect() async {}
  @override
  List<BlueZDevice> get devices => [device];
  @override
  Future<void> close() => device.events.close();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'Closing an attached session leaves another client’s BLE link connected',
    () async {
      final device = FakeDevice(true);
      final attached = BluezTransport(client: FakeClient(device));
      await attached.connect(device.address);
      expect(attached.connected, true);
      await attached.close();
      expect(device.connects, 0);
      expect(device.disconnects, 0);
      expect(device.state, true);
    },
  );
  test(
    'Closing a transport-owned session disconnects only its own BLE link',
    () async {
      final device = FakeDevice(false);
      final owned = BluezTransport(client: FakeClient(device));
      await owned.connect(device.address);
      expect(device.connects, 1);
      await owned.close();
      expect(device.disconnects, 1);
      expect(device.state, false);
    },
  );
}
