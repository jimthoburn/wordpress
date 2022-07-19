FROM amazon/aws-cli:latest

RUN yum update -y \
    && yum install -y gzip

WORKDIR /scripts
COPY install-mysqldump.sh .
RUN "/scripts/install-mysqldump.sh"

COPY backup.sh .
ENTRYPOINT [ "/scripts/backup.sh" ]
