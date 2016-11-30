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
   eval $(docker-machine env manager01) 

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

6. Push docker images to each node
  ```sh
  for node in manager01 manager02 manager03
  do
    eval $(docker-machine env $node)
    mvn install
    for image in url-shortener/spring-cloud-workshop-config-server \
                 url-shortener/spring-cloud-workshop-service-discovery \
                 url-shortener/spring-cloud-workshop-url-shortener-backend \
                 url-shortener/spring-cloud-workshop-url-shortener-frontend
    do
      docker create -e affinity:image=$image $image
    done
                
  done
  ```

7. list nodes in the swarm: 
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
 docker network create --driver overlay --subnet 10.0.0.0/24 workshop 
```


 ```sh
  docker service create  --replicas 1 --name spring-cloud-workshop-redis  --network workshop  redis

  docker service create --endpoint-mode dnsrr --replicas 1 --name spring-cloud-workshop-config-server --network workshop \
  url-shortener/spring-cloud-workshop-config-server --spring.cloud.config.server.git.uri=$REPO

  docker service create --endpoint-mode dnsrr --replicas 1 --name spring-cloud-workshop-dicovery-service --network workshop \
  url-shortener/spring-cloud-workshop-service-discovery

  docker service create --endpoint-mode dnsrr --replicas 1 --name spring-cloud-workshop-url-shortener-backend --network workshop \
  url-shortener/spring-cloud-workshop-url-shortener-backend --spring.cloud.config.uri=http://spring-cloud-workshop-config-server:8888/


  docker service create  --replicas 3 --name spring-cloud-workshop-url-shortener-frontend --network workshop  -p 8080:8080 \
  url-shortener/spring-cloud-workshop-url-shortener-frontend --spring.cloud.config.uri=http://spring-cloud-workshop-config-server:8888

 ```

* scale a service:

  docker service scale service_name=desired num of containers / docker service update --replicas num of containers serviec_name
  docker service ps service_name
  
 ```sh
 docker service scale spring-cloud-workshop-redis=3
 spring-cloud-workshop-redis scaled to 3
 ```
 
* rolling updates:

 ```sh
   docker service update --image updated/image:0.2 --update-parallelism 2 --update-delay 60s service_name
 ```
 
  * --update-parallelism num - number of service tasks that the scheduler updates simultaneously 
  * --update-delay s/m/h/ - time delay between updates to a service task or sets of tasks

* [endpoints/loadbalancing slides](https://docs.google.com/presentation/d/1DFnw6DQq83Chd8ybxu1uQK3r4iUwgElL2uCAyPkukqw/edit#slide=id.p)

* [docker process isolation/overview of kernel namespaces slides] 
(https://docs.google.com/presentation/d/15lwGE6KrJl_TXGNAmSXOZxmVHPGa4XbalL0haFnQxfo/edit#slide=id.p)

* [unionfs/images slides]
(https://docs.google.com/presentation/d/1QoU8XDvPiT7P7Nd7qJFCcfPq_3GbrutJFAVqlBPdmtE/edit#slide=id.p)



