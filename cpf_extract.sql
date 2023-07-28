create table <table_name> as

WITH ext_variables AS (
      SELECT 
      <quantite> AS volume_extract,
      <boost> AS proportion_boost  -- declarer le volume de numero 
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
            ROW_NUMBER() OVER (ORDER BY day_lead ASC) AS rn
    FROM vw_principale_tel_mobile p
    LEFT JOIN vw_shooted_table s
    ON p.tel_mobile = s.tel_mobile
    WHERE  p.tel_mobile is not null
    --AND (DATEDIFF(year,birthday_norm,current_date) between <cpfagemin> and <cpfagemax> or birthday_norm is null)
    AND LEFT(p.tel_mobile,7) not in (select LEFT(tranche_debut,7) from dim_operateurs where code_operateur in ('LYCA','LEFR','NRJ'))
    and boost = '1'
    AND day_lead > <day_lead_min>
    AND day_lead < <day_lead_max>
    and (DATEDIFF(day,TO_DATE(shooted_tout,'YYYY-MM-DD'),current_date) > 7)
   GROUP BY p.tel_mobile,p.day_lead)
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
    WHERE shooted_tout is NULL
    AND (DATEDIFF(year,birthday_norm,current_date) between <cpfagemin> and <cpfagemax> or birthday_norm is null)
    AND p.tel_mobile is not null
    AND LEFT(p.tel_mobile,7) not in (select LEFT(tranche_debut,7) from dim_operateurs where code_operateur in ('LYCA','LEFR','NRJ'))
    and boost = '0'
    GROUP BY p.tel_mobile)
WHERE rn <= 0*(select volume_extract from ext_variables)
),



CPF_NON_SHOOTE AS (          
SELECT 
tel_mobile,         
gender , 
firstname ,
lastname ,   
email ,     
zipcode,
statut_habitation,  
rn,
'CNS' as cohort
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
    WHERE  shooted_cpf is NULL
    and shooted_tout is not null
    AND (DATEDIFF(year,birthday_norm,current_date) between <cpfagemin> and <cpfagemax> or birthday_norm is null)
    AND LEFT(p.tel_mobile,7) not in (select LEFT(tranche_debut,7) from dim_operateurs where code_operateur in ('LYCA','LEFR','NRJ'))
    AND p.tel_mobile is not null
    and boost = '0'
    GROUP BY p.tel_mobile)
WHERE rn <= 0*(select volume_extract from ext_variables) 
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
'DIM_P' as cohort
FROM (
    SELECT DISTINCT p.tel_mobile,
            max(gender) AS gender,
            max(firstname) AS firstname, 
            max(lastname) AS lastname, 
            max(email) AS email, 
            max(p.zipcode) as zipcode ,
            max(statut_habitation) AS statut_habitation,
            ROW_NUMBER() OVER (ORDER BY (CASE WHEN shooted_cpf is null then TO_DATE('1900-01-01','YYYY-MM-DD') else TO_DATE(shooted_cpf,'YYYY-MM-DD') end) ASC) AS rn
    FROM vw_principale_tel_mobile p
    LEFT JOIN vw_shooted_table s
    on p.tel_mobile = s.tel_mobile
    left join densite d
    on p.zipcode = d.zipcode
    WHERE shooted_cpf is not null
    AND (DATEDIFF(year,birthday_norm,current_date) between <cpfagemin> and <cpfagemax> or birthday_norm is null)
    AND p.tel_mobile is not null
    AND boost = '0'
    and DATEDIFF(day,to_date(shooted_cpf,'YYYY-MM-DD'),current_date) > <nombrejourpashootee>
    and DATEDIFF(day,TO_DATE(shooted_tout,'YYYY-MM-DD'),current_date) > 15 
    AND LEFT(p.tel_mobile,7) not in (select LEFT(tranche_debut,7) from dim_operateurs where code_operateur in ('LYCA','LEFR','NRJ'))
    GROUP BY p.tel_mobile,shooted_cpf)
    WHERE rn <= (select volume_extract from ext_variables) - (select count() from CPF_NON_SHOOTE) - (SELECT COUNT() FROM NON_SHOOTE) - (SELECT COUNT(*) FROM P_BOOST))


-- Pour verif (avec cohortes)
/*
SELECT * FROM P_BOOST
UNION 
SELECT * FROM NON_SHOOTE
UNION 
SELECT * FROM CPF_NON_SHOOTE
UNION 
SELECT * FROM CAMPAGNE_SHOOTE
*/

-- Production (sans cohortes avec champs renomés)
SELECT 
lastname as nom,
firstname,
email,
tel_mobile as phone,
Null as gender,
gender as civilite,
Null as code,
Null as utm,
Null as vide,
cohort
FROM P_BOOST
UNION 
SELECT 
lastname as nom,
firstname,
email,
tel_mobile as phone,
Null as gender,
gender as civilite,
Null as code,
Null as utm,
Null as vide,
cohort
FROM NON_SHOOTE
UNION 
SELECT lastname as nom,
firstname,
email,
tel_mobile as phone,
Null as gender,
gender as civilite,
Null as code,
Null as utm,
Null as vide,
cohort
FROM CPF_NON_SHOOTE
UNION 
SELECT 
lastname as nom,
firstname,
email,
tel_mobile as phone,
Null as gender,
gender as civilite,
Null as code,
Null as utm,
Null as vide,
cohort
FROM CAMPAGNE_SHOOTE
