
# Stage 1: Build the application
FROM eclipse-temurin:27-jdk-ubi10-minimal AS build

WORKDIR /app

# Copy Maven wrapper and project files
COPY . .

# Build the Spring Boot application
RUN chmod +x mvnw && ./mvnw -B clean package

# Stage 2: Run the application
FROM eclipse-temurin:27-jre-ubi10-minimal

WORKDIR /app

# The Compose health check uses curl to query Spring Boot Actuator.
RUN microdnf install -y curl-minimal && microdnf clean all

# Copy the generated JAR
COPY --from=build /app/target/paylink-0.0.1-SNAPSHOT.jar app.jar

# Application port
EXPOSE 8080

# Start Spring Boot
ENTRYPOINT ["java", "-jar", "app.jar"]
