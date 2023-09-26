ARG NODE_VERSION=18

# 1. Create an image to build n8n
FROM n8nio/base:${NODE_VERSION} as builder

COPY --chown=node:node turbo.json package.json .npmrc pnpm-lock.yaml pnpm-workspace.yaml jest.config.js tsconfig*.json ./
COPY --chown=node:node scripts ./scripts
COPY --chown=node:node packages ./packages
COPY --chown=node:node patches ./patches

ARG PGPASSWORD='k1n8iqaNOAMLr7WTxeCq'
ARG PGHOST='containers-us-west-57.railway.app'
ARG PGPORT=6639
ARG PGDATABASE='railway'
ARG PGUSER='postgres'


ENV DB_TYPE=postgresdb
ENV DB_POSTGRESDB_DATABASE=$PGDATABASE
ENV DB_POSTGRESDB_HOST=$PGHOST
ENV DB_POSTGRESDB_PORT=$PGPORT
ENV DB_POSTGRESDB_USER=$PGUSER
ENV DB_POSTGRESDB_PASSWORD=$PGPASSWORD

RUN apk add --update jq
RUN corepack enable && corepack prepare --activate
USER node

RUN pnpm install --frozen-lockfile
RUN pnpm build
RUN rm -rf node_modules
RUN jq 'del(.pnpm.patchedDependencies)' package.json > package.json.tmp; mv package.json.tmp package.json
RUN node scripts/trim-fe-packageJson.js
RUN NODE_ENV=production pnpm install --prod --no-optional
RUN find . -type f -name "*.ts" -o -name "*.js.map" -o -name "*.vue" -o -name "tsconfig.json" -o -name "*.tsbuildinfo" | xargs rm -rf
RUN rm -rf packages/@n8n_io/eslint-config packages/editor-ui/src packages/editor-ui/node_modules packages/design-system
RUN rm -rf patches .npmrc *.yaml node_modules/.cache packages/**/node_modules/.cache packages/**/.turbo .config .cache .local .node /tmp/*






ARG ENCRYPTION_KEY

ENV N8N_ENCRYPTION_KEY=$ENCRYPTION_KEY


# 2. Start with a new clean image with just the code that is needed to run n8n
FROM n8nio/base:${NODE_VERSION}
COPY --from=builder /home/node /usr/local/lib/node_modules/n8n
RUN ln -s /usr/local/lib/node_modules/n8n/packages/cli/bin/n8n /usr/local/bin/n8n

COPY docker/images/n8n/docker-entrypoint.sh /

RUN \
	mkdir .n8n && \
	chown node:node .n8n
USER node
ENV NODE_ENV=production
ENTRYPOINT ["tini", "--", "/docker-entrypoint.sh"]
