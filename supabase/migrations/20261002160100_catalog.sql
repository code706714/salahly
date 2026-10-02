-- Catalog of what the platform offers and where: service categories, the
-- services under each one with a suggested starting price, and the areas
-- technicians cover. Read-only for app users; the admin dashboard edits it.

create table public.service_categories (
  id text primary key check (id ~ '^[a-z][a-z_]{1,31}$'),
  name_ar text not null check (char_length(name_ar) between 2 and 40),
  is_active boolean not null default false,
  sort_order smallint not null default 0
);

create table public.services (
  id text primary key check (id ~ '^[a-z][a-z_]{1,47}$'),
  category_id text not null references public.service_categories (id),
  name_ar text not null check (char_length(name_ar) between 2 and 60),
  suggested_price_piastres bigint not null check (suggested_price_piastres > 0),
  is_active boolean not null default true,
  sort_order smallint not null default 0
);

create index services_category_id_idx on public.services (category_id);

-- Centers are approximate and only used to suggest the nearest areas.
create table public.service_areas (
  id text primary key check (id ~ '^[a-z][a-z0-9_]{1,47}$'),
  name_ar text not null unique check (char_length(name_ar) between 2 and 40),
  city_ar text not null check (char_length(city_ar) between 2 and 40),
  center_lat double precision not null check (center_lat between 22 and 32),
  center_lng double precision not null check (center_lng between 24 and 37),
  is_open boolean not null default true,
  sort_order smallint not null default 0
);

alter table public.service_categories enable row level security;
alter table public.services enable row level security;
alter table public.service_areas enable row level security;

revoke all on table public.service_categories, public.services, public.service_areas
  from anon, authenticated;
grant select on table public.service_categories, public.services, public.service_areas
  to authenticated;

create policy "Signed-in users read categories"
  on public.service_categories for select to authenticated using (true);
create policy "Signed-in users read services"
  on public.services for select to authenticated using (true);
create policy "Signed-in users read areas"
  on public.service_areas for select to authenticated using (true);

insert into public.service_categories (id, name_ar, is_active, sort_order) values
  ('ac', 'تكييف', true, 1),
  ('electrical', 'كهربا', false, 2),
  ('plumbing', 'سباكة', false, 3),
  ('appliances', 'غسالات وتلاجات', false, 4);

insert into public.services (id, category_id, name_ar, suggested_price_piastres, sort_order) values
  ('ac_inspection', 'ac', 'كشف', 15000, 1),
  ('ac_inspection_cleaning', 'ac', 'كشف وتنظيف', 35000, 2),
  ('ac_freon_recharge', 'ac', 'شحن فريون', 65000, 3),
  ('ac_split_installation', 'ac', 'تركيب سبليت', 90000, 4),
  ('ac_removal_relocation', 'ac', 'فك ونقل', 60000, 5);

insert into public.service_areas (id, name_ar, city_ar, center_lat, center_lng, sort_order) values
  ('nasr_city', 'مدينة نصر', 'القاهرة', 30.0561, 31.3300, 1),
  ('heliopolis', 'مصر الجديدة', 'القاهرة', 30.0911, 31.3225, 2),
  ('nozha', 'النزهة', 'القاهرة', 30.1195, 31.3483, 3),
  ('abbasiya', 'العباسية', 'القاهرة', 30.0723, 31.2833, 4),
  ('zeitoun', 'الزيتون', 'القاهرة', 30.1047, 31.3133, 5),
  ('hadayek_el_kobba', 'حدائق القبة', 'القاهرة', 30.0880, 31.2860, 6),
  ('ain_shams', 'عين شمس', 'القاهرة', 30.1310, 31.3290, 7),
  ('matareya', 'المطرية', 'القاهرة', 30.1215, 31.3135, 8),
  ('marg', 'المرج', 'القاهرة', 30.1580, 31.3370, 9),
  ('salam_city', 'مدينة السلام', 'القاهرة', 30.1650, 31.3950, 10),
  ('new_cairo', 'التجمع الخامس', 'القاهرة', 30.0080, 31.4280, 11),
  ('rehab', 'الرحاب', 'القاهرة', 30.0600, 31.4930, 12),
  ('madinaty', 'مدينتي', 'القاهرة', 30.1070, 31.6380, 13),
  ('shorouk', 'الشروق', 'القاهرة', 30.1230, 31.6050, 14),
  ('obour', 'العبور', 'القليوبية', 30.2280, 31.4800, 15),
  ('mokattam', 'المقطم', 'القاهرة', 30.0180, 31.3030, 16),
  ('maadi', 'المعادي', 'القاهرة', 29.9600, 31.2570, 17),
  ('helwan', 'حلوان', 'القاهرة', 29.8500, 31.3340, 18),
  ('downtown', 'وسط البلد', 'القاهرة', 30.0480, 31.2400, 19),
  ('zamalek', 'الزمالك', 'القاهرة', 30.0610, 31.2200, 20),
  ('sayeda_zeinab', 'السيدة زينب', 'القاهرة', 30.0290, 31.2430, 21),
  ('manial', 'المنيل', 'القاهرة', 30.0200, 31.2280, 22),
  ('shubra', 'شبرا', 'القاهرة', 30.0870, 31.2440, 23),
  ('shubra_el_kheima', 'شبرا الخيمة', 'القليوبية', 30.1280, 31.2420, 24),
  ('dokki', 'الدقي', 'الجيزة', 30.0380, 31.2120, 25),
  ('mohandessin', 'المهندسين', 'الجيزة', 30.0560, 31.2000, 26),
  ('agouza', 'العجوزة', 'الجيزة', 30.0550, 31.2090, 27),
  ('imbaba', 'إمبابة', 'الجيزة', 30.0760, 31.2070, 28),
  ('giza', 'الجيزة', 'الجيزة', 30.0130, 31.2090, 29),
  ('faisal', 'فيصل', 'الجيزة', 30.0050, 31.1700, 30),
  ('haram', 'الهرم', 'الجيزة', 29.9890, 31.1450, 31),
  ('sheikh_zayed', 'الشيخ زايد', 'الجيزة', 30.0440, 30.9830, 32),
  ('october', '6 أكتوبر', 'الجيزة', 29.9380, 30.9140, 33);
