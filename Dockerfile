# Use latest stable channel SDK.
FROM dart:stable AS build

# Resolve app dependencies.
WORKDIR /app
COPY chameleon_server/pubspec.* ./chameleon_server/
COPY shared/ ./shared/

WORKDIR /app/chameleon_server
RUN dart pub get

# Copy app source code and AOT compile it.
COPY chameleon_server/ .
# Compile the bin/server.dart file
RUN dart compile exe bin/server.dart -o bin/server

# Build minimal serving image from AOT-compiled `/server`
# and the pre-compiled AOT runtime.
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/chameleon_server/bin/server /app/bin/

# Start server.
EXPOSE 8080
CMD ["/app/bin/server"]
