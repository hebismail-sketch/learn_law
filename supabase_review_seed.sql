-- Synthetic sample content for the dedicated review Supabase project only.
-- Safe to run repeatedly; existing review edits are not overwritten.

insert into public.categories (id, name, description)
values (
  'baf85054-8a15-4f4e-9df7-20e77723bb01',
  'بيانات تجريبية للمراجعة',
  'محتوى افتراضي لاختبار التطبيق ولوحة الإدارة.'
)
on conflict (id) do nothing;

insert into public.subcategories (id, category_id, name)
values (
  'baf85054-8a15-4f4e-9df7-20e77723bb02',
  'baf85054-8a15-4f4e-9df7-20e77723bb01',
  'قسم تجريبي'
)
on conflict (id) do nothing;

insert into public.legal_cases (id, subcategory_id, title, description)
values (
  'baf85054-8a15-4f4e-9df7-20e77723bb03',
  'baf85054-8a15-4f4e-9df7-20e77723bb02',
  'دعوى افتراضية لاختبار المراجعة',
  'قضية تدريبية غير حقيقية لاختبار عرض المسارات وتحريرها.'
)
on conflict (id) do nothing;

insert into public.case_steps (
  id, case_id, step_number, title, short_description
)
values
  (
    'baf85054-8a15-4f4e-9df7-20e77723bb04',
    'baf85054-8a15-4f4e-9df7-20e77723bb03',
    1,
    'الخطوة الأولى: مراجعة المستندات',
    'تحقق من المستندات المطلوبة في هذا المثال التدريبي.'
  ),
  (
    'baf85054-8a15-4f4e-9df7-20e77723bb05',
    'baf85054-8a15-4f4e-9df7-20e77723bb03',
    2,
    'الخطوة الثانية: متابعة الإجراء',
    'تابع الإجراء الافتراضي وسجل النتيجة المناسبة.'
  )
on conflict (id) do nothing;
