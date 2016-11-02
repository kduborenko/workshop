# workshop


environment setup:

1. create three virtual machines running docker:

 docker-machine create -d virtualbox --virtualbox-host-dns-resolver manager01
 docker-machine create -d virtualbox --virtualbox-host-dns-resolver manager02
 docker-machine create -d virtualbox --virtualbox-host-dns-resolver manager03


2. point local docker client to manager01:

  eval $(docker-machine env node-1) 
  
3. initialize swarm on manager01:

   docker swarm init --advertise-addr $(docker-machine ip manager01) \
      --listen-addr $(docker-machine ip manager01):2377
4. generate token for managers and set env variable:
  
   TOKEN=$(docker swarm join-token manager -q)
5. point local docker client to manager02.

   eval $(docker-machine env manager02)
6. add manager02 to swarm as a manager

  docker swarm join --token $TOKEN \
    $(docker-machine ip manager01):2377

7. repeate 5 & 6 for manager03

