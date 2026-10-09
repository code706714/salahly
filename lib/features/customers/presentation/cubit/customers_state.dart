part of 'customers_cubit.dart';

/// The chips above the customers list.
enum CustomerFilter {
  all,

  /// Customers who owe money for finished work.
  owing,

  /// Customers who came through the platform.
  platform,

  /// Customers with a unit due for service within
  /// [CustomersState.cleaningWindowDays], or overdue.
  cleaningDue,
}

final class CustomersState extends Equatable {
  const CustomersState({
    required this.today,
    this.customers,
    this.query = '',
    this.filter = CustomerFilter.all,
    this.areaNames = const {},
  });

  /// How far ahead a service counts as coming up.
  static const cleaningWindowDays = 30;

  /// Local midnight of the current day.
  final DateTime today;

  /// Most recently active first; null until loaded.
  final List<CustomerSummary>? customers;
  final String query;

  /// The chip picked; see [activeFilter].
  final CustomerFilter filter;

  /// Area names by id, for searching by area.
  final Map<String, String> areaNames;

  bool get isLoading => customers == null;

  /// No customer was ever added.
  bool get isEmpty => customers?.isEmpty ?? false;

  /// The filter in effect: back to all once its chip has nobody left.
  CustomerFilter get activeFilter =>
      count(filter) == 0 ? CustomerFilter.all : filter;

  /// How many customers [filter] keeps, before searching.
  int count(CustomerFilter filter) => (customers ?? const [])
      .where((summary) => _keeps(filter, summary))
      .length;

  /// The customers to list: those the active filter keeps whose name,
  /// area, address or phone number match the search.
  List<CustomerSummary> get visible {
    final filter = activeFilter;
    final text = foldArabic(normalizeText(query) ?? '').toLowerCase();
    final digits = RegExp(r'^[\d\s+()-]+$').hasMatch(normalizeDigits(text))
        ? digitsOnly(text)
        : '';
    return [
      for (final summary in customers ?? const <CustomerSummary>[])
        if (_keeps(filter, summary) &&
            (text.isEmpty || _matches(summary.customer, text, digits)))
          summary,
    ];
  }

  bool _keeps(CustomerFilter filter, CustomerSummary summary) =>
      switch (filter) {
        CustomerFilter.all => true,
        CustomerFilter.owing => summary.owedPiastres > 0,
        CustomerFilter.platform =>
          summary.customer.source == CustomerSource.platform,
        CustomerFilter.cleaningDue => switch (summary.nextServiceOn) {
          final day? =>
            CalendarDate.daysBetween(today, day) <= cleaningWindowDays,
          null => false,
        },
      };

  bool _matches(Customer customer, String text, String digits) {
    final words = [
      customer.name,
      ?areaNames[customer.areaId],
      ?customer.address,
    ];
    if (words.any((word) => foldArabic(word).toLowerCase().contains(text))) {
      return true;
    }
    final phone = customer.phone;
    return digits.isNotEmpty &&
        phone != null &&
        ('0${phone.nationalNumber}'.contains(digits) ||
            phone.international.contains(digits));
  }

  CustomersState copyWith({
    DateTime? today,
    List<CustomerSummary>? customers,
    String? query,
    CustomerFilter? filter,
    Map<String, String>? areaNames,
  }) {
    return CustomersState(
      today: today ?? this.today,
      customers: customers ?? this.customers,
      query: query ?? this.query,
      filter: filter ?? this.filter,
      areaNames: areaNames ?? this.areaNames,
    );
  }

  @override
  List<Object?> get props => [today, customers, query, filter, areaNames];
}
