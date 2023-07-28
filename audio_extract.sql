create table <table_name> as -- Debut des tables temporaires de variables
WITH ext_variables AS (
      SELECT
      <quantite> AS volume_extract,  -- declarer le volume de numero
      <boost> AS proportion_boost, -- declarer la proportion de BOOST
      <santeagemin> AS age_min,
      <santeagemax> AS age_max
      ),

geo_variables AS (
    <zipcodefromat>
    ),

-- Fin des tables temporaires de variables


P_BOOST AS (               --- CTE - Common Table Expression 1 - Les BOOST
SELECT
tel_mobile,
gender ,
firstname ,
lastname ,
email ,
zipcode,
statut_habitation,
rn,
'B' as cohort
FROM (
    SELECT DISTINCT p.tel_mobile,
            max(gender) AS gender,
            max(firstname) AS firstname,
            max(lastname) AS lastname,
            max(email) AS email,
            max(p.zipcode) as zipcode ,
            max(statut_habitation) AS statut_habitation,
            ROW_NUMBER() OVER (ORDER BY (CASE WHEN shooted_audio is null then TO_DATE('1900-01-01','YYYY-MM-DD') else TO_DATE(shooted_audio,'YYYY-MM-DD') end) ASC) AS rn
    FROM vw_principale_tel_mobile p
    LEFT JOIN vw_shooted_table s
    ON p.tel_mobile = s.tel_mobile
    WHERE  left(p.zipcode,<santezipcodeType>) in (select left(zipcode,<santezipcodeType>) from geo_variables)
    AND p.tel_mobile is not null
    AND DATEDIFF(day,to_date(shooted_audio,'YYYY-MM-DD'),current_date) > <nombrejourpashootee>
    AND DATEDIFF(year,birthday_norm,current_date) between (select age_min from ext_variables) and (select age_max from ext_variables)
    and boost = '1'


   GROUP BY p.tel_mobile,shooted_audio)
WHERE rn <= ((select proportion_boost from ext_variables) * (select volume_extract from ext_variables))
),




NON_SHOOTE AS (
SELECT
tel_mobile,
gender ,
firstname ,
lastname ,
email ,
zipcode,
statut_habitation,
rn,
'NS' as cohort
FROM (
    SELECT DISTINCT p.tel_mobile,
            max(gender) AS gender,
            max(firstname) AS firstname,
            max(lastname) AS lastname,
            max(email) AS email,
            max(p.zipcode) as zipcode ,
            max(statut_habitation) AS statut_habitation,
            ROW_NUMBER() OVER (ORDER BY rand()) AS rn
    FROM vw_principale_tel_mobile p
    LEFT JOIN vw_shooted_table s
    on p.tel_mobile = s.tel_mobile
    WHERE
    shooted_tout is NULL
    and left(p.zipcode,<santezipcodeType>) in (select left(zipcode,<santezipcodeType>) from geo_variables)
   AND DATEDIFF(year,birthday_norm,current_date) between (select age_min from ext_variables) and (select age_max from ext_variables)
    AND p.tel_mobile is not null
    and boost = '0'
    GROUP BY p.tel_mobile)
WHERE rn <= 0.25*(select volume_extract from ext_variables)
),



SANTE_NON_SHOOTE AS (
SELECT
tel_mobile,
gender ,
firstname ,
lastname ,
email ,
zipcode,
statut_habitation,
rn,
'S_NS' as cohort
FROM (
    SELECT DISTINCT p.tel_mobile,
            max(gender) AS gender,
            max(firstname) AS firstname,
            max(lastname) AS lastname,
            max(email) AS email,
            max(p.zipcode) as zipcode ,
            max(statut_habitation) AS statut_habitation,
            ROW_NUMBER() OVER (ORDER BY (CASE WHEN s.shooted_sante is null then TO_DATE('1900-01-01','YYYY-MM-DD') else TO_DATE(s.shooted_sante,'YYYY-MM-DD') end) ASC) AS rn
    FROM vw_principale_tel_mobile p
    LEFT JOIN vw_shooted_table s
    on p.tel_mobile = s.tel_mobile
    WHERE  ((shooted_sante is NULL and shooted_tout is not null) or (shooted_audio is null and shooted_tout is not null))
    AND DATEDIFF(year,birthday_norm,current_date) between (select age_min from ext_variables) and (select age_max from ext_variables)
    and left(p.zipcode,<santezipcodeType>) in (select left(zipcode,<santezipcodeType>) from geo_variables)
    and DATEDIFF(day,TO_DATE(shooted_tout,'YYYY-MM-DD'),current_date) > 15
    AND p.tel_mobile is not null
    and boost = '0'
    GROUP BY p.tel_mobile,s.shooted_sante)
WHERE rn <= 0.25*(select volume_extract from ext_variables) - (SELECT COUNT(*) FROM NON_SHOOTE) -  (SELECT COUNT(*) FROM P_BOOST)
),



CAMPAGNE_SHOOTE AS (          --- CTE - Common Table Expression 1 - Que les Proprietaire non shootes energie non appart
SELECT
tel_mobile,
gender ,
firstname ,
lastname ,
email ,
zipcode,
statut_habitation,
rn,
'CS' as cohort
FROM (
    SELECT DISTINCT p.tel_mobile,
            max(gender) AS gender,
            max(firstname) AS firstname,
            max(lastname) AS lastname,
            max(email) AS email,
            max(p.zipcode) as zipcode ,
            max(statut_habitation) AS statut_habitation,
            ROW_NUMBER() OVER (ORDER BY shooted_sante ASC) AS rn
    FROM vw_principale_tel_mobile p
    LEFT JOIN vw_shooted_table s
    on p.tel_mobile = s.tel_mobile
    WHERE shooted_sante is not null
    and left(p.zipcode,<santezipcodeType>) in (select left(zipcode,<santezipcodeType>) from geo_variables)
    AND DATEDIFF(year,birthday_norm,current_date) between (select age_min from ext_variables) and (select age_max from ext_variables)
    AND p.tel_mobile is not null
    AND DATEDIFF(day,to_date(shooted_audio,'YYYY-MM-DD'),current_date) > <nombrejourpashootee>
    and DATEDIFF(day,TO_DATE(shooted_tout,'YYYY-MM-DD'),current_date) > 15
    AND boost = '0'
    GROUP BY p.tel_mobile,shooted_sante)
    WHERE rn <= (select volume_extract from ext_variables) - (select count(*) from SANTE_NON_SHOOTE)-(SELECT COUNT(*) FROM NON_SHOOTE) -  (SELECT COUNT(*) FROM P_BOOST)) 
    
    SELECT 
lastname as nom,
firstname,
email,
tel_mobile as phone,
Null as gender,
gender as civiliter,
Null as code,
zipcode,
Null as utm,
cohort
 FROM P_BOOST
UNION
SELECT 
lastname as nom,
firstname,
email,
tel_mobile as phone,
Null as gender,
gender as civiliter,
Null as code,
zipcode,
Null as utm,
cohort
FROM NON_SHOOTE
UNION 
SELECT lastname as nom,
firstname,
email,
tel_mobile as phone,
Null as gender,
gender as civiliter,
Null as code,
zipcode,
Null as utm,
cohort
FROM SANTE_NON_SHOOTE
UNION 
SELECT 
lastname as nom,
firstname,
email,
tel_mobile as phone,
Null as gender,
gender as civiliter,
Null as code,
zipcode,
Null as utm,
cohort
FROM CAMPAGNE_SHOOTE"""
