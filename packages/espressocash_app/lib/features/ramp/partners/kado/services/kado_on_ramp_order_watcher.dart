import 'dart:async';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:rxdart/rxdart.dart';

import '../../../../../data/db/db.dart';
import '../../../../analytics/analytics_manager.dart';
import '../../../../currency/models/currency.dart';
import '../../../../ramp_partner/models/ramp_partner.dart';
import '../../../../ramp_partner/models/ramp_type.dart';
import '../../../data/my_database_ext.dart';
import '../../../models/ramp_watcher.dart';
import '../data/kado_api_client.dart';

@injectable
class KadoOnRampOrderWatcher implements RampWatcher {
  KadoOnRampOrderWatcher(this._db, this._client, this._analytics);

  final MyDatabase _db;
  final KadoApiClient _client;
  final AnalyticsManager _analytics;

  StreamSubscription<void>? _subscription;

  @override
  void watch(String orderId) {
    _subscription = Stream<void>.periodic(const Duration(seconds: 10))
        .startWith(null)
        .asyncMap((_) => _db.getNonCompletedOnRampOrder(orderId))
        .whereNotNull()
        .asyncMap((order) => _client.getOrderStatus(order.partnerOrderId))
        .listen((event) async {
          // ignore: prefer-early-return, cannot use
          if (event.data case final data?) {
            final statement = _db.update(_db.onRampOrderRows)
              ..where((tbl) => tbl.id.equals(orderId) & tbl.isCompleted.equals(false));

            final isCompleted = data.machineStatusField == MachineStatus.settled;

            if (isCompleted) await _subscription?.cancel();

            OnRampOrderStatus? status;
            if (isCompleted) {
              status = OnRampOrderStatus.completed;

              _analytics.rampCompleted(
                partnerName: RampPartner.kado.name,
                rampType: RampType.onRamp.name,
                id: orderId,
              );
            } else if (data.machineStatusField == MachineStatus.achPaymentFailed ||
                data.machineStatusField == MachineStatus.cardPaymentFailed) {
              status = OnRampOrderStatus.failure;
            }

            await statement.write(
              OnRampOrderRowsCompanion(
                humanStatus: Value(data.humanStatusField),
                machineStatus: Value(data.machineStatusField.name),
                isCompleted: Value(isCompleted),
                status: Value.ofNullable(status),
                txHash: Value.ofNullable(data.txHash),
                receiveAmount: Value(
                  ((data.payAmount.amount - (data.totalFee?.amount ?? 0)) /
                          (data.quote?.price ?? 0) *
                          pow(10, Currency.usdc.decimals))
                      .toInt(),
                ),
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
