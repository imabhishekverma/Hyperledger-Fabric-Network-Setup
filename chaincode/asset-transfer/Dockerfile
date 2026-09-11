FROM golang:1.20 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY asset_transfer.go ./
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /chaincode-server asset_transfer.go

FROM golang:1.20
COPY --from=build /chaincode-server /chaincode-server
EXPOSE 9999
ENTRYPOINT ["/chaincode-server"]
