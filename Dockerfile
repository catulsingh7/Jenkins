FROM tomcat:10.1-jdk21

RUN apt update && apt install -y net-tools

COPY vprofile-v2.war webapps/vprofile-v2.war

CMD ["catalina.sh", "run"]
