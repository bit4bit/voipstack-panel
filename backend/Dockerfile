FROM openjdk:8-alpine

COPY target/uberjar/backend.jar /backend/app.jar

EXPOSE 3000

CMD ["java", "-jar", "/backend/app.jar"]
