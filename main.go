package main

import (
	"github.com/aws/aws-lambda-go/lambda"
)

type Request struct {
	Input []int `json:"input"`
}

type Response struct {
	Sum int `json:"sum"`
}

func EventHandler(r Request) (Response, error) {
	sum := 0
	for _, i := range r.Input {
		sum += i
	}
	return Response{Sum: sum}, nil
}

func main() {
	lambda.Start(EventHandler)
}
