-- Run this in Supabase SQL Editor (Dashboard → SQL Editor) to create the synced table.
-- Both Android and Web apps will read/write this same table.

create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  amount numeric not null default 0,
  date timestamptz not null default now(),
  category text,
  created_at timestamptz not null default now()
);

-- Allow anonymous read/write for demo. For production, use Row Level Security (RLS).
alter table public.transactions enable row level security;

create policy "Allow all for demo" on public.transactions
  for all
  using (true)
  with check (true);

-- Optional: enable Realtime so both clients get live updates.
alter publication supabase_realtime add table public.transactions;
