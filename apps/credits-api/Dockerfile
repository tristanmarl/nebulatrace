FROM golang:1.23-alpine AS build
WORKDIR /src
COPY go.mod .
COPY main.go .
RUN go build -o /out/credits-api .

FROM alpine:3.20
COPY --from=build /out/credits-api /credits-api
EXPOSE 8080
CMD ["/credits-api"]
