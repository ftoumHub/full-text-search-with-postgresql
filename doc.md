Conf pg_day Adrien Nayrat : https://www.youtube.com/watch?v=9S5dBqMbw8A

#  Full Text Search
## Fonctionnement dans POSTGRESQL

# Au Menu

Comment rechercher de l'information dans un document?
* La Recherche d'Information
* Full Text Search dans Postgres

# 1. Comment faire une recherche?

Notre cerveau sait:
* Identifier les synonymes
* Ignorer les mots non importants "le, la,..."
* Sans forcément prêter attention à la casse, ponctuation
    * But retenir les mots porteurs de sens
    * Traiter de manière automatisée un langage naturel

## Définition

_La recherche d'information (RI) est le domaine qui étudie
la manière de retrouver des informations dans un corpus..._

_[...]représenter des documents dans le but d'en récupérer
des informations, au moyen de la construction d'index. - Wikipedia_

## RI (Composants)

Pré-traitement :
* Extraire les descripteurs :
    * Suppression des mots outils ou mots vides
    * Lemmatisation _stemming_ : Obtenir la racine des mots
    * Remplacer des synonymes
    * Utiliser un thésaurus

## 2. Dans POSTGRESQL?

On parle de Recherche Plein Text (**Full Text Search**)
Plusieurs composants formant une chaîne :
* Parser (identification des tokens)
* Un ou des dictionnaires (filtre les tokens pour obtenir un lexème)

But : obtenir une liste triée de lexèmes formant un _tsvector_.

## LEXEME?

_Définition : Morphème lexical d'un lemme, c'est-à-dire une unité de
sens et de son qui n'est pas fonctionnelle ou dérivationnelle._

Les mots utiles et seulement leur racine.

Exemple : un verbe sans terminaison :
* Empêcher => empech

## Type TSVECTOR

Un **tsvector** est une liste triée de **lexèmes**.  
Ex, on passe un document (ici une phrase) à la fonction **to_tsvector**. Celle-ci va retourner le tsvector correspondant au document.


```sql
select to_tsvector('french', 'Le meilleur SGBD Opensource'); 

to_tsvector
-----------------------------------
'meilleur':2 'opensourc':4 'sgbd':3
```

On obtient la représentation vectorielle de la phrase.
Les lexèmes de la phrase sont extraits et triés. Le chiffre à la droite des ":"
correspond à l'emplacement du lexème dans la phrase.

## PARSER

But : identifier des _tokens_

Exemple :
* word : Mot comportant des lettres
* int : Entier signé
* url : Lien
* email : adresse mail
* tag : balise xml
* blank : espace

## Exemple

Maif France contact@maif.fr http://maif.fr/about.html  
Word email url

## Dictionnaires

Succession de filtres permettant d'obtenir un lexème  
(lemmatisation)
* Supprimer la casse
* Retirer les _stopswords_ (mots vides)
* Remplacer les synonymes
  ...

## Une configuration FTS c'est:

* Un parser
* Plusieurs dictionnaires
* Mapping : applique les dictionnaires en fonction des catégories de token.