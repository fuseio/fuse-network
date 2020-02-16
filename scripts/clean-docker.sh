#!/bin/bash

set -e

# in case "sudo" is needed
PERMISSION_PREFIX=""

# stop all processes
$PERMISSION_PREFIX docker stop $($PERMISSION_PREFIX docker ps -aq)

# remove all containers
$PERMISSION_PREFIX docker rm $($PERMISSION_PREFIX docker ps -aq)

# remove all images
$PERMISSION_PREFIX docker rmi $($PERMISSION_PREFIX docker images -aq)

# remove all stopped containers, all dangling images, all unused networks and all unused volumes
$PERMISSION_PREFIX docker system prune --volumes