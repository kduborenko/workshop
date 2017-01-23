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
 __NOTE__:  Docker swarm mode implements [Raft Consensus Algorithm](https://docs.docker.com/engine/swarm/raft/) and does not require using external key value store anymore, such as Consul or etcd. 
 
 * deploy services
 
 Create an overlay "workshop" network, all containers that constitute workshop services will be assigned to that network.
 Contianer assigned to the overlay network can communicate with each other no matter on which nodes they are deployed.
 
 ```sh
 docker network create --driver overlay --subnet 10.0.0.0/24 workshop 
```


 ```sh
  docker service create  --replicas 1 --name spring-cloud-workshop-redis  --network workshop  redis

  docker service create --endpoint-mode dnsrr --replicas 1 --name spring-cloud-workshop-config-server --network workshop \
url-shortener/spring-cloud-workshop-config-server --spring.cloud.config.server.git.uri=$repo
  
  docker service create --endpoint-mode dnsrr --replicas 1 --name spring-cloud-workshop-dicovery-service --network workshop \
url-shortener/spring-cloud-workshop-service-discovery 
  
  docker service create --endpoint-mode dnsrr --replicas 1 --name spring-cloud-workshop-url-shortener-backend --network workshop url-shortener/spring-cloud-workshop-url-shortener-backend --spring.cloud.config.uri=http://spring-cloud-workshop-config-server:8888 

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
  
 
# Docker Compose

* Compose is a tool for defining and running multi-container Docker applications. With Compose, you use a Compose file to    configure your application's services. Then, using a single command, you create and start all the services from your configuration. 
 The Compose file is a YAML file defining services, networks and volumes. The default path for a Compose file is ./docker-compose.yml.

# Logging

Options:

*  ```docker logs container-name```
    good for local debugging, definitely beats ```docker exec container-name cat /path/to/logfile```
 
* ```docker-compose logs``` , streams log output of running services, of all containers defined in ‘docker-compose.yml‘   

*  logging drivers, sends stdout and stderr output from your container to the centralized logging host, currently supports: splunk, awslogs (cloud watch), journald, syslog, gelf (gray log), gcplogs (google cloud), json-file...

   docker provides __tag__ option to set custom logging format, i.e:
   --log-opt tag="{{.ImageName}}/{{.Name}}/{{.ID}}" value yields syslog log lines like:
```
   Aug  7 18:33:19 HOSTNAME docker/hello-world/foobar/5790672ab6a0[9103]: Hello from Docker.
```  

* ELK Stack (elasticsearch, Logstash, and Kibana).
  good for log aggregation, visualization, analysis, and monitoring
  
- Elasticsearch is a highly scalable open-source full-text search and analytics engine.
- Logstash is in charge of log aggregation from each of the sources and forwarding them to the Elasticsearch instance.
- Kibana is an open source analytics and visualization platform designed to work with Elasticsearch. 
- syslog driver to ship logs to logstash

```
docker-machine ssh manager01 'sudo sysctl -w vm.max_map_count=262144'
docker-machine ssh manager02 'sudo sysctl -w vm.max_map_count=262144'
docker-machine ssh manager03 'sudo sysctl -w vm.max_map_count=262144'

docker service create --network workshop  -p 5000:5000 -p 5000:5000/udp --name logstash avolokitin/logstash

docker service create --network workshop --endpoint-mode dnsrr --name elasticsearch -e "ES_JAVA_OPTS=-Xms512m -Xmx512m" elasticsearch

docker service create --network workshop --name kibana --publish 5601:5601 -e ELASTICSEARCH_URL=http://elasticsearch:9200 kibana

docker run --log-driver syslog --log-opt syslog-address=udp://localhost:5000 --rm busybox echo hello
```

open kibana at $(docker-machine ip manager01):5601


ports:
- 5601 (Kibana web interface).
- 9200 (Elasticsearch JSON interface).
- 5000 (Logstash Beats interface, receives logs from Beats such as Filebeat).


update existing services with logging options and drivers:

```
 docker service update spring-cloud-workshop-url-shortener-frontend --log-driver=syslog --log-opt syslog address=udp://localhost:5000 --log-opt syslog-facility=daemon --log-opt tag="frontend" --log-opt tag="{{.Name}}"

 docker service update pring-cloud-workshop-url-shortener-backend --log-driver=syslog --log-opt syslog-address=udp://localhost:5000 --log-opt syslog-facility=daemon --log-opt tag="backend" --log-opt tag="{{.Name}}"

 docker service update  spring-cloud-workshop-redis --log-driver=syslog --log-opt syslog-address=udp://localhost:5000 --log-opt syslog-facility=daemon --log-opt tag="redis" --log-opt tag="{{.Name}}"

 docker service update spring-cloud-workshop-config-server  --log-driver=syslog --log-opt syslog-address=udp://localhost:5000 --log-opt syslog-facility=daemon --log-opt tag="config-server" --log-opt tag="{{.Name}}"

 docker service update spring-cloud-workshop-dicovery-service  --log-driver=syslog --log-opt syslog-address=udp://localhost:5000 --log-opt syslog-facility=daemon --log-opt tag="dicovery-service" --log-opt tag="{{.Name}}"


```

# docker images cheat sheet.

   Dockerfile format:
   
```sh
INSTRUCTION arguments
```

* __FROM__: base image from which you are going to build.

```sh
FROM base_image_name 
```

* __ADD__: copies/adds new files, directories or remote file and adds them to the fs of the container.

```sh
ADD awesome_java.jar yet_another_awesome.jar
```

* __EXPOSE__: specifies ports container listens on, doesn't publish/make ports availible to the host.

```sh
EXPOSE 8080
```

* __ENV__: sets/updates environment variables.

```sh
ENV PATH /usr/local/bin:$PATH
```

* __RUN__: executes command/commands in a new layer on top of the current image and commit the results.
  shell form, the command is run in a shell (/bin/sh -c by default):

```sh
RUN echo 'hell awaits!' 
```
* exec form, doesn't invoke shell, meaning no shell vars like $HOME/$PATH.
  parsed as JSON array, which means DOUBLE QUOTES.

```sh
RUN ["/bin/echo", "hell awaits"]
```
* __CMD__: runs/executes binraies/software you ship, inside container, also supports shell & exec format.

```sh
CMD ["awesome_binary", "awesome_argument1", "awesome_argument2"]
```

* __ENTRYPOINT__:
   configures a container that will run as an executable/binray, meaning that docker run "image" --help
   will pass --help to the binary set in ENTRYPOINT
   can be used with CMD to specify default argumnets
  
```sh
ENTRYPOINT ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"]
```

* [docker high level overview] 
(https://docs.google.com/presentation/d/15lwGE6KrJl_TXGNAmSXOZxmVHPGa4XbalL0haFnQxfo/edit#slide=id.p)


 
 ```sh
 docker-compose bundle => converts compose.yml into dub
 docker stack deploy 
 ```

