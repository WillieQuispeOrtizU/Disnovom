WITH 
tmp_usr as (
	select id_time_zone, language_code
    from userpotencie_userpotencie uu 
	where uu.nickname_environment ='__owner__' and uu.nickname_member = '__creator__' and uu.state 
), 

tmp_usr_dictionary_language as (
    select "key", message
    from public.user_dictionary_language
    where nickname_owner = '__owner__' and ("key" in ('EXTERNAL_USER', 'INTERNAL_USER')) and language_code in (select language_code from tmp_usr) and state
),
tmp_dictionary_language as (
    select key,message
    from public.dictionary_language
    where ("key" in ('EXTERNAL_USER', 'INTERNAL_USER')) and language_code in (select language_code from tmp_usr) and state and not exists (select * from tmp_usr_dictionary_language)
),
tmp_dict as (
    select "key", message from tmp_usr_dictionary_language
    union
    select "key", message from tmp_dictionary_language where "key" not in (select "key" from tmp_usr_dictionary_language) 
),

tmp_item_config as (
    select json_build_object(
        'list', json_build_object (
            'title', (select message from tmp_dict where key = 'LIST_42_TITLE'))
    ) as item_config
),

list_tmp AS (
    SELECT 
        null "action", 
        null "badge_vector_name", 
        '#FFFFFF' bg_vector_name, 
        null "block_if_empty",
        'INTERNAL_USER' code,
        null "color_action_icon", 
        null "color_badge", 
        null "color_icon_a", 
        null "color_icon_b", 
        null "color_icon_c", 
        null "color_icon_d", 
        '#0072CF' "color_vector_name", 
        true "flag_condition", 
        null "icon_subtitle_a", 
        null "icon_subtitle_b", 
        null "icon_subtitle_c", 
        null "icon_subtitle_d", 
        null "id", 
        null "id_action", 
        null "image_action", 
        null "image_profile", 
        null "metadata_action", 
        null "subtitle", --field2
        null "subtitle_a", 
        null "subtitle_b", 
        null "subtitle_c", 
        null "subtitle_d", 
        (select message from tmp_dict where "key" = 'INTERNAL_USER') "title", 
        null "vector_action", 
        'vct_4x_label' "vector_name_profile"
    UNION ALL
    SELECT 
        null "action", 
        null "badge_vector_name", 
        '#FFFFFF' bg_vector_name, 
        null "block_if_empty",
        'EXTERNAL_USER' code,
        null "color_action_icon", 
        null "color_badge", 
        null "color_icon_a", 
        null "color_icon_b", 
        null "color_icon_c", 
        null "color_icon_d", 
        '#0072CF' "color_vector_name", 
        true "flag_condition", 
        null "icon_subtitle_a", 
        null "icon_subtitle_b", 
        null "icon_subtitle_c", 
        null "icon_subtitle_d", 
        null "id", 
        null "id_action", 
        null "image_action", 
        null "image_profile", 
        null "metadata_action", 
        null "subtitle",
        null "subtitle_a", 
        null "subtitle_b", 
        null "subtitle_c", 
        null "subtitle_d", 
        (select message from tmp_dict where "key" = 'EXTERNAL_USER') "title", 
        null "vector_action", 
        'vct_4x_label' "vector_name_profile"
    UNION ALL
),

counter AS (
	SELECT count(*) "counter" FROM list_tmp
), 
/*END SELECT_SUMMARY*/
data_list AS (
	SELECT json_agg(tmp.*) "rows" FROM (
        SELECT  * FROM list_tmp   
    ) AS tmp
) 
SELECT to_json(tmp.*) FROM ( 
	SELECT * FROM counter
	left join data_list on true
	left join tmp_item_config on true
) AS tmp; 
