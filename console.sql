-- 1) Le type TS_VECTOR dans Postgresql

-- tsvector est un type de donnée représentant un document optimisé pour la recherche full text.
-- Un **tsvector** est une liste triée de **lexèmes**.
-- Ex, on passe un document (ici une phrase) à la fonction **to_tsvector**. Celle-ci va retourner le tsvector correspondant au document.
select 'a fat cat sat on a mat and ate a fat rat'::tsvector;
select to_tsvector('english', 'a fat cat sat on a mat and ate a fat rat');
select to_tsvector('english', 'Si six scies scient six saucissons');

--On obtient la représentation vectorielle de la phrase.
--Les lexèmes de la phrase sont extraits et triés. Le chiffre à la droite des ":"
--correspond à l'emplacement du lexème dans la phrase.


-- 2 mots peuvent retourner le même lexèmes:
select to_tsvector('english', 'satisfy satisfies') as lexèmes;
select to_tsvector('french', 'animal animaux') as lexèmes;
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
select to_tsvector('chat chien') @@ 'chat'::tsquery; -- true
select to_tsvector('chat chien') @@ 'chat & chien'::tsquery; -- true

select to_tsvector('french', 'cheval poney') @@ 'cheval'::tsquery; -- true
select to_tsvector('french', 'cheval poney') @@ 'chevaux'::tsquery; -- false -- WTF?????

-- Pourquoi chevaux ne fonctionne pas alors que si on recheche le lexème de chevaux, on trouve bien cheval??
select to_tsquery('french', 'chevaux'); -- cheval

-- Dans les 2 premières requêtes, on compare un mot à un lexème, ça ne marche pas comme ça :(
-- on doit réfléchir en terme de lexème, on va utiliser la fonction to_tsquery pour nous aider


-- FONCTION TO_TSQUERY
-- Transforme une chaîne de texte en tsquery composée de lexèmes

select to_tsquery('french', 'chevaux');

select to_tsvector('french', 'cheval poney') @@ to_tsquery('french', 'chevaux'); -- cette fois on a bien true
-- évidemment, ça marche aussi avec des prénoms
select to_tsvector('french','georges ginon') @@ to_tsquery('french', 'georges');

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

--On recherche le mot 'Dead' dans le titre des chansons
select alb."Title" as album,
       art."Name" as artiste,
       tr."Name" as titre,
       tr."Composer" as compositeur
from public."Album" alb
         join public."Artist" art on art."ArtistId" = alb."ArtistId"
         join public."Track" tr on tr."AlbumId" = alb."AlbumId"
where to_tsvector(tr."Name") @@ to_tsquery('Dead');




--On recherche le mot 'Dead' dans le titre des chansons ET dans le nom des albums
select alb."Title" as album,
       art."Name" as artiste,
       tr."Name" as titre,
       tr."Composer" as compositeur
from public."Album" alb
         join public."Artist" art on art."ArtistId" = alb."ArtistId"
         join public."Track" tr on tr."AlbumId" = alb."AlbumId"
where to_tsvector(alb."Title" || ' ' || tr."Name") @@ to_tsquery('Dead');



-- On peut visualiser le ts_vector
select al."Title" as album,
       --art."Name" as artiste,
       tr."Name" as titre,
       --tr."Composer" as compositeur,
       to_tsvector(al."Title" || ' ' || tr."Name") as fts
from public."Album" al
         join public."Artist" art on art."ArtistId" = al."ArtistId"
         join public."Track" tr on tr."AlbumId" = al."AlbumId";



-- On va créer une table spécifique pour stocker les champs 'vectorisés'
create table Docs ("TrackId" INT NOT NULL, "document" tsvector);

select * from Docs;

insert into Docs("TrackId", "document")
select tr."TrackId", to_tsvector(alb."Title" || ' ' || tr."Name")
from public."Album" alb
         join public."Artist" art on art."ArtistId" = alb."ArtistId"
         join public."Track" tr on tr."AlbumId" = alb."AlbumId";

select * from Docs;
--truncate table Docs;
--drop table Docs;

-- 3) Performances

-- Comparaison des performances entre une recherche fts 'à la volée'
-- et une recherche avec une colonne contenant le ts_vector précalculé
explain analyse
select al."Title" as album,
       art."Name" as artiste,
       tr."Name" as titre,
       tr."Composer" as compositeur
from public."Album" al
         join public."Artist" art on art."ArtistId" = al."ArtistId"
         join public."Track" tr on tr."AlbumId" = al."AlbumId"
where to_tsvector(al."Title" || ' ' || tr."Name") @@ to_tsquery('Dead');


explain analyse
select al."Title" as album,
       art."Name" as artiste,
       tr."Name" as titre,
       tr."Composer" as compositeur
from public."Album" al
         join public."Artist" art on art."ArtistId" = al."ArtistId"
         join public."Track" tr on tr."AlbumId" = al."AlbumId"
         join public.docs fts on fts."TrackId" = tr."TrackId"
where fts.document @@ to_tsquery('Dead');

-- 4) Indexation
select amname from pg_am;

-- Index GIN
create index document_idx on docs using GIN (document);



-- 5) Ranking items avec ts_rank
select al."Title" as album,
       art."Name" as artiste,
       tr."Name" as titre,
       tr."Composer" as compositeur,
       ts_rank(fts.document, to_tsquery('Dead'))
from public."Album" al
         join public."Artist" art on art."ArtistId" = al."ArtistId"
         join public."Track" tr on tr."AlbumId" = al."AlbumId"
         join public.docs fts on fts."TrackId" = tr."TrackId"
where fts.document @@ to_tsquery('Dead')
order by ts_rank(fts.document, to_tsquery('Dead')) desc;



-- ERROR???? WTF!!!!
select al."Title" as album,
       art."Name" as artiste,
       tr."Name" as titre,
       tr."Composer" as compositeur,
       ts_rank(fts.document, to_tsquery('Dead Horse'))
from public."Album" al
         join public."Artist" art on art."ArtistId" = al."ArtistId"
         join public."Track" tr on tr."AlbumId" = al."AlbumId"
         join public.docs fts on fts."TrackId" = tr."TrackId"
where fts.document @@ to_tsquery('Dead Horse')
order by ts_rank(fts.document, to_tsquery('Dead Horse')) desc;



-- ;)
select al."Title" as album,
       art."Name" as artiste,
       tr."Name" as titre,
       tr."Composer" as compositeur,
       ts_rank(fts.document, plainto_tsquery('Dead Horse'))
from public."Album" al
         join public."Artist" art on art."ArtistId" = al."ArtistId"
         join public."Track" tr on tr."AlbumId" = al."AlbumId"
         join public.docs fts on fts."TrackId" = tr."TrackId"
where fts.document @@ plainto_tsquery('Dead Horse')
order by ts_rank(fts.document, plainto_tsquery('Dead Horse')) desc;


select al."Title" as album,
       art."Name" as artiste,
       tr."Name" as titre,
       tr."Composer" as compositeur,
       ts_rank(fts.document, to_tsquery('Dead | Horse'))
from public."Album" al
         join public."Artist" art on art."ArtistId" = al."ArtistId"
         join public."Track" tr on tr."AlbumId" = al."AlbumId"
         join public.docs fts on fts."TrackId" = tr."TrackId"
where fts.document @@ to_tsquery('Dead | Horse')
order by ts_rank(fts.document, to_tsquery('Dead | Horse')) desc;


alter table docs add column document_with_weights tsvector;
select * from docs;

with subquery as (
    select tr."TrackId" as trackId,
           tr."Name" as titre,
           setweight(to_tsvector(tr."Name"), 'A')
               || setweight(to_tsvector(al."Title"), 'B') as poids
    from public."Album" al
             join public."Artist" art on art."ArtistId" = al."ArtistId"
             join public."Track" tr on tr."AlbumId" = al."AlbumId"
             join public.docs fts on fts."TrackId" = tr."TrackId"
)
update docs
set document_with_weights = subquery.poids
from subquery
where docs."TrackId" = subquery.trackId;

select * from docs;