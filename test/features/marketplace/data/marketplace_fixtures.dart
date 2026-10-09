// JSON as the marketplace functions return it.

Map<String, dynamic> technicianCardJson({
  String id = 'tech-1',
  String name = 'محمود السيد',
}) => {
  'id': id,
  'name': name,
  'shop_name': null,
  'avatar_path': '$id/avatar.jpg',
  'years_experience': 12,
  'verified': true,
  'rating': 4.8,
  'review_count': 126,
  'jobs_done': 214,
};

Map<String, dynamic> offerJson({
  String id = 'offer-1',
  String status = 'sent',
  int price = 35000,
}) => {
  'id': id,
  'price_piastres': price,
  'arrive_at': '2026-10-03T09:00:00+00:00',
  'note': 'السعر شامل الكشف والتنظيف',
  'status': status,
  'distance_km': 2.4,
  'created_at': '2026-10-02T17:10:00+00:00',
  'technician': technicianCardJson(),
  'counter_price_piastres': null,
  'awaiting': 'consumer',
  'counters_left': 3,
};

Map<String, dynamic> requestDetailsJson({
  String status = 'assigned',
  List<Map<String, dynamic>>? offers,
  String? chosenOfferId = 'offer-1',
  Map<String, dynamic>? job,
  Map<String, dynamic>? review,
  String? arrivingAt,
}) => {
  'id': 'request-1',
  'category_id': 'ac',
  'issue': 'not_cooling',
  'description': 'التكييف شغال بس الهوا مش ساقع',
  'photo_paths': ['user-1/photo-1.jpg'],
  'area_id': 'nasr_city',
  'address_label': 'البيت',
  'address_details': '14 شارع عباس العقاد',
  'preferred_on': '2026-10-03',
  'time_window': 'noon',
  'expires_at': '2026-10-03T12:00:00+00:00',
  'status': status,
  'cancelled_by': null,
  'cancelled_at': null,
  'widened': false,
  'created_at': '2026-10-02T16:40:00+00:00',
  'chosen_at': '2026-10-02T17:05:00+00:00',
  'sent_to': 5,
  'seen_by': 3,
  'offers': offers ?? [offerJson(status: 'accepted')],
  'chosen_offer_id': chosenOfferId,
  'technician_phone': '+201009990041',
  'job': job,
  'review': review,
  'open_complaint': false,
  'technician_arriving_at': arrivingAt,
};

Map<String, dynamic> requestJobJson({
  String status = 'confirmed',
  String quoteStatus = 'sent',
}) => {
  'status': status,
  'scheduled_at': '2026-10-03T09:00:00+00:00',
  'confirmed_at': '2026-10-02T18:00:00+00:00',
  'started_at': null,
  'finished_at': null,
  'paid_at': null,
  'cancelled_at': null,
  'quote_status': quoteStatus,
  'quote_sent_at': '2026-10-03T09:35:00.123456+00:00',
  'invoice_number': null,
  'items': [
    {
      'title': 'كشف وتنظيف',
      'unit_price_piastres': 35000,
      'quantity': 1,
      'added_later': false,
    },
    {
      'title': 'شحن فريون جزئي',
      'unit_price_piastres': 30000,
      'quantity': 1,
      'added_later': true,
    },
  ],
  'total_piastres': 65000,
};

Map<String, dynamic> incomingRequestJson({
  Map<String, dynamic>? myOffer,
  int offerCount = 2,
}) => {
  'id': 'request-1',
  'category_id': 'ac',
  'issue': 'not_cooling',
  'description': 'التكييف شغال بس الهوا مش ساقع',
  'photo_paths': <String>[],
  'area_id': 'nasr_city',
  'distance_km': 2,
  'preferred_on': '2026-10-03',
  'time_window': 'noon',
  'expires_at': '2026-10-03T12:00:00+00:00',
  'created_at': '2026-10-02T16:40:00+00:00',
  'consumer_name': 'نورهان م.',
  'consumer_honorific': 'ms',
  'status': 'open',
  'sent_to': 5,
  'offer_count': offerCount,
  'dismissed': false,
  'my_offer': myOffer,
};

Map<String, dynamic> listingJson({
  String id = 'tech-1',
  String name = 'محمود السيد',
}) => {
  'id': id,
  'name': name,
  'avatar_path': '$id/avatar.jpg',
  'rating': 4.8,
  'review_count': 126,
  'years_experience': 12,
  'jobs_done': 214,
  'area_id': 'nasr_city',
  'area_ids': ['heliopolis', 'nasr_city'],
  'services': [
    {
      'service_id': 'plumbing_inspection',
      'category_id': 'plumbing',
      'name_ar': 'كشف وتحديد العطل',
      'starting_price_piastres': 15000,
    },
    {
      'service_id': 'ac_inspection',
      'category_id': 'ac',
      'name_ar': 'كشف',
      'starting_price_piastres': 12000,
    },
  ],
  'min_price_piastres': 12000,
};

Map<String, dynamic> publicProfileJson() => {
  ...listingJson(),
  'shop_name': 'ورشة السيد',
  'reviews': [
    {
      'stars': 5,
      'tags': ['on_time', 'unknown_tag'],
      'comment': 'شغل نضيف',
      'issue': 'plumbing_leak',
      'created_at': '2026-10-01T10:00:00+00:00',
    },
  ],
};

Map<String, dynamic> offerStateJson({
  String status = 'sent',
  int price = 35000,
  int? counter,
}) => {
  'offer_id': 'offer-1',
  'request_id': 'request-1',
  'status': status,
  'price_piastres': price,
  'counter_price_piastres': counter,
  'awaiting': counter == null ? 'consumer' : 'technician',
  'counters_left': 2,
  'revisions_left': 1,
};

Map<String, dynamic> offerThreadJson() => {
  'offer': offerStateJson(counter: 30000),
  'events': [
    {
      'kind': 'offer',
      'actor': 'technician',
      'price_piastres': 35000,
      'created_at': '2026-10-02T17:10:00+00:00',
    },
    {
      'kind': 'counter',
      'actor': 'consumer',
      'price_piastres': 30000,
      'created_at': '2026-10-02T17:20:00+00:00',
    },
    {
      'kind': 'withdraw',
      'actor': 'technician',
      'price_piastres': null,
      'created_at': '2026-10-02T17:30:00+00:00',
    },
  ],
};

Map<String, dynamic> offeringJson() => {
  'work_days': [6, 7, 1],
  'service_radius_km': 15,
  'base_area_id': 'nasr_city',
  'area_ids': ['heliopolis', 'nasr_city'],
  'services': [
    {'service_id': 'ac_inspection', 'starting_price_piastres': 12000},
    {'service_id': 'plumbing_inspection', 'starting_price_piastres': 15000},
  ],
};
