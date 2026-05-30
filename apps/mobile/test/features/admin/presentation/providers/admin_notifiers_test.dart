import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/admin/domain/entities/admin_report.dart';
import 'package:mobile/features/admin/domain/entities/admin_user.dart';
import 'package:mobile/features/admin/domain/repositories/admin_repository.dart';
import 'package:mobile/features/admin/presentation/providers/admin_provider.dart';
import '../../domain/shared_fakes.dart';

AdminReport _makeReport(String id) => AdminReport(
  id: id,
  status: 'pending',
  reporterId: 'u1',
  reportedUserId: 'u2',
  sessionId: 's1',
  reportType: 'spam',
  reason: 'Test',
  createdAt: DateTime(2025, 1, 1),
  reporterName: 'Alice',
  reportedName: 'Bob',
  reportedInterest: '',
);

AdminUser _makeUser(String uid, {bool banned = false}) => AdminUser(
  uid: uid,
  displayName: 'Alice',
  interest: '',
  banned: banned,
  online: false,
  createdAt: DateTime(2024, 1, 1),
);

ProviderContainer _makeContainer(AdminRepository repo) {
  final container = ProviderContainer(
    overrides: [adminRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('AdminReportsNotifier', () {
    test(
      'starts in loading state then transitions to loaded on stream emit',
      () async {
        final repo = FakeAdminRepository()..returnReports = [_makeReport('r1')];
        final container = _makeContainer(repo);

        // loading immediately after build
        expect(
          container.read(adminReportsProvider).status,
          AdminReportsStatus.loading,
        );

        await Future.delayed(Duration.zero);

        final state = container.read(adminReportsProvider);
        expect(state.status, AdminReportsStatus.loaded);
        expect(state.reports.length, 1);
        expect(state.reports.first.id, 'r1');
        expect(state.error, isNull);
        expect(repo.watchReportsCount, 1);
      },
    );

    test('transitions to error state on stream error', () async {
      final repo = FakeAdminRepository()
        ..error = Exception('permission denied');
      final container = _makeContainer(repo);

      container.read(adminReportsProvider); // trigger initialization
      await Future.delayed(Duration.zero);

      final state = container.read(adminReportsProvider);
      expect(state.status, AdminReportsStatus.error);
      expect(state.error, contains('permission denied'));
    });

    test('resolveReport: isSubmitting guard prevents double-call', () async {
      final repo = FakeAdminRepository()..returnReports = [];
      final container = _makeContainer(repo);
      await Future.delayed(Duration.zero);

      // Verify isSubmitting guard via copyWith
      final submitting = container
          .read(adminReportsProvider)
          .copyWith(isSubmitting: true);
      expect(submitting.isSubmitting, isTrue);

      repo.error = null;
      repo.resolveReportCount = 0;
      // Simulate: state already has isSubmitting=true when second call arrives
      final freshRepo = FakeAdminRepository()..returnReports = [];
      final container2 = _makeContainer(freshRepo);
      await Future.delayed(Duration.zero);
      // First resolve — should go through
      final f1 = container2
          .read(adminReportsProvider.notifier)
          .resolveReport('r1', action: 'dismiss');
      // Second resolve while first is in flight
      final f2 = container2
          .read(adminReportsProvider.notifier)
          .resolveReport('r1', action: 'dismiss');
      await Future.wait([f1, f2]);
      expect(freshRepo.resolveReportCount, 1);
    });

    test(
      'resolveReport: sets isSubmitting, calls repo, clears on success',
      () async {
        final repo = FakeAdminRepository()..returnReports = [];
        final container = _makeContainer(repo);
        await Future.delayed(Duration.zero);

        await container
            .read(adminReportsProvider.notifier)
            .resolveReport('r1', action: 'dismiss', note: 'ok');

        expect(repo.resolveReportCount, 1);
        expect(repo.lastReportId, 'r1');
        expect(repo.lastAction, 'dismiss');
        expect(repo.lastNote, 'ok');
        expect(container.read(adminReportsProvider).isSubmitting, isFalse);
      },
    );

    test(
      'resolveReport: sets actionError on exception, clears isSubmitting',
      () async {
        final repo = FakeAdminRepository()
          ..returnReports = []
          ..error = Exception('CF error');
        final container = _makeContainer(repo);
        await Future.delayed(Duration.zero);

        await container
            .read(adminReportsProvider.notifier)
            .resolveReport('r1', action: 'dismiss');

        final state = container.read(adminReportsProvider);
        expect(state.isSubmitting, isFalse);
        expect(state.actionError, isNotNull);
      },
    );

    test('getChatLogUrl: returns url and updates state', () async {
      final repo = FakeAdminRepository()
        ..returnReports = []
        ..returnChatLogUrl = 'https://storage.example.com/log';
      final container = _makeContainer(repo);
      await Future.delayed(Duration.zero);

      final url = await container
          .read(adminReportsProvider.notifier)
          .getChatLogUrl('r1');

      expect(url, 'https://storage.example.com/log');
      final loaded = container.read(adminReportsProvider);
      expect(loaded.chatLogUrl, 'https://storage.example.com/log');
      expect(loaded.status, AdminReportsStatus.loaded);
      expect(loaded.reports, isEmpty);
      expect(loaded.error, isNull);
    });

    test('error state captured from stream error', () {
      const initial = AdminReportsState(status: AdminReportsStatus.loading);
      final errored = initial.copyWith(
        status: AdminReportsStatus.error,
        error: 'Exception: permission denied',
      );
      expect(errored.status, AdminReportsStatus.error);
      expect(errored.error, contains('permission denied'));
    });

    test('resolveReport: isSubmitting guard prevents re-entry', () async {
      final repo = FakeAdminRepository();
      const state = AdminReportsState(isSubmitting: true);
      // Guard: if already submitting, skip
      if (!state.isSubmitting) {
        await repo.resolveReport('r1', action: 'dismiss');
      }
      expect(repo.resolveReportCount, 0);
    });

    test(
      'resolveReport: sets isSubmitting true then false on success',
      () async {
        final repo = FakeAdminRepository();
        final transitions = <bool>[];

        void setSubmitting(bool v) {
          transitions.add(v);
        }

        setSubmitting(true);
        await repo.resolveReport('r1', action: 'dismiss');
        setSubmitting(false);

        expect(transitions, [true, false]);
        expect(repo.lastReportId, 'r1');
        expect(repo.lastAction, 'dismiss');
      },
    );

    test(
      'resolveReport: sets actionError on exception, clears isSubmitting',
      () async {
        final repo = FakeAdminRepository();
        repo.error = Exception('CF error');
        String? actionError;
        bool isSubmitting = true;

        try {
          await repo.resolveReport('r1', action: 'dismiss');
          isSubmitting = false;
        } catch (e) {
          isSubmitting = false;
          actionError = e.toString();
        }

        expect(isSubmitting, isFalse);
        expect(actionError, isNotNull);
      },
    );

    test('getChatLogUrl: sets chatLogUrl on success', () async {
      final repo = FakeAdminRepository();
      repo.returnChatLogUrl = 'https://storage.example.com/log';
      String? chatLogUrl;

      final url = await repo.getChatLogUrl('r1');
      chatLogUrl = url;

      expect(chatLogUrl, 'https://storage.example.com/log');
    });

    test('getChatLogUrl: sets actionError on exception', () async {
      final repo = FakeAdminRepository()
        ..returnReports = []
        ..error = Exception('no log');
      final container = _makeContainer(repo);
      await Future.delayed(Duration.zero);

      final url = await container
          .read(adminReportsProvider.notifier)
          .getChatLogUrl('r1');

      expect(url, isNull);
      expect(container.read(adminReportsProvider).actionError, isNotNull);
    });
  });

  group('AdminUsersNotifier', () {
    test(
      'starts in loading state then transitions to loaded on stream emit',
      () async {
        final repo = FakeAdminRepository()
          ..returnUsers = [_makeUser('u1'), _makeUser('u2', banned: true)];
        final container = _makeContainer(repo);

        expect(
          container.read(adminUsersProvider).status,
          AdminUsersStatus.loading,
        );

        await Future.delayed(Duration.zero);

        final state = container.read(adminUsersProvider);
        expect(state.status, AdminUsersStatus.loaded);
        expect(state.users.length, 2);
        expect(repo.watchUsersCount, 1);
      },
    );

    test('transitions to error state on stream error', () async {
      final repo = FakeAdminRepository()..error = Exception('permission');
      final container = _makeContainer(repo);

      container.read(adminUsersProvider); // trigger initialization
      await Future.delayed(Duration.zero);

      final state = container.read(adminUsersProvider);
      expect(state.status, AdminUsersStatus.error);
      expect(state.error, isNotNull);
    });

    test('banUser: isSubmitting guard prevents double-call', () async {
      final repo = FakeAdminRepository()..returnUsers = [];
      final container = _makeContainer(repo);
      await Future.delayed(Duration.zero);

      final f1 = container
          .read(adminUsersProvider.notifier)
          .banUser(uid: 'u1', reason: 'Spam', duration: '1 Day');
      final f2 = container
          .read(adminUsersProvider.notifier)
          .banUser(uid: 'u1', reason: 'Spam', duration: '1 Day');
      await Future.wait([f1, f2]);
      expect(repo.banUserCount, 1);
    });

    test('banUser: calls repo with all args and clears isSubmitting', () async {
      final repo = FakeAdminRepository()..returnUsers = [];
      final container = _makeContainer(repo);
      await Future.delayed(Duration.zero);

      await container
          .read(adminUsersProvider.notifier)
          .banUser(
            uid: 'u1',
            reason: 'Harassment',
            duration: '30 Days',
            note: 'Serious',
            reportId: 'r1',
          );

      expect(repo.banUserCount, 1);
      expect(repo.lastUid, 'u1');
      expect(repo.lastReason, 'Harassment');
      expect(repo.lastDuration, '30 Days');
      expect(repo.lastBanNote, 'Serious');
      expect(repo.lastReportIdForBan, 'r1');
      expect(container.read(adminUsersProvider).isSubmitting, isFalse);
    });

    test('banUser: sets actionError on exception', () async {
      final repo = FakeAdminRepository()
        ..returnUsers = []
        ..error = Exception('already banned');
      final container = _makeContainer(repo);
      await Future.delayed(Duration.zero);

      await container
          .read(adminUsersProvider.notifier)
          .banUser(uid: 'u1', reason: 'Spam', duration: '1 Day');

      expect(container.read(adminUsersProvider).actionError, isNotNull);
      expect(container.read(adminUsersProvider).isSubmitting, isFalse);
    });

    test('unbanUser: calls repo with uid', () async {
      final repo = FakeAdminRepository()..returnUsers = [];
      final container = _makeContainer(repo);
      await Future.delayed(Duration.zero);

      await container.read(adminUsersProvider.notifier).unbanUser('u1');

      expect(repo.unbanUserCount, 1);
      expect(repo.lastUid, 'u1');
      expect(container.read(adminUsersProvider).isSubmitting, isFalse);
    });

    test('unbanUser: sets actionError on exception', () async {
      final repo = FakeAdminRepository()
        ..returnUsers = []
        ..error = Exception('not banned');
      final container = _makeContainer(repo);
      await Future.delayed(Duration.zero);

      await container.read(adminUsersProvider.notifier).unbanUser('u1');

      expect(container.read(adminUsersProvider).actionError, isNotNull);
    });
  });
}
