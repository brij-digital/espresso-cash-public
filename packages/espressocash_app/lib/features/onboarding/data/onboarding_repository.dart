import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../accounts/auth_scope.dart';
import '../../accounts/models/account.dart';
import '../../profile/data/profile_repository.dart';

@Singleton(scope: authScope)
class OnboardingRepository extends ChangeNotifier {
  OnboardingRepository(this._storage, this._profileRepository, this._account) {
    _profileRepository.addListener(_handleProfileUpdated);
  }

  final SharedPreferences _storage;
  final ProfileRepository _profileRepository;
  final MyAccount _account;

  @PostConstruct()
  void init() {
    if (_storage.getBool(_ofacCheckPerformedKey) != true) {
      final currentCountry = _profileRepository.country;

      if (_ofacBlockedCountries.contains(currentCountry)) {
        _profileRepository.country = null;
      }

      _storage.setBool(_ofacCheckPerformedKey, true);
    }

    if (_account.accessMode == const AccessMode.seedInputted() && !hasConfirmedPassphrase) {
      hasConfirmedPassphrase = true;
    }
  }

  void _handleProfileUpdated() => notifyListeners();

  bool get hasFinishedOnboarding => _profileRepository.hasAllRequiredFields;

  bool get hasConfirmedPassphrase => _storage.getBool(_passphraseConfirmedKey) ?? false;

  set hasConfirmedPassphrase(bool value) {
    _storage.setBool(_passphraseConfirmedKey, value);
    notifyListeners();
  }

  @override
  @disposeMethod
  void dispose() {
    _profileRepository.removeListener(_handleProfileUpdated);
    _storage.remove(_passphraseConfirmedKey);
    super.dispose();
  }
}

const _passphraseConfirmedKey = 'passphraseConfirmed';
const _ofacCheckPerformedKey = 'ofacCheckPerformed';

const _ofacBlockedCountries = {
  'BY', 'CU', 'IR', 'KP', 'SD', 'SO', 'SY', 'RU', 'YE', //
};
