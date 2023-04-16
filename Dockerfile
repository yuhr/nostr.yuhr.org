FROM docker.io/library/rust:1-bookworm as builder
RUN apt-get update
RUN apt-get install -y cmake protobuf-compiler
RUN rm -rf /var/lib/apt/lists/*
RUN cargo new --bin nostr-rs-relay
WORKDIR ./nostr-rs-relay
COPY ./Cargo.toml ./Cargo.toml
COPY ./Cargo.lock ./Cargo.lock
# build dependencies only (caching)
RUN cargo build --release --locked
# get rid of starter project code
RUN rm src/*.rs

# copy project source code
COPY ./src ./src
COPY ./proto ./proto
COPY ./build.rs ./build.rs

# build release using locked deps
RUN rm ./target/release/deps/nostr*relay*
RUN cargo build --release --locked

FROM docker.io/library/debian:bookworm-slim

ARG APP=/app
ARG APP_DATA=/app/db
RUN apt-get update
RUN apt-get install -y ca-certificates tzdata sqlite3 libc6
RUN rm -rf /var/lib/apt/lists/*

EXPOSE 8080

ENV TZ=Etc/UTC
ENV APP_USER=appuser

RUN groupadd $APP_USER
RUN useradd -g $APP_USER $APP_USER
RUN mkdir -p ${APP}
RUN mkdir -p ${APP_DATA}

COPY --from=builder /nostr-rs-relay/target/release/nostr-rs-relay ${APP}/nostr-rs-relay

RUN chown -R $APP_USER:$APP_USER ${APP}
RUN chown -R $APP_USER:$APP_USER ${APP_DATA}

USER $APP_USER
WORKDIR ${APP}

ENV RUST_LOG=info,nostr_rs_relay=info
ENV APP_DATA=${APP_DATA}

CMD ./nostr-rs-relay --db ${APP_DATA}
