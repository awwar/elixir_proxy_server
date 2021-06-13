FROM elixir:1.12.0

RUN mix local.hex --force \
    && mix local.rebar --force 

COPY ./entrypoint.sh /usr/bin/entrypoint.sh

RUN chmod 777 /usr/bin/entrypoint.sh

WORKDIR /app

ENTRYPOINT "/usr/bin/entrypoint.sh"