# --- Build stage ---
FROM golang:1.22-alpine AS builder

WORKDIR /src
COPY go.mod ./
COPY *.go ./

RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /demo-app .

# --- Runtime stage ---
FROM gcr.io/distroless/static-debian12:nonroot

COPY --from=builder /demo-app /demo-app

EXPOSE 8080

ENTRYPOINT ["/demo-app"]
