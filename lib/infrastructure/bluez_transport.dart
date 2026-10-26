import 'dart:async';
import 'dart:collection';

import 'package:bluez/bluez.dart';

import '../domain/models.dart';
import '../domain/protocol.dart';
import 'transport.dart';

class BluezTransport implements BoardTransport {
  final BlueZClient _client;
  final _changes = StreamController<bool>.broadcast();
  final _notifications = Queue<List<int>>();
  final _subscriptions = <StreamSubscription>[];
  final List<BlueZGattCharacteristic> _notifyChannels = [];
  final void Function(String, List<int>)? trace;
  BlueZDevice? _device;
  BlueZGattCharacteristic? _channel;
  bool _ready = false, _initialized = false, _ownsConnection = false;
  BluezTransport({this.trace, BlueZClient? client})
    : _client = client ?? BlueZClient();
  @override
  bool get connected => _ready && (_device?.connected ?? false);
  @override
  bool get isDemo => false;
  @override
  String? get address => _device?.address;
  @override
  String get name => _device?.name ?? 'EX201';
  @override
  Stream<bool> get connectionChanges => _changes.stream;

  Future<void> _init() async {
    if (_initialized) return;
    await _client.connect().timeout(const Duration(seconds: 10));
    _initialized = true;
  }

  bool _looksLikeControl(BlueZDevice d) =>
      d.uuids.any((u) => u.toString().toLowerCase() == controlService) ||
      (d.name.toLowerCase().contains('ex201') &&
          d.addressType == BlueZAddressType.random);
  @override
  Future<List<DiscoveredBoard>> scan() async {
    await _init();
    final powered = _client.adapters.where((a) => a.powered).toList();
    if (powered.isEmpty) {
      throw StateError('Turn Bluetooth on in Linux settings, then scan again.');
    }
    final started = <BlueZAdapter>[];
    try {
      for (final a in powered) {
        await a.setDiscoveryFilter(transport: 'le');
        await a.startDiscovery();
        started.add(a);
      }
      await Future<void>.delayed(const Duration(seconds: 5));
    } finally {
      for (final a in started) {
        try {
          await a.stopDiscovery();
        } catch (_) {}
      }
    }
    return _client.devices
        .where(_looksLikeControl)
        .map((d) => DiscoveredBoard(d.address, d.name, remembered: d.trusted))
        .toList();
  }

  @override
  Future<void> connect(String address) async {
    await _init();
    if (connected) {
      if (this.address != address) {
        throw StateError(
          'Disconnect the current board before selecting another.',
        );
      }
      return;
    }
    var matches = _client.devices
        .where((d) => d.address.toUpperCase() == address.toUpperCase())
        .toList();
    if (matches.isEmpty) {
      await scan();
      matches = _client.devices
          .where((d) => d.address.toUpperCase() == address.toUpperCase())
          .toList();
    }
    if (matches.length != 1) {
      throw StateError(
        'The control device is unavailable. Power it on and close other control apps, then scan again.',
      );
    }
    final device = matches.single;
    _ownsConnection = !device.connected;
    if (_ownsConnection) {
      await device.connect().timeout(const Duration(seconds: 20));
    }
    final timer = Stopwatch()..start();
    while (!device.servicesResolved) {
      if (timer.elapsed > const Duration(seconds: 20)) {
        throw TimeoutException('Bluetooth services were not resolved.');
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    final services = device.gattServices
        .where((s) => s.uuid.toString().toLowerCase() == controlService)
        .toList();
    if (services.isEmpty) {
      throw StateError(
        'This device has no EX201 AB00 control service. Select its BLE control address.',
      );
    }
    final channels = services.single.characteristics
        .where((c) => c.uuid.toString().toLowerCase() == controlChannel)
        .toList();
    if (channels.length != 1 ||
        !channels.single.flags.contains(BlueZGattCharacteristicFlag.read) ||
        !channels.single.flags.contains(BlueZGattCharacteristicFlag.write)) {
      throw StateError('The EX201 read/write characteristic is unavailable.');
    }
    _device = device;
    _channel = channels.single;
    _subscriptions.add(
      device.propertiesChanged.listen((keys) {
        if (keys.contains('Connected')) {
          if (!device.connected) _ready = false;
          _changes.add(connected);
        }
      }),
    );
    for (final c in services.single.characteristics) {
      if (c.flags.contains(BlueZGattCharacteristicFlag.notify) ||
          c.flags.contains(BlueZGattCharacteristicFlag.indicate)) {
        _subscriptions.add(
          c.propertiesChanged.listen((keys) {
            if (keys.contains('Value')) {
              final value = List<int>.of(c.value);
              _notifications.add(value);
              trace?.call('notify', value);
            }
          }),
        );
        await c.startNotify();
        _notifyChannels.add(c);
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
    _ready = true;
    _changes.add(true);
  }

  @override
  Future<void> send(List<int> command) async {
    if (!connected || _channel == null) {
      throw StateError('Connect an EX201 first.');
    }
    trace?.call('send', command);
    await _channel!
        .writeValue(command, type: BlueZGattCharacteristicWriteType.request)
        .timeout(const Duration(seconds: 5));
  }

  @override
  Future<List<int>> exchange(
    List<int> command, {
    int? selector,
    bool ack = false,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    _notifications.clear();
    await send(command);
    final timer = Stopwatch()..start();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    while (timer.elapsed < timeout) {
      final pending = <List<int>>[];
      while (_notifications.isNotEmpty) {
        pending.add(_notifications.removeFirst());
      }
      final read = await _channel!.readValue().timeout(
        const Duration(seconds: 4),
      );
      trace?.call('read', read);
      pending.add(read);
      for (final data in pending) {
        if (ack &&
            data.isNotEmpty &&
            data.first == command[2] &&
            data.skip(1).every((b) => b == 0)) {
          return data;
        }
        for (final reply in framesIn(data)) {
          if (reply[2] != command[2]) continue;
          if (selector != null && (reply[3] == 0 || reply[4] != selector)) {
            continue;
          }
          return reply;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    throw TimeoutException('No matching reply for ${hex(command)}');
  }

  @override
  Future<void> close() async {
    _ready = false;
    for (final c in _notifyChannels) {
      try {
        await c.stopNotify();
      } catch (_) {}
    }
    _notifyChannels.clear();
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
    // Only tear down a link this transport opened. Another control client may
    // already own the BlueZ device connection when this session attaches.
    if (_device != null && _ownsConnection) {
      try {
        await _device!.disconnect();
      } catch (_) {}
    }
    await _client.close();
    await _changes.close();
  }
}
