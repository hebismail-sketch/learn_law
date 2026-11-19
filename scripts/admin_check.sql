-- Learn Law - is hebaesmail.dev@gmail.com able to open the editor?
--
-- Run this ONE statement in the Supabase SQL Editor of the project the app
-- actually talks to (production: https://ptsfjeersiesgjtvcjkh.supabase.co).
-- It changes nothing; it only reports the three things that can keep the
-- editor closed:
--
--   1. the account exists on THIS project at all;
--   2. it has a password (an account created from the dashboard with an empty
--      password box can only sign in through a provider or a magic link, so
--      every password typed in the app is refused as "بيانات الدخول غير صحيحة");
--   3. the admin claim sits in raw_app_meta_data (the only place the app and
--      the RLS policies look) and not only in raw_user_meta_data.

select u.id,
       u.email,
       u.encrypted_password is not null
         and u.encrypted_password <> ''      as has_password,
       u.email_confirmed_at is not null      as email_confirmed,
       u.banned_until,
       u.raw_app_meta_data ->> 'role'        as app_role,
       u.raw_app_meta_data ->> 'learn_law_role' as app_learn_law_role,
       u.raw_user_meta_data ->> 'role'       as user_meta_role,
       u.raw_app_meta_data                   as app_meta_full,
       coalesce(
         u.raw_app_meta_data ->> 'role' = 'admin'
         or u.raw_app_meta_data ->> 'learn_law_role' = 'admin',
         false
       )                                     as app_will_accept_admin,
       u.last_sign_in_at,
       u.updated_at
from auth.users u
where lower(u.email) = lower('hebaesmail.dev@gmail.com');
