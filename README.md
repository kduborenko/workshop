# workshop

* environment setup:

1. create three virtual machines running docker:
 ```sh
  docker-machine create -d virtualbox --virtualbox-host-dns-resolver manager01
  docker-machine create -d virtualbox --virtualbox-host-dns-resolver manager02
  docker-machine create -d virtualbox --virtualbox-host-dns-resolver manager03
 ```

2. point local docker client to manager01 and nitialize swarm:
 ```sh
   eval $(docker-machine env node-1) 

   docker swarm init --advertise-addr $(docker-machine ip manager01) \
       --listen-addr $(docker-machine ip manager01):2377
 ```

3. generate token for managers and set env variable:
 ```sh
    TOKEN=$(docker swarm join-token manager -q)
 ```

4. point local docker client to manager02 and join swarm as a manager:
 ```sh
   eval $(docker-machine env manager02)

   docker swarm join --token $TOKEN \
     $(docker-machine ip manager01):2377
 ```

5. point local docker client to manager03 and join swarm as a manager:
 ```sh
   eval $(docker-machine env manager03)

   docker swarm join --token $TOKEN \
     $(docker-machine ip manager01):2377
 ```

6. list nodes in the swarm: 
 ```sh
 docker node ls
 ```
 ``` 
 ID                           HOSTNAME   STATUS  AVAILABILITY  MANAGER STATUS
 2no8xk6evzc577wbhobekh0xd    manager01  Ready   Active        Leader
 6uwv9gu71m7oefjrc6nxopxfr    manager02  Ready   Active        Reachable
 c8c6b0wemgshgyi72r8a4immr *  manager03  Ready   Active        Reachable
 ```
 
 * deploy services
 
 Create an overlay "workshop" network, all containers that constitute workshop services will be assigned to that network.
 Contianer assigned to the overlay network can communicate with each other no matter on which nodes they are deployed.
 
 ```sh
 docker network create --driver overlay workshop
```


 ```sh
 docker service create  --replicas 1 --name spring-cloud-workshop-redis   --network workshop  redis

 docker service create --endpoint-mode dnsrr --replicas 1 --name config-server  --network workshop  url-shortener/spring-cloud-workshop-config-server --spring.cloud.config.server.git.uri=$REPO

 docker service create --endpoint-mode dnsrr --replicas 1 --name dicovery-service  --network workshop  url-shortener/spring-cloud-workshop-service-discovery

 docker service create --endpoint-mode dnsrr --replicas 1 --name backend   --network workshop  url-shortener/spring-cloud-workshop-url-shortener-backend --spring.cloud.config.uri=http://config-server:8888/


  docker service create  --replicas 3 --name frontend --network workshop  -p 8080:8080 url-shortener/spring-cloud-workshop-url-shortener-frontend --spring.cloud.config.uri=http://config-server:8888


 docker service create  --replicas 1 --name spring-cloud-workshop-redis   --network workshop  redis
 ```

* scale any service:

  docker service service_name=desired num of containers
  
spring-cloud-workshop-redis scaled to 3

* things to discuss:

1. --mount for servces (required storage/volume)
2. Compose does not use swarm mode to deploy services to multiple nodes in a swarm. All containers will be scheduled on the current node. To deploy application across the swarm, use the bundle feature of the Docker experimental build. 
 but: https://docs.docker.com/compose/swarm/ 
3. Push images to hub, to avoid build on each host. 
4. frontend/backend both use 8080
5. hardcoded localhost in yml/jars

