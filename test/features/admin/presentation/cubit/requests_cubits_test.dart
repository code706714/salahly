import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/admin/domain/entities/admin_complaint.dart';
import 'package:salahly/features/admin/domain/entities/admin_request.dart';
import 'package:salahly/features/admin/domain/entities/paged_result.dart';
import 'package:salahly/features/admin/presentation/cubit/action_cubit.dart';
import 'package:salahly/features/admin/presentation/cubit/complaints_cubit.dart';
import 'package:salahly/features/admin/presentation/cubit/paged_cubit.dart';
import 'package:salahly/features/admin/presentation/cubit/requests_cubit.dart';

import '../../../../helpers/admin_fixtures.dart';
import '../../../../helpers/admin_harness.dart';
import '../../../../helpers/admin_mocks.dart';

void main() {
  late MockRequestsRepository requests;
  late MockUsersRepository users;

  setUpAll(AdminHarness.registerFallbacks);
  setUp(() {
    requests = MockRequestsRepository();
    users = MockUsersRepository();
  });

  group('RequestsCubit', () {
    blocTest<RequestsCubit, PagedState<AdminRequest, RequestFilter>>(
      'starts with the last 7 days',
      setUp: () =>
          when(
            () => requests.fetchRequests(
              any(),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            ),
          ).thenAnswer(
            (_) async => Ok(PagedResult(items: [testAdminRequest()], total: 1)),
          ),
      build: () => RequestsCubit(requests),
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        expect(cubit.state.items, [testAdminRequest()]);
        verify(
          () => requests.fetchRequests(
            const RequestFilter(),
            limit: adminPageSize,
            offset: 0,
          ),
        ).called(1);
      },
    );

    blocTest<RequestsCubit, PagedState<AdminRequest, RequestFilter>>(
      'searches and narrows from the first page',
      setUp: () =>
          when(
            () => requests.fetchRequests(
              any(),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            ),
          ).thenAnswer(
            (_) async => const Ok(PagedResult(items: [], total: 0)),
          ),
      build: () => RequestsCubit(requests),
      act: (cubit) => cubit.filterChanged(
        const RequestFilter(
          search: 'R-1048',
          areaId: 'shubra',
          status: AdminRequestStatus.noOffers,
          days: null,
        ),
      ),
      verify: (_) => verify(
        () => requests.fetchRequests(
          const RequestFilter(
            search: 'R-1048',
            areaId: 'shubra',
            status: AdminRequestStatus.noOffers,
            days: null,
          ),
          limit: adminPageSize,
          offset: 0,
        ),
      ).called(1),
    );
  });

  group('ComplaintsCubit', () {
    blocTest<ComplaintsCubit, PagedState<AdminComplaint, ComplaintFilter>>(
      'starts with the open complaints',
      setUp: () =>
          when(
            () => requests.fetchComplaints(
              any(),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            ),
          ).thenAnswer(
            (_) async => Ok(PagedResult(items: [testComplaint()], total: 1)),
          ),
      build: () => ComplaintsCubit(requests),
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        expect(cubit.state.items, [testComplaint()]);
        verify(
          () => requests.fetchComplaints(
            ComplaintFilter.open,
            limit: adminPageSize,
            offset: 0,
          ),
        ).called(1);
      },
    );
  });

  group('ComplaintActionsCubit', () {
    ComplaintActionsCubit build() => ComplaintActionsCubit(
      requestsRepository: requests,
      usersRepository: users,
    );

    blocTest<ComplaintActionsCubit, ActionState>(
      'closes a complaint with the note kept for the team',
      setUp: () => when(
        () => requests.resolveComplaint('complaint-1', 'كلمنا الفني'),
      ).thenAnswer((_) async => const Ok(null)),
      build: build,
      act: (cubit) => cubit.resolve('complaint-1', 'كلمنا الفني'),
      expect: () => const [
        ActionState(isBusy: true),
        ActionState(completed: 1, outcome: AdminOutcome.complaintResolved),
      ],
    );

    blocTest<ComplaintActionsCubit, ActionState>(
      'suspends the technician the complaint is about',
      setUp: () => when(
        () => users.suspend('tech-9', 'شكاوي متكررة'),
      ).thenAnswer((_) async => const Ok(null)),
      build: build,
      act: (cubit) => cubit.suspendTechnician('tech-9', 'شكاوي متكررة'),
      expect: () => const [
        ActionState(isBusy: true),
        ActionState(completed: 1, outcome: AdminOutcome.userSuspended),
      ],
    );
  });
}
