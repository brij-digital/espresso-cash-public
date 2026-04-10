import 'dart:math';

import 'package:dfunc/dfunc.dart';
import 'package:flutter/material.dart';

import '../gen/assets.gen.dart';
import 'colors.dart';

typedef _AnimationTransformer = double Function(double value);

class CpTimelineItem {
  const CpTimelineItem({this.title, this.subtitle, this.trailing});

  final String? title;
  final String? subtitle;
  final String? trailing;
}

enum CpTimelineStatus { inProgress, success, failure, neutral }

class CpTimeline extends StatefulWidget {
  const CpTimeline({
    super.key,
    required this.items,
    required this.status,
    required this.active,
    required this.animated,
  }) : assert(items.length > 0, 'Items must not be empty'),
       assert(
         active >= 0 && active < items.length,
         'Active item must be in range [0, items.length)',
       );

  final List<CpTimelineItem> items;
  final CpTimelineStatus status;
  final int active;
  final bool animated;

  @override
  State<CpTimeline> createState() => _State();
}

class _State extends State<CpTimeline> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lastIconIndex = widget.status == CpTimelineStatus.inProgress && widget.animated
        ? widget.active - 1
        : widget.active;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.items.length,
      itemBuilder: (context, index) {
        final isFirst = index == 0;
        final isLast = index == widget.items.length - 1;

        _AnimationTransformer? indicatorTransformer;
        _AnimationTransformer? connectorTransformer;

        final isActive = index == widget.active;
        final isHighlighted = widget.animated && isActive;

        if (widget.animated) {
          if (isActive) {
            indicatorTransformer = _lowerIndicatorTransformer;
          } else if (index == widget.active - 1) {
            connectorTransformer = _connectorTransformer;
            indicatorTransformer = _upperIndicatorTransformer;
          }
        }

        return Row(
          key: ValueKey(index),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                _IndicatorBackground(
                  backgroundColor: widget.status.backgroundColor,
                  isFirst: isFirst,
                  isLast: isLast,
                  child: _Animation(
                    center: true,
                    controller: _controller,
                    transformer: indicatorTransformer,
                    child: Container(
                      height: _indicatorSize,
                      width: _indicatorSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isHighlighted || index > widget.active
                            ? Colors.white
                            : CpColors.deepGreyColor,
                      ),
                      child: index <= lastIconIndex
                          ? isActive
                                ? widget.status.icon
                                : _successIcon
                          : null,
                    ),
                  ),
                ),
                if (!isLast)
                  _ConnectorBackground(
                    backgroundColor: widget.status.backgroundColor,
                    child: _Animation(
                      center: false,
                      controller: _controller,
                      transformer: connectorTransformer,
                      child: Container(
                        height: _connectorHeight,
                        width: _connectorWidth,
                        color: index >= widget.active ? Colors.white : CpColors.deepGreyColor,
                      ),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: isFirst ? 16 : 0),
                child: _TileInfo(tile: widget.items[index]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TileInfo extends StatelessWidget {
  const _TileInfo({required this.tile});

  final CpTimelineItem tile;

  @override
  Widget build(BuildContext context) {
    final title = tile.title;
    final subtitle = tile.subtitle;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(title, style: _titleStyle),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 2)),
                ],
                if (subtitle != null) Text(subtitle, style: _subtitleStyle),
              ],
            ),
          ),
          Text(tile.trailing ?? '', style: _titleStyle),
        ],
      ),
    );
  }
}

class _IndicatorBackground extends StatelessWidget {
  const _IndicatorBackground({
    required this.child,
    required this.isFirst,
    required this.backgroundColor,
    required this.isLast,
  });

  final Widget child;
  final bool isFirst;
  final Color backgroundColor;
  final bool isLast;

  @override
  Widget build(BuildContext context) => Container(
    width: _timelineWidth,
    decoration: BoxDecoration(
      color: backgroundColor,
      border: Border.all(color: backgroundColor, width: 2),
      borderRadius: (isFirst || isLast)
          ? BorderRadius.vertical(
              top: isFirst ? _timelineRadius : Radius.zero,
              bottom: isLast ? _timelineRadius : Radius.zero,
            )
          : null,
      boxShadow: [
        BoxShadow(
          color: backgroundColor,
          blurRadius: 0.0,
          spreadRadius: 0.0,
          offset: const Offset(0, 1),
        ),
      ],
    ),
    padding: (isFirst || isLast)
        ? EdgeInsets.only(top: isFirst ? 16 : 2, bottom: isLast ? 16 : 2)
        : EdgeInsets.zero,
    margin: EdgeInsets.zero,
    child: SizedBox(height: _indicatorSize + _indicatorBounceOffset, child: child),
  );
}

class _ConnectorBackground extends StatelessWidget {
  const _ConnectorBackground({required this.backgroundColor, required this.child});

  final Color backgroundColor;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: _timelineWidth,
    height: _connectorHeight,
    decoration: BoxDecoration(
      color: backgroundColor,
      boxShadow: [
        BoxShadow(
          color: backgroundColor,
          blurRadius: 0.0,
          spreadRadius: 0.0,
          offset: const Offset(0, 1),
        ),
      ],
    ),
    child: child,
  );
}

class _Animation extends StatelessWidget {
  const _Animation({
    required this.transformer,
    required this.controller,
    required this.center,
    required this.child,
  });

  final AnimationController controller;
  final _AnimationTransformer? transformer;
  final bool center;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final transformer = this.transformer;

    return Stack(
      alignment: Alignment.center,
      children: [
        if (transformer != null)
          AnimatedBuilder(
            animation: controller,
            builder: (context, child) => Positioned(
              bottom: center ? 0 : null,
              top: controller.value.let(_sinoidalTransformer).let(transformer),
              // ignore: avoid-non-null-assertion, child is mandatory for parent
              child: child!,
            ),
            child: child,
          )
        else
          child,
      ],
    );
  }
}

extension on CpTimelineStatus {
  Color get backgroundColor => switch (this) {
    CpTimelineStatus.success => CpColors.successBackgroundColor,
    CpTimelineStatus.inProgress => CpColors.infoBackgroundColor,
    CpTimelineStatus.failure => CpColors.errorBackgroundColor,
    CpTimelineStatus.neutral => CpColors.neutralBackgroundColor,
  };

  Widget get icon {
    switch (this) {
      case CpTimelineStatus.failure:
        return _failIcon;
      case CpTimelineStatus.success:
      case CpTimelineStatus.inProgress:
      case CpTimelineStatus.neutral:
        return _successIcon;
    }
  }
}

final _successIcon = Padding(
  padding: const EdgeInsets.all(6.0),
  child: Assets.icons.timelineCheck.svg(),
);

final _failIcon = Padding(
  padding: const EdgeInsets.all(6.0),
  child: Assets.icons.timelineFail.svg(),
);

double _sinoidalTransformer(double value) => sin(2 * pi * value) / 2;

double _connectorTransformer(double value) => value * _connectorHeight;

double _lowerIndicatorTransformer(double value) => max(0, value) * _indicatorBounceOffset;

double _upperIndicatorTransformer(double value) => min(0, value) * _indicatorBounceOffset;

const _titleStyle = TextStyle(fontWeight: FontWeight.w500, fontSize: 16);
const _subtitleStyle = TextStyle(fontWeight: FontWeight.w400, fontSize: 14);
const _timelineRadius = Radius.circular(32);
const _timelineWidth = 65.0;
const _connectorHeight = 57.0;
const _connectorWidth = 9.0;
const _indicatorSize = 30.0;
const _indicatorBounceOffset = _indicatorSize * 0.3;
