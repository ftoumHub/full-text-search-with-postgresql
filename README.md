Build du conteneur
```bash
docker-compose up --build
```

Démarrer le conteneur et exécuter des commandes
```bash
docker-compose up --remove-orphans -d

docker exec -it fts_with_pg bash

-- run sql scripts
psql -U postgres fts_with_pg -a -f /data/datas.sql
```
Connection à la BD Postgresql
```bash
-- enter a psql session as the user 'postgres'
psql -U postgres

-- Listing out our databases
\l

-- Connect to our pg_fts database
\connect pg_fts
```

Quitter psql:
```bash
\q
```

Sortir du conteneur:
```bash
exit
```

```bash
docker-compose stop

docker-compose rm -f
```