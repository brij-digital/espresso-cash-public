import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../gen/assets.gen.dart';
import '../../../ui/colors.dart';
import '../../../ui/text_field.dart';
import '../../currency/models/currency.dart';
import '../../tokens/widgets/token_icon.dart';
import 'ramp_loader.dart';

class RampTextField extends StatelessWidget {
  const RampTextField({
    super.key,
    required this.currency,
    required this.controller,
    required this.label,
  });

  final String label;
  final Currency? currency;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    final logo = switch (currency) {
      FiatCurrency(:final countryCode) =>
        countryCode != null
            ? CountryFlag.fromCountryCode(
                countryCode,
                shape: const Circle(),
                width: 36.w,
                height: 36.h,
              )
            : _defaultLogo,
      CryptoCurrency(:final token) => TokenIcon(token: token, size: 40.w),
      _ => _defaultLogo,
    };

    final symbol = Text(
      currency?.symbol ?? '',
      style: TextStyle(fontSize: 34.sp, fontWeight: FontWeight.w700),
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 16.w, bottom: 6.h),
            child: Text(
              label,
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w500),
            ),
          ),
          if (controller == null)
            LoadingTextField(prefix: logo, suffix: symbol)
          else
            CpTextField(
              padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 24.w),
              controller: controller,
              inputType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.none,
              backgroundColor: CpColors.blackGreyColor,
              placeholder: '0',
              placeholderColor: Colors.white,
              textColor: Colors.white,
              fontSize: 34.sp,
              fontWeight: FontWeight.w700,
              prefix: Padding(padding: const EdgeInsets.only(left: 16), child: logo),
              readOnly: true,
              suffix: Padding(
                padding: EdgeInsets.only(right: 24.w),
                child: symbol,
              ),
            ),
        ],
      ),
    );
  }
}

Widget get _defaultLogo => CircleAvatar(
  maxRadius: 20.w,
  backgroundColor: CpColors.blackGreyColor,
  child: Assets.icons.money.svg(),
);
