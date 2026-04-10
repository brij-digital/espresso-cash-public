import 'dart:async';

import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:rxdart/rxdart.dart';

import '../../../../../data/db/db.dart';
import '../../../../analytics/analytics_manager.dart';
import '../../../../ramp_partner/models/ramp_partner.dart';
import '../../../../ramp_partner/models/ramp_type.dart';
import '../../../data/my_database_ext.dart';
import '../../../models/ramp_watcher.dart';
import '../data/kado_api_client.dart';

@injectable
class KadoOffRampOrderWatcher implements RampWatcher {
  KadoOffRampOrderWatcher(this._db, this._client, this._analytics);

  final MyDatabase _db;
  final KadoApiClient _client;
  final AnalyticsManager _analytics;

  StreamSubscription<void>? _subscription;

  @override
  void watch(String orderId) {
    _subscription = Stream<void>.periodic(const Duration(seconds: 10))
        .startWith(null)
        .asyncMap((_) => _db.getWaitingForPartnerOffRampOrder(orderId))
        .whereNotNull()
        .asyncMap((order) => _client.getOrderStatus(order.partnerOrderId))
        .listen((event) async {
          // ignore: prefer-early-return, cannot use
          if (event.data case final data?) {
            final statement = _db.update(_db.offRampOrderRows)
              ..where(
                (tbl) =>
                    tbl.id.equals(orderId) &
                    tbl.status.equals(OffRampOrderStatus.waitingForPartner.name),
              );
            final isCompleted = data.machineStatusField == MachineStatus.settled;

            if (isCompleted) {
              await _subscription?.cancel();

              _analytics.rampCompleted(
                partnerName: RampPartner.kado.name,
                rampType: RampType.offRamp.name,
                id: orderId,
              );
            }

            await statement.write(
              OffRampOrderRowsCompanion(
                machineStatus: Value(data.machineStatusField.name),
                humanStatus: Value(data.humanStatusField),
                status: isCompleted
                    ? const Value(OffRampOrderStatus.completed)
                    : const Value(OffRampOrderStatus.waitingForPartner),
              ),
            );
          }
        });
  }

  @override
  void close() {
    _subscription?.cancel();
  }
}
