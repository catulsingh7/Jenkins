FROM 221082191413.dkr.ecr.us-east-1.amazonaws.com/custom-baseimage:v1

COPY target/vprofile-v2.war webapps/vprofile-v2.war

CMD ["catalina.sh", "run"]
