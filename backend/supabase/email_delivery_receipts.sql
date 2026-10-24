begin;
create table public.email_delivery_receipts (
 provider_message_id text primary key,
 status text not null check(status in ('delivered','bounced','delayed')),
 updated_at timestamptz not null default now()
);
alter table public.email_delivery_receipts enable row level security;
revoke all on public.email_delivery_receipts from public,anon,authenticated;
grant all on public.email_delivery_receipts to service_role;
create function public.record_sulh_email_delivery(p_message_id text,p_status text) returns void language plpgsql security invoker set search_path='' as $$
begin
 if p_status not in ('delivered','bounced','delayed') or length(p_message_id)>200 or coalesce(p_message_id,'')='' then raise exception 'invalid_email_event'; end if;
 insert into public.email_delivery_receipts(provider_message_id,status) values(p_message_id,p_status)
 on conflict(provider_message_id) do update set status=case when public.email_delivery_receipts.status in ('delivered','bounced') then public.email_delivery_receipts.status else excluded.status end,updated_at=now();
 update public.booking_email_outbox e set status=r.status,updated_at=now(),error_code=null from public.email_delivery_receipts r
 where e.provider_message_id=r.provider_message_id and r.provider_message_id=p_message_id and e.status not in ('delivered','bounced');
end $$;
revoke all on function public.record_sulh_email_delivery(text,text) from public,anon,authenticated;
grant execute on function public.record_sulh_email_delivery(text,text) to service_role;
commit;
