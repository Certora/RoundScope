FROM eclipse-temurin:21-jre-alpine

COPY target/roundabout-0.0.1-SNAPSHOT.jar /app/roundabout.jar

WORKDIR /work

ENTRYPOINT ["java", "-jar", "/app/roundabout.jar"]
