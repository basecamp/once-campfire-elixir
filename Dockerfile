# Build the pinned native toolchain with Dockerfile.dev first.
FROM campfire-reference:app AS frontend
FROM campfire-elixir:toolchain AS build
ENV MIX_ENV=prod EXQLITE_USE_SYSTEM=1
COPY mix.exs mix.lock ./
COPY deps ./deps
COPY lib ./lib
COPY native ./native
COPY priv ./priv
COPY vectors/message-etags.json vectors/mime-types.json vectors/route-actions.json vectors/image-etags.json vectors/sounds.json vectors/fragment-digests.json ./vectors/
RUN mix deps.compile && mix compile --warnings-as-errors && mix release

FROM campfire-elixir:toolchain
WORKDIR /campfire
COPY --from=build /app/_build/prod/rel/campfire ./
COPY --from=frontend /usr/local/bundle/ruby/3.4.0/gems/thruster-0.1.23-x86_64-linux/exe/x86_64-linux/thrust /usr/local/bin/thrust
COPY --from=frontend /usr/local/bundle/ruby/3.4.0/gems/thruster-0.1.23-x86_64-linux/MIT-LICENSE /campfire/THRUSTER-LICENSE
COPY --from=frontend /rails/public/502.html /campfire/public/502.html
COPY --chmod=755 hooks /hooks
COPY --chmod=755 bin/container-start /campfire/bin/container-start
RUN mkdir -p /rails/storage/db /rails/storage/files /rails/storage/backups /rails/storage/thruster && chown -R 1000:1000 /rails/storage
USER 1000:1000
ARG APP_VERSION=dev
ARG GIT_REVISION=dev
ENV APP_VERSION=$APP_VERSION GIT_REVISION=$GIT_REVISION RAILS_ENV=production
ENV DATABASE_PATH=/rails/storage/db/production.sqlite3 STORAGE_PATH=/rails/storage/files
ENV HTTP_IDLE_TIMEOUT=60 HTTP_READ_TIMEOUT=300 HTTP_WRITE_TIMEOUT=300
EXPOSE 80 443
CMD ["/campfire/bin/container-start"]
