# stop all processes
docker stop $(docker ps -aq)

# remove all containers
docker rm $(docker ps -aq)

# remove all images
docker rmi $(docker images -aq)

# remove all stopped containers, all dangling images, all unused networks and all unused volumes
docker system prune --volumes