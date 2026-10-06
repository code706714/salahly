import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';

/// Ways into buying uses from any screen.
extension BalanceNavigation on BuildContext {
  /// Opens the screen to buy uses. Once a transfer is sent, shows the
  /// balance so the person sees it waiting for review.
  Future<void> openBuyUses(UserRole role) async {
    final sent = await push<bool>(AppRoutes.buyUsesFor(role));
    if (sent ?? false) {
      if (mounted) unawaited(push<void>(AppRoutes.balanceFor(role)));
    }
  }
}
