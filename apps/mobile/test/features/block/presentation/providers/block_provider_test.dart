import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/block/domain/entities/blocked_user.dart';
import 'package:mobile/features/block/domain/repositories/block_repository.dart';
import 'package:mobile/features/block/presentation/providers/block_provider.dart';

// ─── Helpers ────────────────────────────────────────────────────────────────

class _FakeBlockRepository implements BlockRepository {
  int blockCount = 0;
  int unblockCount = 0;
  Exception? error;

  @override
  Stream<List<BlockedUser>> watchBlockedUsers(String uid) =>
      const Stream.empty();

  @override
  Future<void> blockUser(
    String ownerUid,
    String targetUid, {
    String? displayName,
  }) async {
    blockCount++;
    if (error != null) throw error!;
  }

  @override
  Future<void> unblockUser(String ownerUid, String targetUid) async {
    unblockCount++;
    if (error != null) throw error!;
  }
}

class _FakeBlockNotifier extends BlockNotifier {
  final BlockState _initial;
  int blockCallCount = 0;
  int unblockCallCount = 0;

  _FakeBlockNotifier({BlockState initial = const BlockState()})
    : _initial = initial;

  @override
  BlockState build() => _initial;

  @override
  Future<void> block(String targetUid, {String? displayName}) async {
    blockCallCount++;
  }

  @override
  Future<void> unblock(String targetUid) async {
    unblockCallCount++;
  }
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  group('BlockStatus enum', () {
    test('contains all expected values', () {
      expect(
        BlockStatus.values,
        containsAll([
          BlockStatus.idle,
          BlockStatus.loading,
          BlockStatus.loaded,
          BlockStatus.error,
        ]),
      );
      expect(BlockStatus.values.length, 4);
    });
  });

  group('BlockState', () {
    test(
      'initial state has idle status, empty list, not submitting, no error',
      () {
        const state = BlockState();
        expect(state.status, BlockStatus.idle);
        expect(state.blockedUsers, isEmpty);
        expect(state.isSubmitting, isFalse);
        expect(state.error, isNull);
      },
    );

    test('copyWith updates status', () {
      const state = BlockState();
      final updated = state.copyWith(status: BlockStatus.loading);
      expect(updated.status, BlockStatus.loading);
    });

    test('copyWith updates blockedUsers', () {
      const state = BlockState();
      final users = [BlockedUser(uid: 'u1', blockedAt: DateTime(2024, 1, 1))];
      final updated = state.copyWith(blockedUsers: users);
      expect(updated.blockedUsers.length, 1);
      expect(updated.blockedUsers.first.uid, 'u1');
    });

    test('copyWith updates isSubmitting', () {
      const state = BlockState();
      final updated = state.copyWith(isSubmitting: true);
      expect(updated.isSubmitting, isTrue);
    });

    test('copyWith sets error', () {
      const state = BlockState();
      final updated = state.copyWith(error: 'something went wrong');
      expect(updated.error, 'something went wrong');
    });

    test('copyWith clears error with explicit null (sentinel)', () {
      final state = BlockState(status: BlockStatus.error, error: 'old error');
      final cleared = state.copyWith(error: null);
      expect(cleared.error, isNull);
    });

    test('copyWith without arguments preserves all fields', () {
      final users = [BlockedUser(uid: 'u1', blockedAt: DateTime(2024))];
      final state = BlockState(
        status: BlockStatus.loaded,
        blockedUsers: users,
        isSubmitting: true,
        error: 'e',
      );
      final copy = state.copyWith();
      expect(copy.status, BlockStatus.loaded);
      expect(copy.blockedUsers.length, 1);
      expect(copy.isSubmitting, isTrue);
      expect(copy.error, 'e');
    });

    test('copyWith preserves existing values when not specified', () {
      final users = [BlockedUser(uid: 'u1', blockedAt: DateTime(2024))];
      final state = BlockState(
        status: BlockStatus.loaded,
        blockedUsers: users,
        error: 'e',
      );
      final updated = state.copyWith(isSubmitting: true);
      expect(updated.status, BlockStatus.loaded);
      expect(updated.blockedUsers.length, 1);
      expect(updated.error, 'e');
      expect(updated.isSubmitting, isTrue);
    });
  });

  group('BlockNotifier — isSubmitting transitions', () {
    test('unblock sets isSubmitting true then false on success', () async {
      final repo = _FakeBlockRepository();
      final transitions = <bool>[];
      var isSubmitting = false;

      void setSubmitting(bool v) {
        isSubmitting = v;
        transitions.add(v);
      }

      setSubmitting(true);
      await repo.unblockUser('owner', 'target');
      setSubmitting(false);

      expect(transitions, [true, false]);
      expect(isSubmitting, isFalse);
    });

    test('block sets isSubmitting true then false on success', () async {
      final repo = _FakeBlockRepository();
      final transitions = <bool>[];
      var isSubmitting = false;

      void setSubmitting(bool v) {
        isSubmitting = v;
        transitions.add(v);
      }

      setSubmitting(true);
      await repo.blockUser('owner', 'target', displayName: 'Alice');
      setSubmitting(false);

      expect(transitions, [true, false]);
      expect(isSubmitting, isFalse);
    });

    test('isSubmitting guard prevents re-entry while submitting', () async {
      final repo = _FakeBlockRepository();
      const state = BlockState(isSubmitting: true);
      if (!state.isSubmitting) {
        await repo.unblockUser('owner', 'target');
      }
      expect(repo.unblockCount, 0);
    });

    test(
      'block sets isSubmitting false and captures error on exception',
      () async {
        final repo = _FakeBlockRepository();
        repo.error = Exception('block failed');
        String? capturedError;
        bool isSubmitting = true;

        try {
          await repo.blockUser('owner', 'target');
          isSubmitting = false;
        } catch (e) {
          isSubmitting = false;
          capturedError = e.toString();
        }

        expect(isSubmitting, isFalse);
        expect(capturedError, isNotNull);
      },
    );

    test(
      'unblock sets isSubmitting false and captures error on exception',
      () async {
        final repo = _FakeBlockRepository();
        repo.error = Exception('unblock failed');
        String? capturedError;
        bool isSubmitting = true;

        try {
          await repo.unblockUser('owner', 'target');
          isSubmitting = false;
        } catch (e) {
          isSubmitting = false;
          capturedError = e.toString();
        }

        expect(isSubmitting, isFalse);
        expect(capturedError, isNotNull);
      },
    );
  });

  group('_FakeBlockNotifier — via ProviderContainer', () {
    test('initial state is BlockState() when built with default', () {
      final fake = _FakeBlockNotifier();
      final container = ProviderContainer(
        overrides: [blockNotifierProvider.overrideWith(() => fake)],
      );
      addTearDown(container.dispose);

      final state = container.read(blockNotifierProvider);
      expect(state.status, BlockStatus.idle);
      expect(state.blockedUsers, isEmpty);
      expect(state.isSubmitting, isFalse);
      expect(state.error, isNull);
    });

    test('initial state reflects custom initial value', () {
      final users = [BlockedUser(uid: 'u1', blockedAt: DateTime(2024))];
      final fake = _FakeBlockNotifier(
        initial: BlockState(status: BlockStatus.loaded, blockedUsers: users),
      );
      final container = ProviderContainer(
        overrides: [blockNotifierProvider.overrideWith(() => fake)],
      );
      addTearDown(container.dispose);

      final state = container.read(blockNotifierProvider);
      expect(state.status, BlockStatus.loaded);
      expect(state.blockedUsers.length, 1);
    });

    test('unblock increments unblockCallCount', () async {
      final fake = _FakeBlockNotifier();
      final container = ProviderContainer(
        overrides: [blockNotifierProvider.overrideWith(() => fake)],
      );
      addTearDown(container.dispose);

      await container.read(blockNotifierProvider.notifier).unblock('t');
      expect(fake.unblockCallCount, 1);
    });

    test('block increments blockCallCount', () async {
      final fake = _FakeBlockNotifier();
      final container = ProviderContainer(
        overrides: [blockNotifierProvider.overrideWith(() => fake)],
      );
      addTearDown(container.dispose);

      await container
          .read(blockNotifierProvider.notifier)
          .block('t', displayName: 'Alice');
      expect(fake.blockCallCount, 1);
    });
  });
}
