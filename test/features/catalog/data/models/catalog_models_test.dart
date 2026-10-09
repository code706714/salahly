import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/features/catalog/data/models/catalog_models.dart';

void main() {
  Map<String, dynamic> row({Object? issues}) => {
    'id': 'plumbing',
    'name_ar': 'سباكة',
    'is_active': true,
    'sort_order': 2,
    'services': [
      {
        'id': 'plumbing_leak_repair',
        'name_ar': 'إصلاح تسريب',
        'suggested_price_piastres': 25000,
        'is_active': true,
        'sort_order': 2,
      },
      {
        'id': 'plumbing_inspection',
        'name_ar': 'معاينة',
        'suggested_price_piastres': 15000,
        'is_active': true,
        'sort_order': 1,
      },
      {
        'id': 'plumbing_old',
        'name_ar': 'قديمة',
        'suggested_price_piastres': 10000,
        'is_active': false,
        'sort_order': 3,
      },
    ],
    'category_issues': ?issues,
  };

  test('reads the problems of a trade in their sort order', () {
    final category = ServiceCategoryModel.fromJson(
      row(
        issues: [
          {'issue': 'other', 'name_ar': 'حاجة تانية', 'sort_order': 9},
          {'issue': 'plumbing_leak', 'name_ar': 'تسريب مية', 'sort_order': 1},
          {'issue': 'plumbing_clog', 'name_ar': 'الصرف مسدود', 'sort_order': 2},
        ],
      ),
    );

    expect(category.issues.map((issue) => issue.id), [
      'plumbing_leak',
      'plumbing_clog',
      'other',
    ]);
    expect(category.issues.first.name, 'تسريب مية');
  });

  test('reads the open services in their sort order', () {
    final category = ServiceCategoryModel.fromJson(row());

    expect(category.services.map((service) => service.id), [
      'plumbing_inspection',
      'plumbing_leak_repair',
    ]);
    expect(category.issues, isEmpty);
  });
}
