FROM golang:1.24-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o main .

FROM alpine:3.20

# Create non-root user (UID 10001)
RUN addgroup -g 10001 appgroup && \
    adduser -u 10001 -G appgroup -D -s /sbin/nologin appuser

WORKDIR /home/appuser
COPY --from=builder --chown=10001:10001 /app/main .

USER 10001:10001
EXPOSE 8080

ENTRYPOINT ["./main"]