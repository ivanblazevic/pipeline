#!/bin/sh

# To install this script on the server following steps are required:
# wget https://raw.githubusercontent.com/ivanblazevic/pipeline/master/build.sh
# sudo cp build.sh /usr/local/bin/build
# sudo chmod +x /usr/local/bin/build
VERSION=1.0.1

if [ "$1" = "update" ]
then
    wget -P /tmp https://raw.githubusercontent.com/ivanblazevic/pipeline/master/build.sh
    sudo cp /tmp/build.sh /usr/local/bin/build
    rm /tmp/build.sh
    echo "Build script has been updated to version ${VERSION}"
    exit
fi

echo "Build has started..."

REPO=$1 #"/var/builder_react.git"
DOCKER_IMAGE=$2  #"builder_react:latest"
SERVICE_NAME=$3  #"builder_react"
SERVICE_NAME_DEV="${SERVICE_NAME}_dev"

echo "Repo: ${REPO}"
echo "Docker image: ${DOCKER_IMAGE}"
echo "Service name: ${SERVICE_NAME}"
echo "Service name (dev): ${SERVICE_NAME_DEV}"

git --work-tree=$REPO --git-dir=$REPO checkout -f

while read oldrev newrev ref
do
  branch=`echo $ref | cut -d/ -f3`

  docker build --build-arg branch=$branch -t $SERVICE_NAME .
  docker tag $SERVICE_NAME localhost:5000/$DOCKER_IMAGE
  docker push localhost:5000/$DOCKER_IMAGE

  if [ "release" = "$branch" ]; then
    docker service rm $SERVICE_NAME
    git --work-tree=./path/under/root/dir/live-site/ checkout -f $branch
    docker service update $SERVICE_NAME --image localhost:5000/$DOCKER_IMAGE
    echo 'Changes pushed live.'
  fi

  if [ "master" = "$branch" ]; then
    echo "Removing ${SERVICE_NAME_DEV} service"
    docker service rm $SERVICE_NAME_DEV
    #git --work-tree=./path/under/root/dir/dev-site/ checkout -f $branch
    echo "Starting new ${SERVICE_NAME_DEV} service"
    docker service update $SERVICE_NAME_DEV --image localhost:5000/$DOCKER_IMAGE
    echo "Changes pushed to dev."
  fi
done

## Cleanup old containers
docker rm $(docker ps -q -f 'status=exited')
docker rmi $(docker images -q -f "dangling=true")
