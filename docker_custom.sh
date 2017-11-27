#### Custom bash functions for docker ####
# function to execute a bash shell inside a running container. Parameter is the container ID.
docker-bash() {
  [ "$#" -lt 2 ] && quit "2 arguments required (user followed by container name/id), $# provided" || docker exec -it -u $1 $2 "/bin/bash"
}

docker-bash-win() {
  [ "$#" -lt 2 ] && quit "2 arguments required (user followed by container name/id), $# provided" || winpty docker exec -it -u $1 $2 "bash"
}


docker-ip() {
  [ "$#" -lt 1 ] && quit "1 argument required (container name/id), $# provided" || docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $1
}

docker-ps() {
  template="table {{.Names}}\t{{.ID}}\t{{.Status}}\t{{.Ports}}"
  if [[ $1 =~ ^(cat"--detail"|"-d")$ ]]; then
    template="$template \t{{.Image}}\t{{.Command}}\t{{.Size}}"
  fi
    cmd="docker ps --format '$template'"

  if [[ $1 =~ ^(cat"--all"|"-a")$ ]]; then
    cmd="$cmd $1"
  fi

  eval $cmd
}

docker-ps-usage() {
  echo "Usage: docker-ps [OPTIONS]"
  echo "Options:"
  echo -e "\t --all | -a \t\t List all containers"
  echo -e "\t --detail | -d \t\t Show all details"
  echo -e "\t --usage | -u \t\t Show this usage menu"
}
