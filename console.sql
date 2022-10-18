-- FTS_WITH_PG

-- ********* Qu'est ce qu'une recherche full text?

-- C'est la recherche d'un ou plusieurs documents satisfaisant une requête.
--
-- Ces documents seront éventuellement retournés de manière ordonnée en fonction
-- de leur similarité envers la requête. Les notions de requête et de
-- similarité sont flexibles et vont dépendre des spécificités applicatives.

-- Un 'document' peut être de plusieurs type
--  * un fichier texte
--  * un champ textuel
--  * un fichier html...

-- Les opérateurs de recherche textuel existent depuis plusieurs années.
-- Postgresql dispose de plusieurs opérateurs comme ~, ~*, LIKE, ILIKE.

-- Cependant, ces opérateurs ont des lacunes qui ne permettent pas de satisfaire

-- les besoins qui peuvent émerger du fait d'une recherche plein texte.
-- * pas de support de la langue, ex: animal et animaux.
--      En recherchant un document contenant le terme 'animal', on voudrait pouvoir remonter le terme 'animaux'
-- * pas de possibilité d'ordonner les résultats (ranking)
-- * lenteur, car tous les documents d'une table seront parcourus sans possibilité d'indexation.

-- Les améliorations qui ont permis la recheche full text dans postgres
-- sont venus grâce à l'idée de préprocesser des documents au moment de
-- l'indexation pour permettre d'économiser du temps au moment de la recherche.

-- Ces pré-traitements inclus les étapes suivantes :
-- * Suppression des mots outils ou mots vides
-- * Lemmatisation (stemming) : Obtenir la racine des mots
-- * Remplacer des synonymes
-- * Utiliser un thésaurus


-- I - Vue d'ensemble de la recherche Full Text

-- 1) TS_VECTOR : type de donnée représentant un document optimisé pour la recherche full text.

-- Un **tsvector** est une liste triée de **lexèmes**.

-- Lexème?
-- Les mots utiles et seulement leur racine.
-- Exemple : un verbe sans terminaison : Empêcher ⇒ empech


-- Ex, on passe un document (ici une phrase) à la fonction **to_tsvector**. Celle-ci va retourner le tsvector correspondant au document.
select to_tsvector('french', 'ceci est un type de données représentant un document optimisé pour la recherche full text document!!');
---------------------------------------------------------------
-- 'cec':1 'docu':9 'don':6 'full':14 'optimis':10 'recherch':13 'représent':7 'text':15 'typ':4


-- On obtient la représentation vectorielle de la phrase.
-- Les lexèmes de la phrase sont extraits et triés.
-- Le chiffre à la droite des ":" correspond à l'emplacement du lexème dans la phrase.
-- on ne retrouve plus 'est' 'un' 'de' 'pour' 'la', ainsi que les signes de ponctuation

-- Si plusieurs occurences d'un même mot, la fonction en tient compte
-- 2 mots différents peuvent retourner le même lexèmes:
select to_tsvector('french', 'animal animaux'); -- retourne : 'animal':1,2

select to_tsvector('<HTML>
<HEAD>
<TITLE>Your Title Here</TITLE>
</HEAD>
<BODY BGCOLOR="FFFFFF">
<CENTER><IMG SRC="clouds.jpg" ALIGN="BOTTOM"> </CENTER>
<HR>
<a href="http://somegreatsite.com">Link Name</a>is a link to another nifty site
<H1>This is a Header</H1>
<H2>This is a Medium Header</H2>
Send me mail at <a href="mailto:support@yourcompany.com">
support@yourcompany.com</a>.
<P> This is a new paragraph!
<P> <B>This is a new paragraph!</B>
<BR> <B><I>This is a new sentence without a paragraph break, in bold italics.</I></B>
<HR>
</BODY>
</HTML>');



select * from ts_debug('french', 'ceci est un type de données représentant un document optimisé pour la recherche full text!!');




-- 2) TS_QUERY : un type de données pour les requêtes textuels, permettant d'interroger un TS_VECTOR

-- Un **ts_query** comprend les lexèmes recherchés qui peuvent être combinés
-- avec les opérateurs - & (AND), | (OR), ! (NOT)



-- 3) OPERATEUR @@

-- permet d'interroger un tsvector

-- FONCTION TO_TSQUERY
-- Transforme une chaîne de texte en tsquery composée de lexèmes

-- ici on recherche si 'chat' est bien contenu dans la représentation vectorielle de 'chat chien'
select to_tsvector('chat chien') @@ to_tsquery('chat'); -- true

select to_tsvector('chat chien') @@ to_tsquery('chat & chien'); -- true

select to_tsvector('french', 'cheval poney') @@ to_tsquery('chevaux'); -- false -- ?????



-- Pourquoi chevaux ne fonctionne pas alors que si on recheche le lexème de chevaux, on trouve bien cheval??
select to_tsquery('french', 'chevaux'); -- Attention à ne pas oublier le dictionnaire!!!

-- Dans les 2 premières requêtes, on compare un mot à un lexème, ça ne marche pas comme ça :(
-- on doit réfléchir en terme de lexème, on va utiliser la fonction to_tsquery pour nous aider

-- avec le dictionaire, on a bien 'true'
select to_tsvector('french', 'cheval poney') @@ to_tsquery('french', 'chevaux');

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





-- II - Un peu de pratique...


-- Une requête qui retourne album, artiste, titre, compositeur
select art."Name" as artiste,
       alb."Title" as album,
       tr."Name" as chanson
from public."Album" alb
         join public."Artist" art on art."ArtistId" = alb."ArtistId"
         join public."Track" tr on tr."AlbumId" = alb."AlbumId";


-- Recherche dans une seule colonne
-- Ici, la colonne est "vectorisée" à la volée
select art."Name" as artiste,
       alb."Title" as album,
       tr."Name" as chanson,
       to_tsvector(tr."Name") as tsvector_chanson
from public."Album" alb
         join public."Artist" art on art."ArtistId" = alb."ArtistId"
         join public."Track" tr on tr."AlbumId" = alb."AlbumId"
-- On recherche le mot 'Dead' dans le titre des chansons
where to_tsvector(tr."Name") @@ to_tsquery('Dead');

select to_tsquery('Dead');



-- Recherche dans sur plusieurs colonnes
select art."Name" as artiste,
       alb."Title" as album,
       tr."Name" as chanson,
       to_tsvector(alb."Title" || ' ' || tr."Name") as tsvector_album_et_chanson
from public."Album" alb
         join public."Artist" art on art."ArtistId" = alb."ArtistId"
         join public."Track" tr on tr."AlbumId" = alb."AlbumId"
-- On recherche le mot 'Dead' dans le titre des chansons ET dans le nom des albums
where to_tsvector(alb."Title" || ' ' || tr."Name") @@ to_tsquery('Dead');


-- Ce type de requête n'est évidemment pas optimale en terme de performance


-- On va créer une table spécifique pour stocker les champs 'vectorisés'
truncate table Docs;
select * from Docs;

create table Docs (
    "TrackId" INT NOT NULL, -- le champ TrackId va nous servir de clé étrangère
    "document" tsvector -- le champ document est de type tsvector
);

/**insert into Docs("TrackId", "document")
    select tr."TrackId", to_tsvector(alb."Title" || ' ' || tr."Name")
    from public."Album" alb
             join public."Artist" art on art."ArtistId" = alb."ArtistId"
             join public."Track" tr on tr."AlbumId" = alb."AlbumId";
*/

select "TrackId", "document" from Docs;

-- On peut faire la même requête mais sur le champ document cette fois
select alb."Title" as album,
       art."Name" as artiste,
       tr."Name" as titre,
       doc.document as tsvector_album_et_chanson
from public."Album" alb
         join public."Artist" art on art."ArtistId" = alb."ArtistId"
         join public."Track" tr on tr."AlbumId" = alb."AlbumId"
         join public."docs" doc on doc."TrackId" = tr."TrackId"
where doc.document @@ to_tsquery('Dead');



-- ******* Performances *******

-- Comparaison des performances entre une recherche fts 'à la volée'
-- et une recherche avec une colonne contenant le ts_vector précalculé

-- Old way
explain analyse select al."Title" as album, art."Name" as artiste, tr."Name" as titre
                from public."Album" al
                         join public."Artist" art on art."ArtistId" = al."ArtistId"
                         join public."Track" tr on tr."AlbumId" = al."AlbumId"
                where to_tsvector(al."Title" || ' ' || tr."Name") @@ to_tsquery('Dead');

-- Avec colonne dédiée
explain analyse select al."Title" as album, art."Name" as artiste, tr."Name" as titre
                from public."Album" al
                         join public."Artist" art on art."ArtistId" = al."ArtistId"
                         join public."Track" tr on tr."AlbumId" = al."AlbumId"
                         join public.docs doc on doc."TrackId" = tr."TrackId"
                where doc.document @@ to_tsquery('Dead');


-- ******* Indexation *******

-- Indexer un tsvector : GIN & GiST
select amname from pg_am;

-- Indexer une colonne tsvector
-- * Oblige à maintenir une colonne supplémentaire
-- * Permet de concatener des champs et d'attribuer despoids

-- Index GIN (Generalized Inverted Index)
-- Index inversé : Contient chaque élément d'un tsvector

alter table docs add column document_with_idx tsvector;

/**with subquery as (
    select tr."TrackId" as trackId, to_tsvector(alb."Title" || ' ' || tr."Name") as vect
    from public."Album" alb
             join public."Artist" art on art."ArtistId" = alb."ArtistId"
             join public."Track" tr on tr."AlbumId" = alb."AlbumId"
             join public.docs fts on fts."TrackId" = tr."TrackId"
)
update docs
set document_with_idx = subquery.vect
from subquery
where docs."TrackId" = subquery.trackId;*/

select document_with_idx from Docs;

create index document_idx on docs using GIN (document);
select * from pg_indexes where tablename = 'docs';


-- ******* Ranking *******

select art."Name" as artiste,
       al."Title" as album,
       tr."Name" as chanson,
       ts_rank(doc.document_with_idx, to_tsquery('Dead')) -- ranking
from public."Album" al
         join public."Artist" art on art."ArtistId" = al."ArtistId"
         join public."Track" tr on tr."AlbumId" = al."AlbumId"
         join public.docs doc on doc."TrackId" = tr."TrackId"
where doc.document_with_idx @@ to_tsquery('Dead')
order by ts_rank(doc.document_with_idx, to_tsquery('Dead')) desc;


alter table docs add column document_with_weights tsvector;

/**with subquery as (
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
where docs."TrackId" = subquery.trackId;*/

select document_with_weights from docs;

-- Recherche avec setWeight A sur le titre de l'album
-- Les résultats matchant dans le titre de l'album sont privilégiés au détriment
-- des résultats matchant dans le titre des chansons
select art."Name" as artiste,
       al."Title" as album,
       tr."Name" as chanson,
       ts_rank(doc.document_with_weights, to_tsquery('Dead'))
from public."Album" al
         join public."Artist" art on art."ArtistId" = al."ArtistId"
         join public."Track" tr on tr."AlbumId" = al."AlbumId"
         join public.docs doc on doc."TrackId" = tr."TrackId"
where doc.document_with_weights @@ to_tsquery('Dead')
order by ts_rank(doc.document_with_weights, to_tsquery('Dead')) desc;



-- ERROR???? WTF!!!!
select al."Title" as album, art."Name" as artiste, tr."Name" as titre,
       ts_rank(fts.document, to_tsquery('Dead Horse'))
from public."Album" al
         join public."Artist" art on art."ArtistId" = al."ArtistId"
         join public."Track" tr on tr."AlbumId" = al."AlbumId"
         join public.docs fts on fts."TrackId" = tr."TrackId"
where fts.document @@ to_tsquery('Dead Horse')
order by ts_rank(fts.document, to_tsquery('Dead Horse')) desc;


-- ;)
select art."Name" as artiste, al."Title" as album,  tr."Name" as titre,
       ts_rank(fts.document, plainto_tsquery('Dead Horse'))
from public."Album" al
         join public."Artist" art on art."ArtistId" = al."ArtistId"
         join public."Track" tr on tr."AlbumId" = al."AlbumId"
         join public.docs fts on fts."TrackId" = tr."TrackId"
where fts.document @@ plainto_tsquery('Dead Horse')
order by ts_rank(fts.document, plainto_tsquery('Dead Horse')) desc;



select al."Title" as album, art."Name" as artiste, tr."Name" as titre,
       ts_rank(fts.document, to_tsquery('Dead | Horse'))
from public."Album" al
         join public."Artist" art on art."ArtistId" = al."ArtistId"
         join public."Track" tr on tr."AlbumId" = al."AlbumId"
         join public.docs fts on fts."TrackId" = tr."TrackId"
where fts.document @@ to_tsquery('Dead | Horse')
order by ts_rank(fts.document, to_tsquery('Dead | Horse')) desc;


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


-- THE END!!!!
