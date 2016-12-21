FROM logstash:latest
COPY logstash.conf /opt/logstash/server/etc/conf.d/workshop-syslog

EXPOSE 5000/tcp 5000/udp

ENTRYPOINT ["logstash",  "-f"] 
CMD ["/opt/logstash/server/etc/conf.d/"]

