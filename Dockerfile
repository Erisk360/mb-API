FROM alpine:latest

RUN apk add --no-cache curl bash jq

WORKDIR /app

COPY entrypoint.sh .
COPY .env .

RUN chmod +x entrypoint.sh

ENTRYPOINT ["sh", "-c", "while true; do . ./.env && ./entrypoint.sh; sleep 30; done"]

