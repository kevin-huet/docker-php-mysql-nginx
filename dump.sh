user=username
user_local=username
path_local=$HOME/www/your/path
fqdn=domainName;
port=22003;
database_name=name
database_local_name=name
container_php_local=name
container_mysql_local=name
container_mysql_server=name
file='dump_'$(date +"%Y%m%d")'.txt'

echo "=========================================="
echo "Import de la db prod en local        "
echo "=========================================="

output=${path_local}/var/dump/${file}
command='docker exec --user='${user}' '${container_mysql_server}' bash -c "mysqldump -u root -pPaswword '${database_name}'"'

ssh "${user}"@"${fqdn}" -p "${port}" "${command}">${output}

if [ -f ${output} ]; then
    echo "Dump de la prod ajouté dans ${output}";
else
    echo "Echec du dump de la prod dans ${output}";
fi

# Mise à jour cache doctrine et php
docker exec ${container_php_local} /bin/sh -c "php bin/console doctrine:cache:clear-query"

# Suppression et création de la database
echo "=========================================="
echo "Suppression et initialisation db en local "
echo "=========================================="

docker exec ${container_php_local} /bin/sh -c "php bin/console doctrine:database:drop --force"
docker exec ${container_php_local} /bin/sh -c "php bin/console doctrine:database:create"
docker exec ${container_php_local} /bin/sh -c "php bin/console doctrine:cache:clear-query"

echo "OK"

# Mise à jour schéma et données à partir du fichier dump
echo "=========================================="
echo "Chargement de la db en local              "
echo "=========================================="

path_dump="var/dump/${file}"
command_dump="mysql -u ${user_local} -pPassword ${database_local_name} < dump.sql;"
# avec namespaces
docker cp "${path_dump}" ${container_mysql_local}:/dump.sql
docker exec ${container_mysql_local} /bin/sh -c "${command_dump}"
docker exec ${container_php_local} /bin/sh -c "php bin/console doctrine:cache:clear-query" &> /dev/null

echo "OK"
