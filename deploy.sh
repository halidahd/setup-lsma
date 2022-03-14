user="lsma"
path=/home/$user
tag=$(cat tag.txt)
source=$(cat source.txt)
releaseDir=$path/project
export TAG=$tag
cd $path

echo "===== PULL REPOSITORIES ====="

docker pull registry.gitlab.com/sampletext/yayoi_ma/admin:$tag
docker pull registry.gitlab.com/sampletext/yayoi_ma/nuxt:$tag

echo "===== CLONE REPOSITORIES ==="
git clone -b $tag --single-branch $source $releaseDir
cd $releaseDir
git reset --hard HEAD

echo "===== COPY SETUP ====="
cd $path
pwd
echo $releaseDir
cp $path/.env.docker $releaseDir/.env
cp $path/.env.api $releaseDir/nuxt/.env

echo "===== DOWN APPLICATIONS ====="
[ -n "$(docker ps -aq --filter 'status=running')" ] && docker stop $(docker ps -aq)
[ -n "$(docker ps -aq --filter 'status=exited')" ] && docker rm $(docker ps -aq)

echo "===== START APPLICATIONS ====="
cd $releaseDir
docker-compose -f docker-compose.prod.yml up -d nginx admin redis nuxt

echo "===== MIGRATION ====="
cd $releaseDir
docker-compose exec -T --user www-data:www-data admin php artisan migrate --force

echo "===== SYNC KEY ====="
docker-compose exec -T --user www-data:www-data admin php artisan sync:token

echo "===== CLEAN ====="
docker system prune -f --volumes
docker image prune -a -f

echo "=================== DONE ================="
