-- ============================================================
-- ترقية تطبيق "ديون الصيدلية" — مشروع Supabase: gsftoyjqolqapfypbrlj
-- سلة محذوفات + سجل تدقيق (إضافات جديدة فقط — لا يعدّل أي جدول حالي)
-- طريقة التنفيذ: Supabase Dashboard → SQL Editor → الصق الملف كاملاً → Run
-- آمن للتنفيذ مرة واحدة، وإعادة تنفيذه لا تضر (IF NOT EXISTS / DROP POLICY IF EXISTS)
-- ============================================================

-- 1) جدول سلة المحذوفات: تُحفظ فيه نسخة من أي سجل قبل حذفه حتى يمكن استرجاعه
create table if not exists public.trash_items (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  pharmacy_id uuid,
  deleted_by uuid,
  deleted_by_name text,
  entity text not null,          -- 'debtor' أو 'transaction'
  payload jsonb not null         -- نسخة كاملة من السجل المحذوف
);

-- 2) جدول سجل التدقيق: منو سوّى شنو ومتى (إضافة/تسديد/حذف/استرجاع...)
create table if not exists public.audit_log (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  pharmacy_id uuid,
  user_id uuid,
  user_name text,
  action text not null,
  entity text,
  entity_id text,
  details jsonb
);

-- 3) تفعيل أمان الصفوف (RLS) على الجدولين الجديدين
alter table public.trash_items enable row level security;
alter table public.audit_log enable row level security;

-- 4) الصلاحيات: فقط أعضاء نفس الصيدلية (حسب جدول profiles) يقدرون يوصلون لبيانات صيدليتهم
drop policy if exists trash_select on public.trash_items;
create policy trash_select on public.trash_items for select to authenticated
  using (pharmacy_id in (select pharmacy_id from public.profiles where id = auth.uid()));

drop policy if exists trash_insert on public.trash_items;
create policy trash_insert on public.trash_items for insert to authenticated
  with check (pharmacy_id in (select pharmacy_id from public.profiles where id = auth.uid()));

drop policy if exists trash_delete on public.trash_items;
create policy trash_delete on public.trash_items for delete to authenticated
  using (pharmacy_id in (select pharmacy_id from public.profiles where id = auth.uid()));

drop policy if exists audit_select on public.audit_log;
create policy audit_select on public.audit_log for select to authenticated
  using (pharmacy_id in (select pharmacy_id from public.profiles where id = auth.uid()));

drop policy if exists audit_insert on public.audit_log;
create policy audit_insert on public.audit_log for insert to authenticated
  with check (pharmacy_id in (select pharmacy_id from public.profiles where id = auth.uid()));
-- ملاحظة: لا توجد صلاحية تعديل/حذف على audit_log عمداً، حتى يبقى السجل غير قابل للعبث.

-- ============================================================
-- فحص اختياري (شغّل كل سطر وحده واقرأ النتيجة — لا يغيّر شيئاً):
--   select tablename, policyname, cmd, roles from pg_policies where schemaname = 'public' order by tablename;
--   select relname, relrowsecurity from pg_class where relname in ('debtors','transactions','profiles','receipts');
--
-- إذا أظهر الفحص أن relrowsecurity = false لأي جدول، فهذا يعني أن أي شخص
-- يملك مفتاح الاتصال العام يقدر يقرأ بياناته. الإصلاح يكون بتفعيل RLS
-- وإضافة سياسات تقيّد كل جدول بصيدلية المستخدم، مثال لجدول debtors:
--
--   alter table public.debtors enable row level security;
--   create policy debtors_pharmacy on public.debtors for all to authenticated
--     using (pharmacy_id in (select pharmacy_id from public.profiles where id = auth.uid()))
--     with check (pharmacy_id in (select pharmacy_id from public.profiles where id = auth.uid()));
--
-- ⚠️ لا تنفّذ أمثلة الإصلاح إلا بعد مراجعتها على نسخة تجريبية، لأن سياسة
-- خاطئة ممكن توقف التطبيق الحالي عن العمل. نفّذها جدولًا واحدًا في كل مرة
-- وجرّب التطبيق بعدها مباشرة.
-- ============================================================
