-- 가계부 Supabase 스키마
-- Supabase 대시보드 → SQL Editor에 통째로 붙여넣고 실행

-- 1) 테이블

create table majors (
  user_id uuid not null references auth.users(id) on delete cascade,
  major text not null,
  sort_order int not null default 0,
  primary key (user_id, major)
);

create table categories (
  id bigserial primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  major text not null,
  sub text not null,
  sort_order int not null default 0,
  unique (user_id, major, sub)
);

create table budgets (
  user_id uuid not null references auth.users(id) on delete cascade,
  major text not null,
  monthly_amount bigint not null default 0,
  updated_at timestamptz default now(),
  primary key (user_id, major)
);

create table transactions (
  id bigserial primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  date text not null,
  card text,
  merchant text,
  amount bigint not null,
  major_category text not null,
  sub_category text,
  memo text,
  is_fixed int not null default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create index idx_tx_user_date on transactions(user_id, date);
create index idx_tx_user_major on transactions(user_id, major_category);

create table fixed_expenses (
  id bigserial primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  major text not null,
  sub text,
  amount bigint not null default 0,
  card text,
  day_of_month int not null default 1,
  active int not null default 1,
  memo text,
  sort_order int not null default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 2) Row Level Security: 자기 데이터만 읽고 쓰게

alter table majors enable row level security;
alter table categories enable row level security;
alter table budgets enable row level security;
alter table transactions enable row level security;
alter table fixed_expenses enable row level security;

create policy "own majors" on majors for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "own categories" on categories for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "own budgets" on budgets for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "own transactions" on transactions for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "own fixed_expenses" on fixed_expenses for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- 3) updated_at 자동 갱신 트리거

create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger tx_set_updated_at before update on transactions
  for each row execute function set_updated_at();

create trigger fx_set_updated_at before update on fixed_expenses
  for each row execute function set_updated_at();

create trigger bg_set_updated_at before update on budgets
  for each row execute function set_updated_at();
