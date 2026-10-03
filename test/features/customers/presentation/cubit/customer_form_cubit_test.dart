import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/features/customers/domain/entities/customer.dart';
import 'package:salahly/features/customers/domain/entities/customer_summary.dart';
import 'package:salahly/features/customers/presentation/cubit/customer_form_cubit.dart';

import '../../../../helpers/customer_fixtures.dart';
import '../../../../helpers/mocks.dart';

void main() {
  late MockCustomersRepository customers;
  late MockContactPicker contacts;

  final karim = testCustomer(
    areaId: 'heliopolis',
    address: '7 شارع الحجاز',
    notes: 'بيحب المعاد بعد الضهر',
  );
  final phone = PhoneNumber.tryParse('01228703314')!;

  setUpAll(() {
    registerFallbackValue(phone);
    registerFallbackValue(const CustomerDraft(name: ''));
  });

  setUp(() {
    customers = MockCustomersRepository();
    contacts = MockContactPicker();
    when(() => customers.findByPhone(any())).thenAnswer((_) async => null);
    when(
      () => customers.watchCustomer('customer-1'),
    ).thenAnswer(
      (_) => Stream.value(CustomerRecord(customer: karim, units: const [])),
    );
  });

  CustomerFormCubit build({String? customerId, bool fromContacts = false}) =>
      CustomerFormCubit(
        customers: customers,
        contacts: contacts,
        customerId: customerId,
        fromContacts: fromContacts,
      );

  CustomerFormCubit editing() => build()
    ..emit(
      const CustomerFormState(
        isEditing: false,
        status: CustomerFormStatus.editing,
      ),
    );

  group('load', () {
    blocTest<CustomerFormCubit, CustomerFormState>(
      'starts a new customer empty',
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [
        const CustomerFormState(
          isEditing: false,
          status: CustomerFormStatus.editing,
        ),
      ],
    );

    blocTest<CustomerFormCubit, CustomerFormState>(
      'fills in the customer being edited',
      build: () => build(customerId: 'customer-1'),
      act: (cubit) => cubit.load(),
      expect: () => [
        const CustomerFormState(
          isEditing: true,
          status: CustomerFormStatus.editing,
          name: 'أ. كريم منصور',
          phoneText: '01228703314',
          areaId: 'heliopolis',
          address: '7 شارع الحجاز',
          notes: 'بيحب المعاد بعد الضهر',
        ),
      ],
    );

    blocTest<CustomerFormCubit, CustomerFormState>(
      'closes when the customer to edit is gone',
      setUp: () => when(
        () => customers.watchCustomer('customer-9'),
      ).thenAnswer((_) => Stream.value(null)),
      build: () => build(customerId: 'customer-9'),
      act: (cubit) => cubit.load(),
      expect: () => [
        const CustomerFormState(
          isEditing: true,
          status: CustomerFormStatus.cancelled,
        ),
      ],
    );

    blocTest<CustomerFormCubit, CustomerFormState>(
      'closes when the customer cannot be read',
      setUp: () => when(
        () => customers.watchCustomer('customer-9'),
      ).thenAnswer((_) => Stream.error(StateError('db'))),
      build: () => build(customerId: 'customer-9'),
      act: (cubit) => cubit.load(),
      expect: () => [
        const CustomerFormState(
          isEditing: true,
          status: CustomerFormStatus.cancelled,
        ),
      ],
      errors: () => [isA<StateError>()],
    );
  });

  group('from contacts', () {
    blocTest<CustomerFormCubit, CustomerFormState>(
      'fills in the contact picked',
      setUp: () => when(contacts.pickPhoneNumber).thenAnswer(
        (_) async => (name: ' كريم   منصور ', phone: '+20 122 870 3314'),
      ),
      build: () => build(fromContacts: true),
      act: (cubit) => cubit.load(),
      expect: () => [
        const CustomerFormState(
          isEditing: false,
          status: CustomerFormStatus.editing,
          name: 'كريم منصور',
          phoneText: '01228703314',
          source: CustomerSource.contacts,
        ),
      ],
      verify: (_) => verify(() => customers.findByPhone(phone)).called(1),
    );

    blocTest<CustomerFormCubit, CustomerFormState>(
      'keeps a number that is not an Egyptian mobile for fixing',
      setUp: () => when(contacts.pickPhoneNumber).thenAnswer(
        (_) async => (name: 'م' * 70, phone: '02 2345 6789'),
      ),
      build: () => build(fromContacts: true),
      act: (cubit) => cubit.load(),
      expect: () => [
        CustomerFormState(
          isEditing: false,
          status: CustomerFormStatus.editing,
          name: 'م' * 60,
          phoneText: '0223456789',
          source: CustomerSource.contacts,
        ),
      ],
      verify: (_) => verifyNever(() => customers.findByPhone(any())),
    );

    blocTest<CustomerFormCubit, CustomerFormState>(
      'hands back the customer who already has the number',
      setUp: () {
        when(contacts.pickPhoneNumber).thenAnswer(
          (_) async => (name: 'كريم', phone: '01228703314'),
        );
        when(
          () => customers.findByPhone(phone),
        ).thenAnswer((_) async => karim);
      },
      build: () => build(fromContacts: true),
      act: (cubit) => cubit.load(),
      expect: () => [
        CustomerFormState(
          isEditing: false,
          status: CustomerFormStatus.saved,
          saved: karim,
        ),
      ],
    );

    blocTest<CustomerFormCubit, CustomerFormState>(
      'closes when no contact was picked',
      setUp: () => when(contacts.pickPhoneNumber).thenAnswer((_) async => null),
      build: () => build(fromContacts: true),
      act: (cubit) => cubit.load(),
      expect: () => [
        const CustomerFormState(
          isEditing: false,
          status: CustomerFormStatus.cancelled,
        ),
      ],
    );
  });

  group('fields', () {
    test('follow what is typed and picked', () {
      final cubit = editing()
        ..nameChanged('أ. كريم')
        ..phoneChanged('01228703314')
        ..areaChanged('heliopolis')
        ..addressChanged('7 شارع الحجاز')
        ..notesChanged('البواب عم رجب');

      expect(
        cubit.state.draft,
        CustomerDraft(
          name: 'أ. كريم',
          phone: phone,
          areaId: 'heliopolis',
          address: '7 شارع الحجاز',
          notes: 'البواب عم رجب',
        ),
      );
      cubit.areaChanged(null);
      expect(cubit.state.areaId, isNull);
    });

    test('accept no phone, or an Egyptian mobile in any digits', () {
      final cubit = editing();
      expect(cubit.state.isPhoneValid, isTrue);
      cubit.phoneChanged('٠١٢٢٨٧٠٣٣١٤');
      expect(cubit.state.phone, phone);
      cubit.phoneChanged('0122870');
      expect(cubit.state.isPhoneValid, isFalse);
    });
  });

  group('save', () {
    blocTest<CustomerFormCubit, CustomerFormState>(
      'points out a missing name or a wrong number',
      build: editing,
      act: (cubit) async {
        cubit.phoneChanged('0122');
        await cubit.save();
      },
      skip: 1,
      expect: () => [
        isA<CustomerFormState>()
            .having((state) => state.showErrors, 'showErrors', isTrue)
            .having((state) => state.isNameValid, 'isNameValid', isFalse)
            .having((state) => state.isPhoneValid, 'isPhoneValid', isFalse)
            .having(
              (state) => state.status,
              'status',
              CustomerFormStatus.editing,
            ),
      ],
      verify: (_) => verifyNever(() => customers.addCustomer(any())),
    );

    blocTest<CustomerFormCubit, CustomerFormState>(
      'adds the customer and hands them back',
      setUp: () => when(
        () => customers.addCustomer(any()),
      ).thenAnswer((_) async => Ok(karim)),
      build: editing,
      act: (cubit) async {
        cubit
          ..nameChanged('أ. كريم منصور')
          ..phoneChanged('01228703314');
        await cubit.save();
      },
      skip: 2,
      expect: () => [
        isA<CustomerFormState>().having(
          (state) => state.status,
          'status',
          CustomerFormStatus.saving,
        ),
        isA<CustomerFormState>()
            .having((state) => state.status, 'status', CustomerFormStatus.saved)
            .having((state) => state.saved, 'saved', karim),
      ],
      verify: (_) => verify(
        () => customers.addCustomer(
          CustomerDraft(name: 'أ. كريم منصور', phone: phone),
        ),
      ).called(1),
    );

    blocTest<CustomerFormCubit, CustomerFormState>(
      'adds a customer without a phone without looking for duplicates',
      setUp: () => when(
        () => customers.addCustomer(any()),
      ).thenAnswer((_) async => Ok(karim)),
      build: editing,
      act: (cubit) async {
        cubit.nameChanged('أ. كريم منصور');
        await cubit.save();
      },
      verify: (_) {
        verifyNever(() => customers.findByPhone(any()));
        verify(
          () => customers.addCustomer(
            const CustomerDraft(name: 'أ. كريم منصور'),
          ),
        ).called(1);
      },
    );

    blocTest<CustomerFormCubit, CustomerFormState>(
      'stops at a number another customer has, until it changes',
      setUp: () => when(
        () => customers.findByPhone(phone),
      ).thenAnswer((_) async => karim),
      build: editing,
      act: (cubit) async {
        cubit
          ..nameChanged('كريم')
          ..phoneChanged('01228703314');
        await cubit.save();
        cubit.phoneChanged('0122870331');
      },
      skip: 3,
      expect: () => [
        isA<CustomerFormState>()
            .having(
              (state) => state.status,
              'status',
              CustomerFormStatus.editing,
            )
            .having((state) => state.duplicate, 'duplicate', karim),
        isA<CustomerFormState>().having(
          (state) => state.duplicate,
          'duplicate',
          null,
        ),
      ],
      verify: (_) => verifyNever(() => customers.addCustomer(any())),
    );

    blocTest<CustomerFormCubit, CustomerFormState>(
      'says why adding failed',
      setUp: () => when(
        () => customers.addCustomer(any()),
      ).thenAnswer((_) async => const Err(UnexpectedFailure())),
      build: editing,
      act: (cubit) async {
        cubit.nameChanged('أ. كريم منصور');
        await cubit.save();
      },
      skip: 2,
      expect: () => [
        isA<CustomerFormState>()
            .having(
              (state) => state.status,
              'status',
              CustomerFormStatus.editing,
            )
            .having(
              (state) => state.failure,
              'failure',
              const UnexpectedFailure(),
            ),
      ],
    );

    blocTest<CustomerFormCubit, CustomerFormState>(
      'says so when looking for duplicates fails',
      setUp: () => when(
        () => customers.findByPhone(any()),
      ).thenThrow(StateError('db')),
      build: editing,
      act: (cubit) async {
        cubit
          ..nameChanged('أ. كريم منصور')
          ..phoneChanged('01228703314');
        await cubit.save();
      },
      skip: 3,
      expect: () => [
        isA<CustomerFormState>()
            .having(
              (state) => state.status,
              'status',
              CustomerFormStatus.editing,
            )
            .having(
              (state) => state.failure,
              'failure',
              isA<UnexpectedFailure>(),
            ),
      ],
    );

    blocTest<CustomerFormCubit, CustomerFormState>(
      'does nothing while saving',
      build: () => build()
        ..emit(
          const CustomerFormState(
            isEditing: false,
            status: CustomerFormStatus.saving,
          ),
        ),
      act: (cubit) => cubit.save(),
      expect: () => <CustomerFormState>[],
    );
  });

  group('edit', () {
    final renamed = testCustomer(name: 'أ. كريم');

    blocTest<CustomerFormCubit, CustomerFormState>(
      'saves the changes, keeping their own number, and hands them back',
      setUp: () {
        when(
          () => customers.findByPhone(phone),
        ).thenAnswer((_) async => karim);
        when(
          () => customers.updateCustomer(any(), any()),
        ).thenAnswer((_) async => const Ok(null));
        var reads = 0;
        when(() => customers.watchCustomer('customer-1')).thenAnswer(
          (_) => Stream.value(
            CustomerRecord(
              customer: reads++ == 0 ? karim : renamed,
              units: const [],
            ),
          ),
        );
      },
      build: () => build(customerId: 'customer-1'),
      act: (cubit) async {
        await cubit.load();
        cubit.nameChanged('أ. كريم');
        await cubit.save();
      },
      skip: 3,
      expect: () => [
        isA<CustomerFormState>()
            .having((state) => state.status, 'status', CustomerFormStatus.saved)
            .having((state) => state.saved, 'saved', renamed),
      ],
      verify: (_) => verify(
        () => customers.updateCustomer(
          'customer-1',
          CustomerDraft(
            name: 'أ. كريم',
            phone: phone,
            areaId: 'heliopolis',
            address: '7 شارع الحجاز',
            notes: 'بيحب المعاد بعد الضهر',
          ),
        ),
      ).called(1),
    );

    blocTest<CustomerFormCubit, CustomerFormState>(
      'says why saving the changes failed',
      setUp: () => when(
        () => customers.updateCustomer(any(), any()),
      ).thenAnswer((_) async => const Err(UnexpectedFailure())),
      build: () => build(customerId: 'customer-1'),
      act: (cubit) async {
        await cubit.load();
        await cubit.save();
      },
      skip: 2,
      expect: () => [
        isA<CustomerFormState>().having(
          (state) => state.failure,
          'failure',
          const UnexpectedFailure(),
        ),
      ],
    );

    blocTest<CustomerFormCubit, CustomerFormState>(
      'fails when the customer disappears while saving',
      setUp: () {
        when(
          () => customers.updateCustomer(any(), any()),
        ).thenAnswer((_) async => const Ok(null));
        var reads = 0;
        when(() => customers.watchCustomer('customer-1')).thenAnswer(
          (_) => Stream.value(
            reads++ == 0
                ? CustomerRecord(customer: karim, units: const [])
                : null,
          ),
        );
      },
      build: () => build(customerId: 'customer-1'),
      act: (cubit) async {
        await cubit.load();
        await cubit.save();
      },
      skip: 2,
      expect: () => [
        isA<CustomerFormState>().having(
          (state) => state.failure,
          'failure',
          const UnexpectedFailure(),
        ),
      ],
    );

    blocTest<CustomerFormCubit, CustomerFormState>(
      'deletes the customer',
      setUp: () => when(
        () => customers.deleteCustomer(any()),
      ).thenAnswer((_) async => const Ok(null)),
      build: () => build(customerId: 'customer-1'),
      act: (cubit) async {
        await cubit.load();
        await cubit.delete();
      },
      skip: 1,
      expect: () => [
        isA<CustomerFormState>().having(
          (state) => state.status,
          'status',
          CustomerFormStatus.deleting,
        ),
        isA<CustomerFormState>().having(
          (state) => state.status,
          'status',
          CustomerFormStatus.deleted,
        ),
      ],
      verify: (_) =>
          verify(() => customers.deleteCustomer('customer-1')).called(1),
    );

    blocTest<CustomerFormCubit, CustomerFormState>(
      'says why deleting failed',
      setUp: () => when(
        () => customers.deleteCustomer(any()),
      ).thenAnswer((_) async => const Err(UnexpectedFailure())),
      build: () => build(customerId: 'customer-1'),
      act: (cubit) async {
        await cubit.load();
        await cubit.delete();
      },
      skip: 2,
      expect: () => [
        isA<CustomerFormState>()
            .having(
              (state) => state.status,
              'status',
              CustomerFormStatus.editing,
            )
            .having(
              (state) => state.failure,
              'failure',
              const UnexpectedFailure(),
            ),
      ],
    );

    blocTest<CustomerFormCubit, CustomerFormState>(
      'cannot delete a customer not saved yet',
      build: editing,
      act: (cubit) => cubit.delete(),
      expect: () => <CustomerFormState>[],
      verify: (_) => verifyNever(() => customers.deleteCustomer(any())),
    );
  });
}
