-- FTS_WITH_PG

-- 1) C'est quoi une recherche full text?

-- C'est la recherche d'un ou plusieurs documents satisfaisant une requête. Ces documents seront éventuellement
-- retournés de manière ordonnée en fonction de leur similarité envers la requête. Les notions de requête et de
-- similarité sont flexibles et vont dépendre des spécificités applicatives.

-- Un 'document' peut être de plusieurs type, il peut s'agir d'un fichier texte, d'un champ textuel, ou d'un fichier
-- html par exemple.

-- Les opérateurs de recherche textuel existent depuis plusieurs années. Postgresql dispose de plusieurs opérateurs
-- comme ~, ~*, LIKE, ILIKE pour les champs de type texte. Cependant, ces opérateurs ont des lacunes qui ne permettent
-- pas de satisfaire les besoins qui peuvent émerger du fait d'une recherche plein texte.

-- * pas de support de la langue, ex: animal et animaux. En recherchant un document contenant le terme 'animal', on
--   voudrait pouvoir remonter le terme 'animaux'
-- * pas de possibilité d'ordonner les résultats (ranking)
-- * lenteur, car tous les documents d'une table seront parcourus sans possibilité d'indexation.

-- Les améliorations qui ont permis la rechecher full text dans postgres sont venus grâce à l'idée de préprocesser des
-- documents au moment de l'indexation pour permettre d'économiser du temps au moment de la recherche.

-- Ces pré-traitements inclus les étapes suivantes :
-- Suppression des mots outils ou mots vides
-- Lemmatisation stemming : Obtenir la racine des mots
-- Remplacer des synonymes
-- Utiliser un thésaurus


-- 1) Le type TS_VECTOR dans Postgresql

-- tsvector est un type de donnée représentant un document optimisé pour la recherche full text.
-- Un **tsvector** est une liste triée de **lexèmes**.
-- Ex, on passe un document (ici une phrase) à la fonction **to_tsvector**. Celle-ci va retourner le tsvector correspondant au document.
select 'a fat cat sat on a mat and ate a fat rat'::tsvector;
select to_tsvector('english', 'a fat cat sat on a mat and ate a fat rat');
select to_tsvector('french', 'Si six scies scient six saucissons');

select to_tsvector('french', 'concombre poutre concupiscant nyctalope altermondialiste');

select to_tsvector('french', 'ts_vector est un type de données représentant un document optimisé pour la recherche full text');

--On obtient la représentation vectorielle de la phrase.
--Les lexèmes de la phrase sont extraits et triés. Le chiffre à la droite des ":" correspond à l'emplacement du lexème dans la phrase.


-- 2 mots peuvent retourner le même lexèmes:
select to_tsvector('french', 'animal animaux');
-- retourne : 'animal':1,2

-- Identifier des tokens
select alias,description,token from ts_debug('Maif France contact@maif.fr http://maif.fr/about.html');


-- Comment interroger un tsvector?

-- Type TSQUERY
-- Comprend les lexèmes recherchés qui peuvent être combinés avec les opérateurs suivants :
-- & (AND)
-- | (OR)
-- ! (NOT)
-- L'opérateur de recherche de phrase (depuis la 9.6): <-> (FOLLOWED BY)

-- Ex: on génère une requête sur 2 lexèmes
select 'chat & chien'::tsquery;

-- OPERATEUR @@
-- permet d'interroger un tsvector
-- ici on recherche si 'chat' est bien contenu dans la représentation vectorielle de 'chat chien'
select to_tsvector('chat chien') @@ to_tsquery('chat'); -- true
select to_tsvector('chat chien') @@ to_tsquery('chat & chien'); -- true

select to_tsvector('french', 'cheval poney') @@ to_tsquery('cheval'); -- true
select to_tsvector('french', 'cheval poney') @@ to_tsquery('chevaux'); -- false -- WTF?????

-- Pourquoi chevaux ne fonctionne pas alors que si on recheche le lexème de chevaux, on trouve bien cheval??
select to_tsquery('french', 'chevaux'); -- cheval

-- Dans les 2 premières requêtes, on compare un mot à un lexème, ça ne marche pas comme ça :(
-- on doit réfléchir en terme de lexème, on va utiliser la fonction to_tsquery pour nous aider


-- FONCTION TO_TSQUERY
-- Transforme une chaîne de texte en tsquery composée de lexèmes

select to_tsquery('french', 'chevaux');

select to_tsvector('french', 'cheval poney') @@ to_tsquery('french', 'chevaux'); -- cette fois on a bien true

-- Quelques exemples:
select to_tsvector('french', 'cheval poney') @@ to_tsquery('french', 'chevaux & chat'); -- false
select to_tsvector('french', 'cheval poney') @@ to_tsquery('french', 'chevaux | chat'); -- true
select to_tsvector('french', 'cheval poney') @@ to_tsquery('french', '!chat'); -- true

-- + complexe:
select to_tsvector('french', 'cheval poney') @@ to_tsquery('french', 'aux:*'); -- false
select to_tsvector('french', 'cheval poney') @@ to_tsquery('french', 'chev:*'); -- true
select to_tsvector('french', 'cheval poney') @@ to_tsquery('french', 'chev:* & pon:*'); -- true
select to_tsvector('french', 'cheval poney') @@ to_tsquery('french', '(chev:* & tet:*) | (chev:* & pon:*)'); -- true


-- PLAINTO_TSQUERY
-- Convertit une chaîne de text en tsquery

select to_tsquery('french', 'chevaux & poney');
select plainto_tsquery('french', 'chevaux poney');

select to_tsvector('french', 'cheval poney') @@ to_tsquery('french', 'chevaux & poney'); -- ERROR
select to_tsvector('french', 'cheval poney') @@ to_tsquery('french', 'chevaux & poney'); -- true
-- est équivalent à:
select to_tsvector('french', 'cheval poney') @@ plainto_tsquery('french', 'chevaux poney'); -- true
-- on considère que l'espace est équivalent au &, donc:
select to_tsvector('french', 'cheval poney') @@ plainto_tsquery('french', 'chevaux chat'); -- false




-- 2) Exemples avec des vrais données

-- Une requête qui retourne album, artiste, titre, compositeur
-- 500 lignes
select alb."Title" as album, art."Name" as artiste, tr."Name" as titre
from public."Album" alb
         join public."Artist" art on art."ArtistId" = alb."ArtistId"
         join public."Track" tr on tr."AlbumId" = alb."AlbumId";


-- Recherche dans une seule colonne: On recherche le mot 'Dead' dans le titre des chansons
select alb."Title" as album, art."Name" as artiste, tr."Name" as titre, to_tsvector(tr."Name")
from public."Album" alb
         join public."Artist" art on art."ArtistId" = alb."ArtistId"
         join public."Track" tr on tr."AlbumId" = alb."AlbumId"
where to_tsvector(tr."Name") @@ to_tsquery('Dead');



--On recherche le mot 'Dead' dans le titre des chansons ET dans le nom des albums
select alb."Title" as album, art."Name" as artiste, tr."Name" as titre, to_tsvector(alb."Title" || ' ' || tr."Name")
from public."Album" alb
         join public."Artist" art on art."ArtistId" = alb."ArtistId"
         join public."Track" tr on tr."AlbumId" = alb."AlbumId"
where to_tsvector(alb."Title" || ' ' || tr."Name") @@ to_tsquery('Dead');



-- On va créer une table spécifique pour stocker les champs 'vectorisés'
drop table Docs;
select * from Docs;

-- le champ TrackId fera le lien avec l'identifiant des chansons
-- le champ document est de type tsvector
create table Docs ("TrackId" INT NOT NULL, "document" tsvector);
select * from Docs;

insert into Docs("TrackId", "document")
select tr."TrackId", to_tsvector(alb."Title" || ' ' || tr."Name")
from public."Album" alb
         join public."Artist" art on art."ArtistId" = alb."ArtistId"
         join public."Track" tr on tr."AlbumId" = alb."AlbumId";

select * from Docs;

-- On peut faire la même requête mais sur le champ document cette fois
select alb."Title" as album, art."Name" as artiste, tr."Name" as titre
from public."Album" alb
         join public."Artist" art on art."ArtistId" = alb."ArtistId"
         join public."Track" tr on tr."AlbumId" = alb."AlbumId"
         join public."docs" doc on doc."TrackId" = tr."TrackId"
where doc.document @@ to_tsquery('Dead');

-- 3) Performances

-- Comparaison des performances entre une recherche fts 'à la volée'
-- et une recherche avec une colonne contenant le ts_vector précalculé
explain analyse select al."Title" as album, art."Name" as artiste, tr."Name" as titre
                from public."Album" al
                         join public."Artist" art on art."ArtistId" = al."ArtistId"
                         join public."Track" tr on tr."AlbumId" = al."AlbumId"
                where to_tsvector(al."Title" || ' ' || tr."Name") @@ to_tsquery('Dead');

explain analyse select al."Title" as album, art."Name" as artiste, tr."Name" as titre
                from public."Album" al
                         join public."Artist" art on art."ArtistId" = al."ArtistId"
                         join public."Track" tr on tr."AlbumId" = al."AlbumId"
                         join public.docs doc on doc."TrackId" = tr."TrackId"
                where doc.document @@ to_tsquery('Dead');


-- 4) Indexation
select amname from pg_am;

-- Index GIN
alter table docs add column document_with_idx tsvector;
select * from Docs;

with subquery as (
    select tr."TrackId" as trackId, to_tsvector(alb."Title" || ' ' || tr."Name") as vect
    from public."Album" alb
             join public."Artist" art on art."ArtistId" = alb."ArtistId"
             join public."Track" tr on tr."AlbumId" = alb."AlbumId"
             join public.docs fts on fts."TrackId" = tr."TrackId"
)
update docs
set document_with_idx = subquery.vect
from subquery
where docs."TrackId" = subquery.trackId;


create index document_idx on docs using GIN (document);
select * from pg_indexes where tablename = 'docs';

explain analyse select al."Title" as album, art."Name" as artiste, tr."Name" as titre
                from public."Album" al
                         join public."Artist" art on art."ArtistId" = al."ArtistId"
                         join public."Track" tr on tr."AlbumId" = al."AlbumId"
                         join public.docs doc on doc."TrackId" = tr."TrackId"
                where doc.document @@ to_tsquery('Dead');

explain analyse select al."Title" as album, art."Name" as artiste, tr."Name" as titre
                from public."Album" al
                         join public."Artist" art on art."ArtistId" = al."ArtistId"
                         join public."Track" tr on tr."AlbumId" = al."AlbumId"
                         join public.docs doc on doc."TrackId" = tr."TrackId"
                where doc.document_with_idx @@ to_tsquery('Dead');


-- 5) Ranking items avec ts_rank
select al."Title" as album, art."Name" as artiste, tr."Name" as titre, ts_rank(doc.document_with_idx, to_tsquery('Dead'))
from public."Album" al
         join public."Artist" art on art."ArtistId" = al."ArtistId"
         join public."Track" tr on tr."AlbumId" = al."AlbumId"
         join public.docs doc on doc."TrackId" = tr."TrackId"
where doc.document_with_idx @@ to_tsquery('Dead')
order by ts_rank(doc.document_with_idx, to_tsquery('Dead')) desc;


alter table docs add column document_with_weights tsvector;
select * from docs;

with subquery as (
    select tr."TrackId" as trackId,
           setweight(to_tsvector(tr."Name"), 'B')
               || setweight(to_tsvector(al."Title"), 'A') as poids
    from public."Album" al
             join public."Artist" art on art."ArtistId" = al."ArtistId"
             join public."Track" tr on tr."AlbumId" = al."AlbumId"
             join public.docs fts on fts."TrackId" = tr."TrackId"
)
update docs
set document_with_weights = subquery.poids
from subquery
where docs."TrackId" = subquery.trackId;

-- Recherche avec setWeight A sur le titre de l'album
select al."Title" as album, art."Name" as artiste, tr."Name" as titre, ts_rank(doc.document_with_weights, to_tsquery('Dea:*'))
from public."Album" al
         join public."Artist" art on art."ArtistId" = al."ArtistId"
         join public."Track" tr on tr."AlbumId" = al."AlbumId"
         join public.docs doc on doc."TrackId" = tr."TrackId"
where doc.document_with_weights @@ to_tsquery('Dea:*')
order by ts_rank(doc.document_with_weights, to_tsquery('Dea:*')) desc;


-- Création d'un trigger pour la mise à jour







-- ERROR???? WTF!!!!
select al."Title" as album, art."Name" as artiste, tr."Name" as titre, ts_rank(fts.document, to_tsquery('Dead Horse'))
from public."Album" al
         join public."Artist" art on art."ArtistId" = al."ArtistId"
         join public."Track" tr on tr."AlbumId" = al."AlbumId"
         join public.docs fts on fts."TrackId" = tr."TrackId"
where fts.document @@ to_tsquery('Dead Horse')
order by ts_rank(fts.document, to_tsquery('Dead Horse')) desc;

-- ;)
select al."Title" as album, art."Name" as artiste, tr."Name" as titre, ts_rank(fts.document, plainto_tsquery('Dead Horse'))
from public."Album" al
         join public."Artist" art on art."ArtistId" = al."ArtistId"
         join public."Track" tr on tr."AlbumId" = al."AlbumId"
         join public.docs fts on fts."TrackId" = tr."TrackId"
where fts.document @@ plainto_tsquery('Dead Horse')
order by ts_rank(fts.document, plainto_tsquery('Dead Horse')) desc;


select al."Title" as album, art."Name" as artiste, tr."Name" as titre, ts_rank(fts.document, to_tsquery('Dead | Horse'))
from public."Album" al
         join public."Artist" art on art."ArtistId" = al."ArtistId"
         join public."Track" tr on tr."AlbumId" = al."AlbumId"
         join public.docs fts on fts."TrackId" = tr."TrackId"
where fts.document @@ to_tsquery('Dead | Horse')
order by ts_rank(fts.document, to_tsquery('Dead | Horse')) desc;


-- KITSUNE_PPROD

select count(*) from person_search; -- 12114331

select * from person_search limit 3;

select *
from person_search ps
where ps.document @@ to_tsquery('french', 'alem:* & guillaume:*');

select *
from person_search ps
where ps.document @@ to_tsquery('french', 'alem');

select similarity('john','joh');
select similarity('joe','joh');

select to_tsvector('english', '19801010') @@ to_tsquery('english', '19801010');

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

-- Création d'un système de ranking "custom"

select
    --json ->> 'lastName' as "lastName",
    --json ->> 'firstName' as "firstName",
    --json ->> 'birthDate' as "birthDate",
    similarity(json ->> 'lastName', 'bernard') as "NOM",
    similarity(json ->> 'firstName', 'elise') as "PRENOM",
    similarity(json ->> 'birthDate', '1988-06-09') as "DATE DE NAISSANCE",
    npdn -- Ranking spécifique NomPrenomDateNaissance
from (
         select public.person.json, (
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
                           public.person_search.document @@ to_tsquery('kitsune', '1988:*')
                       and public.person_search.document @@ to_tsquery('kitsune', 'bernard:* | elise:*')
                   )
     ) as p
         join public.maif_vie_ranks on public.maif_vie_ranks.code = p.npdn
order by rang asc limit 300;



explain analyse select count(*)
                from person_search ps
                where ps.document @@ to_tsquery('kitsune', '1989:*');