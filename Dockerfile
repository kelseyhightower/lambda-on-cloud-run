FROM golang:1.15.5-buster as go-builder
WORKDIR /module
COPY . /module/
ADD aws-lambda-rie /aws-lambda-rie
RUN mkdir -p /opt/extensions
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build

FROM scratch
COPY --from=go-builder /opt/extensions /opt/extensions
COPY --from=go-builder /aws-lambda-rie /aws-lambda-rie
COPY --from=go-builder /module/sum /sum
ENTRYPOINT ["/sum"]
