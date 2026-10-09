-- More categories, part 2: carpentry, satellite dishes and TVs, and
-- aluminum work, each with its own services and issue list. Starting
-- prices are hints the technician can change.

insert into public.service_categories (id, name_ar, is_active, sort_order) values
  ('carpentry', 'نجارة', true, 6),
  ('satellite_tv', 'دش وتلفزيونات', true, 7),
  ('aluminum', 'ألوميتال', true, 8)
on conflict (id) do nothing;

insert into public.services (id, category_id, name_ar, suggested_price_piastres, sort_order) values
  ('carpentry_inspection', 'carpentry', 'معاينة', 10000, 1),
  ('carpentry_door_repair', 'carpentry', 'إصلاح أو تغيير باب', 30000, 2),
  ('carpentry_lock_hinges', 'carpentry', 'تغيير كالون ومفصلات', 15000, 3),
  ('carpentry_furniture_repair', 'carpentry', 'إصلاح أثاث', 25000, 4),
  ('carpentry_furniture_assembly', 'carpentry', 'فك وتركيب أثاث', 40000, 5),
  ('carpentry_custom_work', 'carpentry', 'تفصيل نجارة', 100000, 6),
  ('tv_inspection', 'satellite_tv', 'كشف وتحديد العطل', 15000, 1),
  ('tv_dish_install', 'satellite_tv', 'تركيب دش', 40000, 2),
  ('tv_dish_alignment', 'satellite_tv', 'ضبط الدش والقنوات', 20000, 3),
  ('tv_screen_repair', 'satellite_tv', 'إصلاح شاشة', 60000, 4),
  ('tv_wall_mount', 'satellite_tv', 'تركيب شاشة على الحيطة', 25000, 5),
  ('tv_board_repair', 'satellite_tv', 'صيانة بوردة', 45000, 6),
  ('aluminum_inspection', 'aluminum', 'معاينة', 10000, 1),
  ('aluminum_window_install', 'aluminum', 'تركيب شباك ألوميتال', 80000, 2),
  ('aluminum_door_install', 'aluminum', 'تركيب باب ألوميتال', 100000, 3),
  ('aluminum_repair', 'aluminum', 'إصلاح شباك أو باب', 25000, 4),
  ('aluminum_glass_replacement', 'aluminum', 'تغيير زجاج', 30000, 5),
  ('aluminum_shutter_install', 'aluminum', 'تركيب شيش حصيرة', 60000, 6)
on conflict (id) do nothing;

insert into public.category_issues (category_id, issue, name_ar, sort_order) values
  ('carpentry', 'carpentry_door', 'باب أو شباك خشب', 1),
  ('carpentry', 'carpentry_furniture', 'أثاث محتاج إصلاح', 2),
  ('carpentry', 'carpentry_custom', 'تفصيل نجارة', 3),
  ('carpentry', 'installation', 'فك وتركيب', 4),
  ('carpentry', 'other', 'حاجة تانية', 5),
  ('satellite_tv', 'tv_no_signal', 'مفيش إشارة أو قنوات', 1),
  ('satellite_tv', 'tv_screen', 'الشاشة بايظة', 2),
  ('satellite_tv', 'tv_not_starting', 'مش بيشتغل', 3),
  ('satellite_tv', 'installation', 'تركيب دش أو شاشة', 4),
  ('satellite_tv', 'other', 'حاجة تانية', 5),
  ('aluminum', 'aluminum_window', 'شباك', 1),
  ('aluminum', 'aluminum_door', 'باب', 2),
  ('aluminum', 'aluminum_glass', 'زجاج مكسور', 3),
  ('aluminum', 'installation', 'تركيب جديد', 4),
  ('aluminum', 'other', 'حاجة تانية', 5)
on conflict (category_id, issue) do nothing;
