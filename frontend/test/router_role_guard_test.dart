import 'package:flutter_test/flutter_test.dart';
import 'package:buildvox/models/user_model.dart';
import 'package:buildvox/router.dart';

UserModel _user({
  required String uid,
  required UserRole role,
  TradeType? trade,
}) {
  return UserModel(
    uid: uid,
    name: uid,
    email: '$uid@demo.com',
    role: role,
    trade: trade,
    companyId: null,
    assignedProjectIds: const [],
    assignedSiteIds: const [],
    fcmTokens: const [],
  );
}

void main() {
  group('homeRouteForUser', () {
    test('routes workers by trade shell first', () {
      expect(
        homeRouteForUser(
          _user(uid: 'e', role: UserRole.worker, trade: TradeType.electrical),
        ),
        '/electrician',
      );
      expect(
        homeRouteForUser(
          _user(uid: 'p', role: UserRole.worker, trade: TradeType.plumbing),
        ),
        '/plumber',
      );
      expect(
        homeRouteForUser(
          _user(uid: 'w', role: UserRole.worker, trade: TradeType.framing),
        ),
        '/worker',
      );
    });

    test('routes non-workers by role', () {
      expect(homeRouteForUser(_user(uid: 'gc', role: UserRole.gc)), '/gc');
      expect(
        homeRouteForUser(_user(uid: 'm', role: UserRole.manager)),
        '/manager',
      );
      expect(
        homeRouteForUser(_user(uid: 'a', role: UserRole.admin)),
        '/admin',
      );
    });
  });

  group('isAllowedRouteForUser', () {
    test('electrician is limited to electrician routes', () {
      final electrician = _user(
        uid: 'e',
        role: UserRole.worker,
        trade: TradeType.electrical,
      );
      expect(
        isAllowedRouteForUser(path: '/electrician', user: electrician),
        isTrue,
      );
      expect(
        isAllowedRouteForUser(path: '/electrician/task/1', user: electrician),
        isTrue,
      );
      expect(isAllowedRouteForUser(path: '/manager', user: electrician), isFalse);
      expect(isAllowedRouteForUser(path: '/gc', user: electrician), isFalse);
      expect(isAllowedRouteForUser(path: '/worker', user: electrician), isFalse);
    });

    test('plumber is limited to plumber routes', () {
      final plumber = _user(
        uid: 'p',
        role: UserRole.worker,
        trade: TradeType.plumbing,
      );
      expect(isAllowedRouteForUser(path: '/plumber', user: plumber), isTrue);
      expect(
        isAllowedRouteForUser(path: '/plumber/task/1', user: plumber),
        isTrue,
      );
      expect(isAllowedRouteForUser(path: '/manager', user: plumber), isFalse);
      expect(isAllowedRouteForUser(path: '/worker', user: plumber), isFalse);
    });

    test('generic worker is limited to worker routes', () {
      final worker = _user(
        uid: 'w',
        role: UserRole.worker,
        trade: TradeType.framing,
      );
      expect(isAllowedRouteForUser(path: '/worker', user: worker), isTrue);
      expect(isAllowedRouteForUser(path: '/worker/task/1', user: worker), isTrue);
      expect(isAllowedRouteForUser(path: '/electrician', user: worker), isFalse);
      expect(isAllowedRouteForUser(path: '/manager', user: worker), isFalse);
    });

    test('manager, gc, and admin are confined to their own shells', () {
      final manager = _user(uid: 'm', role: UserRole.manager);
      final gc = _user(uid: 'g', role: UserRole.gc);
      final admin = _user(uid: 'a', role: UserRole.admin);

      expect(isAllowedRouteForUser(path: '/manager', user: manager), isTrue);
      expect(
        isAllowedRouteForUser(path: '/manager/anything', user: manager),
        isTrue,
      );
      expect(isAllowedRouteForUser(path: '/gc', user: manager), isFalse);

      expect(isAllowedRouteForUser(path: '/gc', user: gc), isTrue);
      expect(isAllowedRouteForUser(path: '/manager', user: gc), isFalse);

      expect(isAllowedRouteForUser(path: '/admin', user: admin), isTrue);
      expect(isAllowedRouteForUser(path: '/manager', user: admin), isFalse);
    });
  });
}
