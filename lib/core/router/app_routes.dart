/// Paths of every screen, so navigation never relies on string literals.
abstract final class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const otp = '/login/otp';
  static const welcome = '/welcome';
  static const onboarding = '/onboarding';
  static const consumerOnboarding = '/onboarding/consumer';
  static const technicianOnboarding = '/onboarding/technician';
  static const consumerHome = '/consumer';
  static const consumerRequests = '/consumer/requests';
  static const consumerAccount = '/consumer/account';
  static const newRequest = '/consumer/requests/new';
  static const consumerAddresses = '/consumer/account/addresses';
  static const pastTechnicians = '/consumer/account/technicians';
  static const consumerTechnicians = '/consumer/technicians';
  static const technicianHome = '/technician';
  static const technicianJobs = '/technician/jobs';
  static const technicianCalendar = '/technician/jobs/calendar';
  static const newJob = '/technician/jobs/new';
  static const technicianCustomers = '/technician/customers';
  static const newCustomer = '/technician/customers/new';
  static const technicianMoney = '/technician/money';
  static const technicianAccount = '/technician/account';
  static const incomingRequests = '/technician/requests';
  static const sessionUnavailable = '/session-unavailable';
  static const legal = '/legal';
  static const terms = '/legal/terms';
  static const privacy = '/legal/privacy';

  /// A new request, optionally for [categoryId] or to [technicianId] first.
  static String newRequestFor({String? categoryId, String? technicianId}) {
    final query = {'category': ?categoryId, 'technician': ?technicianId};
    return query.isEmpty
        ? newRequest
        : Uri(path: newRequest, queryParameters: query).toString();
  }

  static String request(String id) => '$consumerRequests/$id';
  static String requestComplaint(String id) => '${request(id)}/complaint';
  static String technicianProfile(String id) => '$consumerTechnicians/$id';

  static String incomingRequest(String id) => '$incomingRequests/$id';

  static String job(String id) => '$technicianJobs/$id';
  static String jobQuote(String id) => '${job(id)}/quote';
  static String jobInvoice(String id) => '${job(id)}/invoice';

  /// A new job with the customer already picked.
  static String newJobFor(String customerId) =>
      Uri(path: newJob, queryParameters: {'customer': customerId}).toString();

  /// A new job with its visit already set to [scheduledAt], local time.
  static String newJobAt(DateTime scheduledAt) => Uri(
    path: newJob,
    queryParameters: {'at': scheduledAt.toIso8601String()},
  ).toString();

  static String customer(String id) => '$technicianCustomers/$id';
  static String editCustomer(String id) => '${customer(id)}/edit';

  /// A new customer, starting from the phone's contact picker.
  static final newCustomerFromContacts = Uri(
    path: newCustomer,
    queryParameters: {'from': 'contacts'},
  ).toString();
}
