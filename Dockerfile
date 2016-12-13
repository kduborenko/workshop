FROM ubuntu:14.04

RUN apt-get update && apt-get -y -q upgrade
RUN apt-get -y -q install software-properties-common python-software-properties \
        && add-apt-repository ppa:adiscon/v8-stable \
        && apt-get update && apt-get -y -q install rsyslog
        
RUN sed 's/#$ModLoad imudp/$ModLoad imudp/' -i /etc/rsyslog.conf
RUN sed 's/#$UDPServerRun 514/$UDPServerRun 514/' -i /etc/rsyslog.conf
RUN sed 's/#$ModLoad imtcp/$ModLoad imtcp/' -i /etc/rsyslog.conf
RUN sed 's/#$InputTCPServerRun 514/$InputTCPServerRun 514/' -i /etc/rsyslog.conf
RUN sed 's/$ModLoad imklog/#$ModLoad imklog/' -i /etc/rsyslog.conf
RUN sed 's/$FileOwner syslog/$FileOwner root/' -i /etc/rsyslog.conf
RUN sed 's/$PrivDropToUser syslog/#$PrivDropToUser syslog/' -i /etc/rsyslog.conf
RUN sed 's/$PrivDropToGroup syslog/#$PrivDropToGroup syslog/' -i /etc/rsyslog.conf

EXPOSE 514/tcp 514/udp

ADD logs.conf /etc/rsyslog.d/

ENTRYPOINT ["/usr/sbin/rsyslogd", "-n"]
