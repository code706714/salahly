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
