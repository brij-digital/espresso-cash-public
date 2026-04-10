import 'package:ec_client_dart/ec_client_dart.dart';
import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../utils/errors.dart';
import '../../accounts/auth_scope.dart';

typedef AmbassadorStatus = ({bool isAmbassador, bool isReferral});

@Singleton(scope: authScope)
class AmbassadorService extends ValueNotifier<AmbassadorStatus> {
  AmbassadorService(this._ecClient, this._storage) : super(_defaultAmbassadorStatus);

  final EspressoCashClient _ecClient;
  final SharedPreferences _storage;

  @PostConstruct()
  void init() {
    final isAmbassador = _storage.getBool(_ambassadorKey) ?? false;
    final isReferral = _storage.getBool(_referralKey) ?? false;

    value = (isAmbassador: isAmbassador, isReferral: isReferral);

    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    try {
      final status = await _ecClient.verifyReferralStatus().then(
        (e) => (isAmbassador: e.isAmbassador, isReferral: e.isReferral),
      );
      _update(status);
    } on Exception catch (error) {
      reportError(error);
    }
  }

  void _update(AmbassadorStatus status) {
    value = status;

    _storage
      ..setBool(_ambassadorKey, status.isAmbassador)
      ..setBool(_referralKey, status.isReferral);
  }

  Future<void> addReferral(String ambassadorAddress) async {
    await _ecClient.addReferral(AmbassadorReferralRequestDto(ambassadorAddress: ambassadorAddress));

    _update((isAmbassador: value.isAmbassador, isReferral: true));
  }

  @disposeMethod
  @override
  void dispose() {
    _storage
      ..remove(_ambassadorKey)
      ..remove(_referralKey);

    super.dispose();
  }
}

const _defaultAmbassadorStatus = (isAmbassador: false, isReferral: false);

const _ambassadorKey = 'isAmbassador';
const _referralKey = 'isReferral';
