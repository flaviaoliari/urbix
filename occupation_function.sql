set search_path to private, public, urbix;
drop function if exists balance();
create or replace function balance()
returns table (i bigint, hora character varying, ingresos numeric, egresos numeric, ocupacion numeric)
as $$
begin
drop sequence if exists i; create temporary sequence i; -- secuencia y tabla temporaria deberían desaparecer una vez cerrada la sesión
drop table if exists transit; create temporary table transit as -- junta de ingresos y egresos
with movimientos as (select * from
  (select working_hour_text(date_trunc('hour', timestamp)::time,v_id) as hora, (round(avg(estimation)))::integer as "in"
  from variables_estimations
  where v_id=51
  group by hora) as ingresos
natural full join
  (select working_hour_text(date_trunc('hour', timestamp)::time,v_id) as hora, (round(avg(estimation)))::integer as "out"
  from variables_estimations
  where v_id=52
  group by hora) as egresos
order by hora
)
select nextval('i')-1 as i,* from movimientos
;
create or replace view balance as
with recursive estado(i,hora,ingresos,egresos,ocupacion) as ( -- tabla recursiva.
    values (0::bigint,null,0,0,0) -- caso base todo en cero hora nula
  union all (
    select transit.i+1, transit.hora, "in", "out", greatest("in" - "out" + estado.ocupacion, 0) -- incrementa secuencia (?)
    from estado
    join transit
    using(i)
  )
)
select * from estado 

select * from balance;
end;
$$
language plpgsql
;



select hora, ingresos, egresos, ocupacion, null 
--  case when ingresos!=0 then round(100*(ingresos - egresos)/ingresos) else 'NaN' end 
  as "desbalance porcentual" 
from balance
where hora is not null or hora!=''
union
select '| total', sum(ingresos), sum(egresos), sum(ingresos - egresos), 
  case when sum(ingresos)!=0 then round(100*sum(ingresos - egresos)/sum(ingresos))
  else 'NaN' end
from balance
order by hora 
;
