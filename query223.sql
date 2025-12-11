WITH
  setting_user AS (
  SELECT id_rol,nickname_owner_rol, rol_name, id_time_zone, "name",nickname_member, country_code, cur_timestamp, cur_timestamp::date cur_date, cur_timestamp::time cur_time, to_char(cur_timestamp, 'YYYY')::SMALLINT cur_year,
  to_char(cur_timestamp, 'MM')::SMALLINT cur_month, to_char(cur_timestamp, 'DD')::SMALLINT cur_day, to_char(cur_timestamp, 'IW')::SMALLINT cur_week, INTERVAL '1 minute' interva, language_code
   FROM (
   SELECT t.id_time_zone, t."name", uu.nickname_member, timezone(t."name",CURRENT_TIMESTAMP) cur_timestamp, uu.country_code, uu.id_rol,uu.nickname_owner_rol,r.rol_name, uu.language_code
   FROM userpotencie_userpotencie  uu
   INNER JOIN time_zone t ON uu.id_time_zone = t.id_time_zone
   inner join rol_potencie r on (r.id_rol,r.nickname_owner)=(uu.id_rol,uu.nickname_owner_rol) and r.state
   WHERE uu.nickname_environment = '__owner__' AND uu.nickname_member = '__creator__' and uu.state) AS t
),

usr_dictionary as (
   SELECT key, message, case when key ilike 'LIST_223_%' then lower(SUBSTRING("key" FROM POSITION('223_' IN "key") + LENGTH('223_'))) else null end item 
   FROM user_dictionary_language
   WHERE nickname_owner = '__owner__' AND (key ilike 'LIST_223_%' or key in ('LIST_244_TITLE', 'LIST_245_TITLE')) AND language_code = (SELECT language_code FROM setting_user) AND state
),

tmp_dictionary as (
   select key, message, case when key ilike 'LIST_223_%' then lower(SUBSTRING("key" FROM POSITION('223_' IN "key") + LENGTH('223_'))) else null end item
   from dictionary_language
   where (key ilike 'LIST_223_%' or key in ('LIST_244_TITLE', 'LIST_245_TITLE')) AND language_code = (SELECT language_code FROM setting_user) AND state
),

tmp_dict as (select "key", message, item from usr_dictionary union select "key", message,item from tmp_dictionary where "key" not in (select "key" from usr_dictionary)),

config_list as (
    select json_config, 
    (json_config->'assignedto_me')::boolean assignedto_me
    from list_config
    where id_list = 223 and nickname_owner_list ='POTENCIE' 
    and nickname_owner = '__owner__' and json_config notnull and state 
    and ((select id_rol from setting_user ) IN (SELECT unnest(roles)) OR roles isnull)

    UNION ALL  -- En casso no hay registros se isnerta un valor por defecto
    SELECT 
        NULL::jsonb,
        false AS assignedto_me
    WHERE NOT EXISTS (
        SELECT 1 FROM list_config 
        WHERE id_list = 223  
          AND nickname_owner_list = 'POTENCIE' 
          AND nickname_owner = '__owner__' 
          AND json_config NOTNULL 
          AND state 
    )
),

listas_no_acceso as (
    select id_list
    from list_config
    where id_list in (244, 245, 532) and nickname_owner_list ='POTENCIE' 
    and nickname_owner = '__owner__' and json_config isnull and state 
    and ((select id_rol from setting_user ) IN (SELECT unnest(roles)) OR roles isnull)
),

tmp_item_config as (
    select jsonb_build_object(
        'list', jsonb_build_object(
            'title', (select message from tmp_dict where "key" = 'LIST_223_TITLE')),
            'action_config', jsonb_build_object(
                'action_create1', jsonb_build_object('title', (select message from tmp_dict where "key" = 'LIST_244_TITLE')),
                'more_actions2', jsonb_build_object('title', (select message from tmp_dict where "key" = 'LIST_245_TITLE')))) as "item_config"),

tmp_json as(
    SELECT jsonb_object_agg(item, value) AS item_config
    FROM (
        SELECT case when item = 'title' then 'list' 
        when item ilike 'footer%' then 'action_config'
        else item end,
        CASE WHEN item not ilike 'footer%' and item not ilike 'title%' and item not ilike '%question_yes_no%' and item not ilike '%commentary%' THEN
            jsonb_build_object('title_main', '', 'title', message)
        WHEN item ilike '%question_yes_no%' THEN
            jsonb_build_object('title', message, 'title_main', message)
        WHEN item in ('title', 'subtitle') THEN
            jsonb_build_object(
                'title', (select message from tmp_dict where item ilike 'title'), 
                'subtitle' , null
                /* case 
                    when (select * from entrada) = true then 
                        case 
                            when (select assignedto_me from config_list) = true 
                                and (select pending_activities from config_list) = true 
                            then (select message from tmp_dict where "key" = 'MY_PENDING_TASKS')
                            
                            when (select assignedto_me from config_list) = true 
                                and (select pending_activities from config_list) is distinct from true 
                            then (select message from tmp_dict where "key" = 'MY_TASKS')
                            
                            when (select assignedto_mygroups from config_list) = true 
                                and (select pending_activities from config_list) = true 
                            then (select message from tmp_dict where "key" = 'MY_GROUPS_PENDING_TASKS')
                            
                            when (select assignedto_mygroups from config_list) = true 
                                and (select pending_activities from config_list) is distinct from true 
                            then (select message from tmp_dict where "key" = 'MY_GROUPS_TASKS')
                            
                            when (select assignedto_mygroups from config_list) is distinct from true 
                            and (select assignedto_me from config_list) is distinct from true 
                                and (select pending_activities from config_list) = true 
                            then (select message from tmp_dict where "key" = 'PENDING_TASKS')
                            
                            else null
                        end
                    else null
                end */
            )
        WHEN item in ('footer', 'footer_web') THEN
            jsonb_build_object(
				'footer_web', jsonb_build_object ('title', (select message from tmp_dict where item ilike 'footer')),
				'footer1', jsonb_build_object ('title', (select message from tmp_dict where item ilike 'footer'))

			)
        when item ilike '%commentary%' then jsonb_build_object('id', null, 'value', message)
        END AS value
        FROM tmp_dict
        WHERE item notnull
    ) AS tmp
),

combined_json AS (SELECT 
    case when t1.item_config isnull then t2.item_config 
    when t2.item_config isnull then t1.item_config 
    else
        t1.item_config || t2.item_config
    end AS item_config
    FROM tmp_item_config t1
    full join tmp_json t2 on true
),

tmp_item_config_final as(
    SELECT jsonb_object_agg(key, value) AS item_config FROM (
        select case when key_1 isnull then key_2 else key_1 end "key",
        case when value2 isnull then jsonb_concat('{}'::jsonb , value1::jsonb ) 
            when value1 isnull then jsonb_concat('{}'::jsonb , value2::jsonb ) 
            else jsonb_concat(value1::jsonb , value2::jsonb ) 
        end as value 
        from ( 
            SELECT "key" key_1, (item_config->>"key")::json  AS value1
            FROM combined_json
            CROSS JOIN jsonb_each(item_config)
        ) tmp_1
        full join (SELECT "key" key_2, (json_config->>"key")::json  AS value2
        FROM config_list
        CROSS JOIN jsonb_each(json_config)
        where key in (select item from tmp_dict)
        ) tmp_2 on key_1=key_2
  ) AS tmp 
),

sacar_fecha_actualizacion as (
	SELECT (
		concat(end_date, ' 23:59:59.595959595959')::timestamp - concat((select num_hour from time_zone where id_time_zone=(select id_time_zone from setting_user)) ,' hour')::interval) end_date,
	    (concat(start_date, ' 00:00:00')::timestamp - concat((select num_hour from time_zone where id_time_zone=(select id_time_zone from setting_user)) ,' hour')::interval) start_date
	FROM json_to_record('@date_update'::json) AS x (end_date date, end_time time, start_date date, start_time time)
),

buscar_filtros_tipo as (
	select id_tag, tipo_id::integer 
	from (
       SELECT 40 id_tag, replace(z::text,'"','') tipo_id from json_array_elements('@tag40_producttype_id') z
	   where '@tag40_producttype_id' notnull
       union 
       SELECT 41 id_tag, replace(z::text,'"','') tipo_id from json_array_elements('@tag41_producttype_id') z
	   where '@tag41_producttype_id' notnull
       union 
	   SELECT 42 id_tag,replace(z::text,'"','') tipo_id from json_array_elements('@tag42_producttype_id') z
	   where '@tag42_producttype_id' notnull
	   union
	   SELECT 43 id_tag,replace(z::text,'"','') tipo_id from json_array_elements('@tag43_producttype_id') z
	   where '@tag43_producttype_id' notnull
	   union
	   SELECT 44 id_tag,replace(z::text,'"','') tipo_id from json_array_elements('@tag44_producttype_id') z
	   where '@tag44_producttype_id' notnull
	   union
	   SELECT 45 id_tag,replace(z::text,'"','') tipo_id from json_array_elements('@tag45_producttype_id') z
	   where '@tag45_producttype_id' notnull
	   union
	   SELECT 46 id_tag,replace(z::text,'"','') tipo_id from json_array_elements('@tag46_producttype_id') z
	   where '@tag46_producttype_id' notnull
	   union
	   SELECT 47 id_tag,replace(z::text,'"','') tipo_id from json_array_elements('@tag47_producttype_id') z
	   where '@tag47_producttype_id' notnull
	   union
	   SELECT 48 id_tag,replace(z::text,'"','') tipo_id from json_array_elements('@tag48_producttype_id') z
	   where '@tag48_producttype_id' notnull
       union
	   SELECT 49 id_tag, replace(z::text,'"','') tipo_id from json_array_elements('@tag49_producttype_id') z
	   where '@tag49_producttype_id' notnull
     ) as x
),

arreglo_tipo as (
  select array_agg(tipo_id order by tipo_id) tipo1
   from buscar_filtros_tipo
),

buscar_filtros_misc as (
	select id_tag, item_id::integer,id_misce 
	from (
       SELECT 50 id_tag,replace(z::text,'"','') item_id , (select id_miscellaneous from miscellaneous_detail where nickname_owner='__owner__' and id_tag=50 and nickname_owner_tag='POTENCIE' AND STATE limit 1) id_misce
	   from json_array_elements('@tag50_item_id') z
	   where '@tag50_item_id' notnull
       union 
       SELECT 51 id_tag,replace(z::text,'"','') item_id , (select id_miscellaneous from miscellaneous_detail where nickname_owner='__owner__' and id_tag=51 and nickname_owner_tag='POTENCIE' AND STATE limit 1) id_misce
	   from json_array_elements('@tag51_item_id') z
	   where '@tag51_item_id' notnull
	   union 
       SELECT 52 id_tag,replace(z::text,'"','') item_id, (select id_miscellaneous from miscellaneous_detail where nickname_owner='__owner__' and id_tag=52 and nickname_owner_tag='POTENCIE' AND STATE limit 1) id_misce 
	   from json_array_elements('@tag52_item_id') z
	   where '@tag52_item_id' notnull
       union 
	   SELECT 53 id_tag,replace(z::text,'"','') item_id , (select id_miscellaneous from miscellaneous_detail where nickname_owner='__owner__' and id_tag=53 and nickname_owner_tag='POTENCIE' AND STATE limit 1) id_misce
		from json_array_elements('@tag53_item_id') z
	   where '@tag53_item_id' notnull
	   union
	   SELECT 54 id_tag, replace(z::text,'"','') item_id , (select id_miscellaneous from miscellaneous_detail where nickname_owner='__owner__' and id_tag=54 and nickname_owner_tag='POTENCIE' AND STATE limit 1) id_misce
	   from json_array_elements('@tag54_item_id') z
	   where '@tag54_item_id' notnull
	  ) as x
),

arreglo_misc as (
    select array_agg(id_misce||','||item_id order by id_misce,item_id) misc1
   from buscar_filtros_misc
 ),

buscar_producto as (
   SELECT id_product , nickname_owner,product_title , id_contact_maker, nickname_owner_contact,  country_code code_country, observation, description, id_external, stock_min, stock_max,  id_pricelist, nickname_creator, creation_date,update_date,  id_brand, nickname_owner_brand, commentary, id_measure, nickname_owner_measure, iscombo, hasinventory, id_filepath_image, nickname_owner_filepath, part_number, is_inventoriable, is_saleable, is_buyable, id_product_type type_product_id, nickname_owner_type, id_product_subtype subtype_product_id, nickname_owner_subtype, quantity_stock stock_quantity,nickname_owner_pricelist
	FROM public.product
	where  (
   CASE
   WHEN '@t_image' NOTNULL and 1=(SELECT valor FROM (SELECT replace(z::text,'"','')::integer VALOR from json_array_elements('@t_image') z ) AS X ) then 
      id_filepath_image notnull 
	WHEN '@t_image' NOTNULL  and 2=(  SELECT valor FROM (SELECT replace(z::text,'"','')::integer VALOR from json_array_elements('@t_image') z ) AS X ) 
                      then id_filepath_image isnull  
               else  true end) and  
	        (CASE WHEN '@inventoriable_is' NOTNULL  and 1=(  SELECT valor FROM (SELECT replace(z::text,'"','')::integer VALOR from json_array_elements('@inventoriable_is') z ) AS X ) 
                      then is_inventoriable=true
	            WHEN '@inventoriable_is' NOTNULL  and 2=(  SELECT valor FROM (SELECT replace(z::text,'"','')::integer VALOR from json_array_elements('@inventoriable_is') z ) AS X ) 
                      then is_inventoriable=false 
               else  true end) and 
	         (CASE WHEN '@saleable_is' NOTNULL  and 1=(  SELECT valor FROM (SELECT replace(z::text,'"','')::integer VALOR from json_array_elements('@saleable_is') z ) AS X ) 
                      then is_saleable=true
	            WHEN '@saleable_is' NOTNULL  and 2=(  SELECT valor FROM (SELECT replace(z::text,'"','')::integer VALOR from json_array_elements('@saleable_is') z ) AS X ) 
                      then is_saleable=false 
               else  true end) and 
	            (CASE WHEN '@buyable_is' NOTNULL  and 1=(  SELECT valor FROM (SELECT replace(z::text,'"','')::integer VALOR from json_array_elements('@buyable_is') z ) AS X ) 
                      then is_buyable=true
	            WHEN '@buyable_is' NOTNULL  and 2=(  SELECT valor FROM (SELECT replace(z::text,'"','')::integer VALOR from json_array_elements('@buyable_is') z ) AS X ) 
                      then is_buyable=false 
               else  true end) and 
	          (CASE WHEN '@combo_is' NOTNULL  and 1=(  SELECT valor FROM (SELECT replace(z::text,'"','')::integer VALOR from json_array_elements('@combo_is') z ) AS X ) 
                      then iscombo=true
	            WHEN '@combo_is' NOTNULL  and 2=(  SELECT valor FROM (SELECT replace(z::text,'"','')::integer VALOR from json_array_elements('@combo_is') z ) AS X ) 
                      then iscombo=false 
               else  true end) and 
	          (CASE WHEN '@t_hasinventory' NOTNULL  and 1=(  SELECT valor FROM (SELECT replace(z::text,'"','')::integer VALOR from json_array_elements('@t_hasinventory') z ) AS X ) 
                      then hasinventory=true
	            WHEN '@t_hasinventory' NOTNULL  and 2=(  SELECT valor FROM (SELECT replace(z::text,'"','')::integer VALOR from json_array_elements('@t_hasinventory') z ) AS X ) 
                      then hasinventory=false 
               else  true end) and 
	           (CASE WHEN '@maker_contact_id' NOTNULL Then id_contact_maker::text in  (SELECT replace(z::text,'"','') from json_array_elements('@maker_contact_id') z) else true end) and
	           (CASE WHEN '@code_country' NOTNULL Then country_code in  (SELECT replace(z::text,'"','') from json_array_elements('@code_country') z) else true end) and
	           (CASE WHEN '@brand_id' NOTNULL Then id_brand::text in  (SELECT replace(z::text,'"','') from json_array_elements('@brand_id') z) else true end) and
               (CASE WHEN '@measure_id' NOTNULL Then id_measure::text in  (SELECT replace(z::text,'"','') from json_array_elements('@measure_id') z) else true end) and
               (CASE WHEN '@type_product_id' NOTNULL Then id_product_type::text in  (SELECT replace(z::text,'"','') from json_array_elements('@type_product_id') z) else true end) and
               (CASE WHEN '@subtype_product_id' NOTNULL Then id_product_subtype::text in  (SELECT replace(z::text,'"','') from json_array_elements('@subtype_product_id') z) else true end) and
               (CASE WHEN '@id_external' NOTNULL THEN id_external::text in (SELECT replace(z::text,'"','') from json_array_elements('@id_external') z) else true end) and
                nickname_owner='__owner__' 
                and id_tag isnull
                and nickname_owner_tag isnull
                and state 
	         /*SECONDARY_FILTER*//*END SECONDARY_FILTER*/ 
),

buscar_tipo as (
   select p.id_product, p.nickname_owner, p.type_product_id , pt.product_type_title 
   from buscar_producto p 
	inner join product_type pt on (pt.id_product_type,pt.nickname_owner)=(p.type_product_id,p.nickname_owner_type) and pt.state
),

buscar_subtipo as (
   select p.id_product, p.nickname_owner, p.subtype_product_id
   from buscar_producto p 
	inner join product_type pt on (pt.id_product_type,pt.nickname_owner)=(p.subtype_product_id,p.nickname_owner_subtype) and pt.state
),

buscar_marca as (
   select p.id_product, p.nickname_owner, p.id_brand, b.brand_title 
   from buscar_producto p 
	inner join brand b on (b.id_brand,b.nickname_owner)=(p.id_brand,p.nickname_owner_brand) and b.state
),
buscar_measure as (
   select p.id_product, p.nickname_owner, p.id_measure, b.measure_title ,b.symbol symbol_measure
   from buscar_producto p 
	inner join measure b on (b.id_measure,b.nickname_owner)=(p.id_measure,p.nickname_owner_measure) and b.state
),

buscar_foto as (
   select p.id_product, p.nickname_owner, p.id_filepath_image, f.filepath_url foto_producto
   from buscar_producto p 
	inner join filepath f on (f.id_filepath,f.nickname_owner)=(p.id_filepath_image,p.nickname_owner_filepath) and f.state
),
   
buscar_pais as (
  select p.id_product,p.nickname_owner,p.code_country, d.message pais,c.country_vector_flag
   from buscar_producto p
  inner join country c  on ( c.country_code)=(p.code_country) and c.state
  inner join dictionary_language d on d.key=c.country_name and d.language_code=(select  language_code from setting_user)
),

buscar_tag as ( 
  select t.id_tag,t.nickname_owner,t.tag_name, tt.id_tag_type,ttt.nickname_owner_tagtype , initcap( tt.tag_type_title::varchar) titulo_tag
  from tag t
  left join tag_tagtype ttt on (ttt.id_tag,ttt.nickname_owner_tag) =(t.id_tag,t.nickname_owner) and ttt.nickname_owner_tagtype='PROYECTOS' and ttt.state
  left join tag_type tt on (tt.id_tag_type,tt.nickname_owner)= (ttt.id_tag_type,ttt.nickname_owner_tagtype) and tt.state
  where t.nickname_owner='POTENCIE' AND t.state and t.id_tag in (56,62,67)
  ),
  
buscar_tag_name as (
    select t.id_tag,t.nickname_owner,t.tag_name, t.id_tag_type,t.nickname_owner_tagtype , initcap(d.message) titulo_tag
   from   buscar_tag t
   inner join dictionary_language d on d.key=t.tag_name and d.language_code=(select  language_code from setting_user)
	where t.id_tag_type isnull
),

unir_tag  as (
  select * 
  from   buscar_tag where id_tag_type notnull
  union 
  select * from buscar_tag_name where id_tag_type isnull
),

buscar_otros_tipos as (
   select p.id_product, p.nickname_owner, pt.id_product_type, ppt.nickname_owner_producttype,pt.product_type_title,pt.id_tag,pt.nickname_owner_tag,pt.issubtype
   from buscar_producto p 
   inner join product_producttype ppt on (ppt.id_product,ppt.nickname_owner_product)=(p.id_product, p.nickname_owner) and ppt.state
   inner join product_type pt on (pt.id_product_type,pt.nickname_owner)=(ppt.id_product_type,ppt.nickname_owner_producttype) and pt.state
 ),
 
arreglo_tipo2 as (
   select id_product,array_agg (id_product_type  order by id_product_type ) tipo2
   from buscar_otros_tipos
	group by id_product
  
),

buscar_miscellaneous as (
    select p.id_product, p.nickname_owner,md.id_miscellaneous,md.id_item,md.nickname_owner,md.miscellaneous_detail_title,md.color, md.id_tag, md.nickname_owner_tag, md.description, ROW_NUMBER() OVER (ORDER BY md.miscellaneous_detail_title) ordinal
	 from buscar_producto p 
	 inner join miscellaneousdetail_link ml ON (ml.id_link,ml.nickname_owner_link)=(p.id_product,p.nickname_owner) and ml.id_table_potencie=2 and ml.state
	 inner join miscellaneous_detail md on (md.id_miscellaneous,md.id_item,md.nickname_owner)=(ml.id_miscellaneous,ml.id_item,ml.nickname_owner) and md.state
 ),
 
arreglo_misc2 as (
   select id_product, array_agg(id_miscellaneous||','||id_item order by id_miscellaneous,id_item) misc2
   from buscar_miscellaneous
	group by id_product
),

buscar_precio as (
   select p.id_product, p.nickname_owner,pd.id_currency, pd.price, pd.price_total, pd.tax_included,c.iso_code,c.symbol
   from buscar_producto p
   inner join pricelist_detail pd on (pd.id_product,pd.nickname_owner_product)=(p.id_product, p.nickname_owner) and pd.state
   inner join pricelist pr on (pr.id_pricelist,pr.nickname_owner)=(pd.id_pricelist,pd.nickname_owner_list) and pr.state and pr.pricelist_default 
   left join currency c on c.id_currency=pd.id_currency 
),
 
lst_records_filter1 as (
    select p.id_product, p.nickname_owner,p.product_title, p.id_contact_maker,p.observation, p.description, p.id_external, p.stock_min, p.stock_max, p.commentary, iscombo, hasinventory, part_number, is_inventoriable, is_saleable, is_buyable, stock_quantity,   creation_date, p.update_date
	from buscar_producto p 
	where case when  '@tag40_producttype_id' notnull then p.id_product in (select id_product from buscar_otros_tipos where id_tag=40 and id_product_type in (select tipo_id from buscar_filtros_tipo where id_tag=40) ) else true end and
		  case when  '@tag41_producttype_id' notnull then p.id_product in (select id_product from buscar_otros_tipos where id_tag=41 and id_product_type in (select tipo_id from buscar_filtros_tipo where id_tag=41) ) else true end and
	      case when  '@tag42_producttype_id' notnull then p.id_product in (select id_product from buscar_otros_tipos where id_tag=42 and id_product_type in (select tipo_id from buscar_filtros_tipo where id_tag=42) ) else true end and
	      case when  '@tag43_producttype_id' notnull then p.id_product in (select id_product from buscar_otros_tipos where id_tag=43 and id_product_type in (select tipo_id from buscar_filtros_tipo where id_tag=43) ) else true end and
	      case when  '@tag44_producttype_id' notnull then p.id_product in (select id_product from buscar_otros_tipos where id_tag=44 and id_product_type in (select tipo_id from buscar_filtros_tipo where id_tag=44) ) else true end and
	      case when '@tag45_producttype_id' notnull then p.id_product in (select id_product from buscar_otros_tipos where id_tag=45 and id_product_type in (select tipo_id from buscar_filtros_tipo where id_tag=45) ) else true end and
	      case when  '@tag46_producttype_id' notnull then p.id_product in (select id_product from buscar_otros_tipos where id_tag=46 and id_product_type in (select tipo_id from buscar_filtros_tipo where id_tag=46) ) else true end and
	      case when '@tag47_producttype_id' notnull	then p.id_product in (select id_product from buscar_otros_tipos where id_tag=47 and id_product_type in (select tipo_id from buscar_filtros_tipo where id_tag=47) ) else true end and
          case when '@tag48_producttype_id' notnull then p.id_product in (select id_product from buscar_otros_tipos where id_tag=48 and id_product_type in (select tipo_id from buscar_filtros_tipo where id_tag=48) ) else true end and
	      case when  '@tag49_producttype_id' notnull then p.id_product in (select id_product from buscar_otros_tipos where id_tag=49 and id_product_type in (select tipo_id from buscar_filtros_tipo where id_tag=49) ) else true end 
	 
),

lst_records_filter2 as (
    select p.id_product, p.nickname_owner,p.product_title, p.id_contact_maker,p.observation, p.description, p.id_external, p.stock_min, p.stock_max, p.commentary, iscombo, hasinventory, part_number, is_inventoriable, is_saleable, is_buyable, stock_quantity, creation_date, p.update_date
	from lst_records_filter1 p 
	where case when '@tag50_item_id' notnull then p.id_product in (select id_product from  buscar_miscellaneous where id_tag=50 and  id_item  in (select item_id from buscar_filtros_misc where id_tag=50)) else true end and 
	      case when '@tag51_item_id' notnull then p.id_product in (select id_product from  buscar_miscellaneous where id_tag=51 and  id_item  in (select item_id from buscar_filtros_misc where id_tag=51)) else true end and 
	      case when '@tag52_item_id' notnull then p.id_product in (select id_product from  buscar_miscellaneous where id_tag=52 and  id_item  in (select item_id from buscar_filtros_misc where id_tag=52)) else true end and 
	      case when '@tag53_item_id' notnull then p.id_product in (select id_product from  buscar_miscellaneous where id_tag=53 and  id_item  in (select item_id from buscar_filtros_misc where id_tag=53)) else true end and 
	      case when  '@tag54_item_id' notnull then p.id_product in (select id_product from  buscar_miscellaneous where id_tag=54 and  id_item  in (select item_id from buscar_filtros_misc where id_tag=54)) else true end 
     /*SECONDARY_FILTER*//*END SECONDARY_FILTER*/
     /*PRINCIPAL_ORDER*//*END PRINCIPAL_ORDER*/
  ),


lst_records as (
   select p.id_product, p.nickname_owner,p.product_title, p.id_contact_maker,p.observation, p.description, p.id_external, p.stock_min, p.stock_max, p.commentary, iscombo, hasinventory, t.product_type_title, part_number, is_inventoriable, is_saleable, is_buyable, stock_quantity, p.creation_date, p.update_date,
	       b.id_brand, b.brand_title,
	       m.id_measure, m.measure_title,m.symbol_measure, t.type_product_id, st.subtype_product_id, f.foto_producto,
	       co.pais,co.country_vector_flag, d.message "si", d1.message "tax",d2.message "notax",
	     pr.id_currency, pr.price, pr.price_total, pr.tax_included,pr.iso_code,pr.symbol ,su.language_code, 
	     case when pr.tax_included then pr.price_total else pr.price end precio,
	     case when m.symbol_measure notnull then lower(m.symbol_measure) else m.measure_title end unidad,
	     case when pr.tax_included  then d1.message else d2.message end mess
	from lst_records_filter2 p
   left join buscar_marca b on (b.id_product,b.nickname_owner)=(p.id_product,p.nickname_owner)
   left join buscar_measure m on (m.id_product,m.nickname_owner)=(p.id_product,p.nickname_owner)
   left join buscar_tipo t on (t.id_product,t.nickname_owner)=(p.id_product,p.nickname_owner)
   left join buscar_subtipo st on (st.id_product,st.nickname_owner)=(p.id_product,p.nickname_owner)
   left join buscar_foto f on (f.id_product,f.nickname_owner)=(p.id_product,p.nickname_owner)
   left join buscar_pais co on (co.id_product,co.nickname_owner)=(p.id_product,p.nickname_owner)
   left join buscar_precio pr on (pr.id_product,pr.nickname_owner)=(p.id_product,p.nickname_owner)
   left join dictionary_language d on d.key='YES' and d.language_code=(select  language_code from setting_user)
   left join dictionary_language d1 on d1.key='TAXES_INCLUDED' and d1.language_code=(select  language_code from setting_user)
   left join dictionary_language d2 on d2.key='TAXES_NOT_INCLUDED' and d2.language_code=(select  language_code from setting_user)
   left join sacar_fecha_actualizacion sf on true
   left join setting_user su on true 
 /*LIMIT_LIST*/OFFSET __offset__ LIMIT __limit__/*END LIMIT_LIST*/
),

counter as(
   select count(*) "counter" from lst_records_filter2
),

t_showaction as (
    select array[
        244 NOT IN (SELECT id_list FROM listas_no_acceso),
        245 NOT IN (SELECT id_list FROM listas_no_acceso), true
    ] show_action
),

lst_temp as (
    select
        r.id_product "id",
        null "checkbox_actions",
        jsonb_build_object(
            'image_url', r.foto_producto,
            'vector', 'vct_4x_market',
            'vector_color', '#FFFFFF',
            'vector_bg_color', null,
            'in_case', null,
            'filter', null,
            'text', null,
            'text_bg_color', '#FFFFFF00',
            'text_color','#FFFFFF00',
            'text_style','NORMAL'
        ) as col1,
        jsonb_build_object(
            'in_case', null,
            'filter', jsonb_build_object('product_id',r.id_product),
            'text', r.id_product,
            'text_bg_color', '#FFFFFF00',
            'text_color','#212322',
            'text_style','NORMAL',
            'vector', NULL,
            'vector_color', NULL
        ) as col2,
        jsonb_build_object(
            'in_case', null,
            'filter', jsonb_build_object('product_id',r.id_product),
            'text', r.id_external, 
            'text_bg_color', '#FFFFFF00',
            'text_color', null,
            'text_style','NORMAL',
            'vector', NULL,
            'vector_color', NULL
        ) as col3,
        jsonb_build_object(
            'in_case', null,
            'filter', null,
            'text', r.product_title,
            'text_bg_color', '#FFFFFF00',
            'text_color', null,
            'text_style','NORMAL',
            'vector', NULL,
            'vector_color', NULL
        ) as col4,
        jsonb_build_object(
            'in_case', null,
            'filter', null,
            'text', r.brand_title,
            'text_bg_color', '#FFFFFF00',
            'text_color', null,
            'text_style','NORMAL',
            'vector', NULL,
            'vector_color', NULL
        ) as col5,
        jsonb_build_object(
            'in_case', null,
            'filter', null,
            'text', r.product_type_title,
            'text_bg_color', '#FFFFFF00',
            'text_color', null,
            'text_style','NORMAL',
            'vector', NULL,
            'vector_color', NULL
        ) as col6,
        jsonb_build_object(
            'in_case', null,
            'filter', null,
            'text', r.description,
            'text_bg_color', '#FFFFFF00',
            'text_color', null,
            'text_style','NORMAL',
            'vector', NULL,
            'vector_color', NULL
        ) as col7,
        jsonb_build_object(
            'in_case', null,
            'filter', null,
            'text', r.measure_title,
            'text_bg_color', '#FFFFFF00',
            'text_color', null,
            'text_style','NORMAL',
            'vector', NULL,
            'vector_color', NULL
        ) as col8,
        jsonb_build_object(
            'in_case', null,
            'filter', null,
            'text', r.iso_code,
            'text_bg_color', '#FFFFFF00',
            'text_color', null,
            'text_style','NORMAL',
            'vector', NULL,
            'vector_color', NULL
        ) as col9,
        jsonb_build_object(
            'in_case', null,
            'filter', null,
            'text', r.price,
            'text_bg_color', '#FFFFFF00',
            'text_color', null,
            'text_style','NORMAL',
            'vector', NULL,
            'vector_color', NULL
        ) as col10,    
        jsonb_build_object(
            'in_case', null,
            'filter', null,
            'text',convert_date( cast(update_date::timestamp with time zone at time zone (select name from setting_user) as timestamp),  'TMDy, DD TMMon YYYY HH24:MI', (select language_code from setting_user)),
            'text_bg_color', '#FFFFFF00',
            'text_color', null,
            'text_style','NORMAL',
            'vector', NULL,
            'vector_color', NULL
        ) as col11,
        jsonb_build_object(
            'in_case', null,
            'filter', null,
            'text', r.stock_quantity,
            'text_bg_color', '#FFFFFF00',
            'text_color', null,
            'text_style','NORMAL',
            'vector', NULL,
            'vector_color', NULL
        ) as col12
    from lst_records r
    left join setting_user su on true
),

list_tmp as (
    select *
    from lst_temp
),

data_list AS (
SELECT json_agg(tmp.*) "rows" FROM (
SELECT * FROM list_tmp

) AS tmp
)
SELECT to_json(tmp.*) FROM (
    SELECT * FROM counter
    left join tmp_item_config_final on true 
    left join data_list on true
    left join t_showaction on true
) AS tmp;


