-- Create a fresh schema in the dedicated Google Play review Supabase project.
-- Do not run this file against the production project.

create extension if not exists pgcrypto;

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.subcategories (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.categories (id),
  name text not null,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.legal_cases (
  id uuid primary key default gen_random_uuid(),
  subcategory_id uuid not null references public.subcategories (id),
  title text not null,
  description text,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.case_steps (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.legal_cases (id),
  step_number integer not null,
  title text not null,
  short_description text not null default '',
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
