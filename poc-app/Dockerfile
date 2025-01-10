# syntax=docker/dockerfile:1

###############################################################################
# Stage 1: Build
###############################################################################
FROM golang:1.23-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./

RUN go mod download

COPY main.go ./

RUN go build -o myapp

###############################################################################
# Stage 2: Deploy
###############################################################################
FROM alpine:latest

WORKDIR /root/

COPY --from=builder /app/myapp .

CMD ["./myapp"]
