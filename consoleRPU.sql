-- Volumétrie > 12 Millions (12114837 ce matin!!!)

-- La table contient plusieurs colonnes tsvector avec des valeurs uniques ou plusieurs valeurs

select count(*) from person_search;

select * from person_search limit 3;

select *
from person_search ps
where ps.document @@ to_tsquery('french', 'ab:* & t:*');


-- Travail réalisé avec la MOA MAIF Vie pour identifier un mode de classification des résultats proche
-- voir meilleur que celui retourné par la recherche elasticsearch existante.

-- Analyse initial sur Excel à partir d'échantillon de données pour pouvoir circonscrire le besoin au mieux.
-- Identifier les critères et trouver méthode permettant de se rapprocher au mieux des attentes.

select rang,
       code,
       case when substring(code, 1, 1) = '0' then 'Erroné'
            when substring(code, 1, 1) = '1' then 'Exact'
            when substring(code, 1, 1) = '2' then 'Approchant'
           end as Nom,
       case when substring(code, 2, 1) = '0' then 'Erroné'
            when substring(code, 2, 1) = '1' then 'Exact'
            when substring(code, 2, 1) = '2' then 'Approchant'
           end as Prenom,
       case when substring(code, 3, 1) = '0' then 'Erroné'
            when substring(code, 3, 1) = '1' then 'Exact'
            when substring(code, 3, 1) = '2' then 'au 01/01 de l année saisie'
            when substring(code, 3, 1) = '3' then 'année saisie exact'
           end as DateNaissance
from maif_vie_ranks;


-- Pour pallier au manque de granularité de la fonction ts_rank,
-- on s'est appuyé sur une autre fonction de postgresql qui est le calcul de similarité

-- si la similarité est exact on obtient la valeur 1
with l(term) as (
    values
    ('john'),
    ('joh'),
    ('johhhhhhhh'),
    ('joe'),
    ('geo')
)
select term, similarity('john',term) from l;


-- pendant la phase de développement on a du identifié des "seuils" pour discriminer entre les valeurs
-- approchantes et erronés
-- en fonction des seuils, certains cas remontent plus ou moins haut des les resultats de recherche
-- démarche strictement empirique

-- Beaucoup de tests de non régression!!!!

select to_tsvector('english', '19801010') @@ to_tsquery('english', '19801010');



-- Création d'un système de ranking "custom"

explain analyse
select
        json ->> 'lastName' as "lastName", json ->> 'firstName' as "firstName", json ->> 'birthDate' as "birthDate",
    similarity(json ->> 'lastName', 'bernard') as "NOM",
    similarity(json ->> 'firstName', 'elise') as "PRENOM",
    similarity(json ->> 'birthDate', '1988-06-09') as "DATE DE NAISSANCE",
    npdn -- Ranking spécifique NomPrenomDateNaissance
from (
    select public.person.json, (
    -- Ici les calculs de similarité
    case when similarity( public.person.json ->> 'lastName', 'bernard') = 1.0 then '1'
    when similarity( public.person.json ->> 'lastName', 'bernard') < 0.4 then '0' else '2' end
    ||
    case when similarity( public.person.json ->> 'firstName', 'elise') = 1.0 then '1'
    when similarity( public.person.json ->> 'firstName', 'elise') < 0.4 then '0' else '2' end
    ||
    case when cast( public.person.json ->> 'birthDate' as date) = cast('1988-06-09' as date) then '1'
    when cast( public.person.json ->> 'birthDate' as date) = cast('1988-01-01' as date) then '2'
    when (date_part('year', cast( public.person.json ->> 'birthDate' as date)) - 1988) = 0 then '3' else '0' end) as NPDN
    from public.person
    join public.person_search on public.person_search.person_id = public.person.id
    where (
    -- restriction basées sur nos colonnes tsvector
    public.person_search.document @@ to_tsquery('kitsune', '1988:*')
    and public.person_search.document @@ to_tsquery('kitsune', 'bernard:* | elise:*')
    )
    ) as p
    join public.maif_vie_ranks on public.maif_vie_ranks.code = p.npdn
order by rang asc limit 3000;


-- Recherche rapide grâce aux restrictions sur les ts_vector

explain analyse select count(*)
                from person_search ps
                where ps.document @@ to_tsquery('kitsune', '1989:*');