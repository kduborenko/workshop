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
  url-shortener/spring-cloud-workshop-url-shortener-frontend --spring.cloud.config.uri=http://spring-cloud-workshop-config-server:8888 --log-driver=syslog --log-opt syslog-address=tcp://rsyslog:514 --log-opt tag="frontend"
  
  docker service create  --replicas 1 --name rsyslog --network workshop  -p 514:514/udp -p 514:514 avolokitin/rsyslog 

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

# Logging

*  ```docker logs container-name```
  good for local debugging, definitely beats ```docker exec container-name cat /path/to/logfile```
 
* ```docker-compose logs``` , streams log output of running services, of all containers defined in ‘docker-compose.yml‘   

*  logging drivers: splunk, awslogs (cloud watch), journald, syslog, gelf (gray log), gcplogs (google cloud), json-file...

   Also use  docker logging tags to specify custom logging format:
   i.e --log-driver=syslog --log-opt syslog-tag=my_service_name
   For example, specifying a --log-opt tag="{{.ImageName}}/{{.Name}}/{{.ID}}" value yields syslog log lines like:
```
   Aug  7 18:33:19 HOSTNAME docker/hello-world/foobar/5790672ab6a0[9103]: Hello from Docker.
```  


* ELK Stack (elasticsearch, Logstash, and Kibana).
  good for log aggregation, visualization, analysis, and monitoring
  no need to mess with individuall service installations, since there are ready-made and bullet-proof images on Docker Hub
  the one we gonna use [__willdurand/elk__] (https://hub.docker.com/r/willdurand/elk/) 
  plus [__Filebeat__] (https://www.elastic.co/products/beats/filebeat) to collect logs (e.g. from log files, from the syslog daemon)  and send them to our instance of Logstash.

- Elasticsearch is a highly scalable open-source full-text search and analytics engine.
- Logstash is in charge of log aggregation from each of the sources and forwarding them to the Elasticsearch instance.
- Kibana is an open source analytics and visualization platform designed to work with Elasticsearch. 
- Filebeat is a log data shipper.




```sh
 docker run -p 5601:5601 -p 9200:9200 -p 5044:5044  -p 9300:9300 -it --name elk sebp/elk
```

ports:
- 5601 (Kibana web interface).
- 9200 (Elasticsearch JSON interface).
- 9300 (Elasticsearch publish interface)
- 5044 (Logstash Beats interface, receives logs from Beats such as Filebeat).



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

* [endpoints/loadbalancing slides](https://docs.google.com/presentation/d/1DFnw6DQq83Chd8ybxu1uQK3r4iUwgElL2uCAyPkukqw/edit#slide=id.p)

* [docker process isolation/overview of kernel namespaces slides] 
(https://docs.google.com/presentation/d/15lwGE6KrJl_TXGNAmSXOZxmVHPGa4XbalL0haFnQxfo/edit#slide=id.p)

* [unionfs/images slides]
(https://docs.google.com/presentation/d/1QoU8XDvPiT7P7Nd7qJFCcfPq_3GbrutJFAVqlBPdmtE/edit#slide=id.p)


1. slides
2. logging elk/g4j
3. images
