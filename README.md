# Lambda Functions on Cloud Run Tutorial

This tutorial walks you through building and deploying an [AWS Lambda](https://aws.amazon.com/lambda/) function [packaged in a container image](https://aws.amazon.com/blogs/aws/new-for-aws-lambda-container-image-support) to [Cloud Run](https://cloud.google.com/run).

## Prerequisites

This tutorial assumes you have a GCP and AWS account and the corresponding commandline tools installed.

Verify `gcloud` is installed:

```
gcloud --version
```
```
Google Cloud SDK 319.0.0
```

Verify `aws` is installed: 

```
aws --version
```
```
aws-cli/2.1.6 ...
```

This tutorial leverages `docker` to build images locally:

```
docker version
```
```
Client: Docker Engine - Community
 Version:           19.03.14
```

Clone this repo and change into the `lambda-on-cloud-run` directory:

```
git clone https://github.com/kelseyhightower/lambda-on-cloud-run.git
```

```
cd lambda-on-cloud-run/
```

> This tutorial assumes `lambda-on-cloud-run` is the current working directory.

## Testing Locally

In this section you will build and test the `sum` Lambda function locally. The `sum` function is written in Go using the [`aws-lambda-go`](https://github.com/aws/aws-lambda-go) Go library. The `sum` function adds a set of integers and returns the sum.

Example input:

```
{"input": [1,2,3]}
```

Response:

```
{"sum":6}
```

Build the `sum` Go binary:

```
go build .
```

If you attempt to run the `sum` binary you'll get the following error:

```
2020/12/02 09:19:15 expected AWS Lambda environment variables [_LAMBDA_SERVER_PORT AWS_LAMBDA_RUNTIME_API] are not defined
```

Lambda functions are not servers that listen on a port. Lambda functions are clients that run inside an AWS Lambda environment. In order to test the `sum` function locally we need to emulate a working Lambda environment. That's where the [Lambda Runtime Interface Emulator](https://github.com/aws/aws-lambda-runtime-interface-emulator/) comes in.

While the Lambda Runtime Interface Emulator was designed to run inside a container image, it can also be run directly on a Linux machine.

The emulator checks a few directories during startup so lets create those now:

```
sudo mkdir /opt/extensions
```

Start the emulator and pass it the relative path to the `sum` function binary:

```
./aws-lambda-rie ./sum
```
```
INFO[0000] exec 'echo' (cwd=/home/khightower/lambda-on-cloud-run, handler=) 
```

At this point the `aws-lambda-rie` emulator is up and running on port 8080. Open a separate terminal and submit an event to the `sum` function: 

```
curl -i -X POST \
  "http://127.0.0.1:8080/2015-03-31/functions/function/invocations" \
  -d '{"input": [1,2,3]}'
```

```
HTTP/1.1 200 OK
Content-Length: 9
Content-Type: text/plain; charset=utf-8

{"sum":6}
```

## Build Docker Image

Now that we have proven the `sum` function is working. It's time to package the `sum` function binary in a container image using Docker.

Build the `sum` container image and tag it:

```
docker build -t sum:0.0.1 .
```

```
Successfully built 39e4b4b3bb47
Successfully tagged sum:0.0.1
```

At this point you should have a couple of docker images in your local repository:

```
docker images
```
```
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
sum                 0.0.1               39e4b4b3bb47        19 seconds ago      17.4MB
<none>              <none>              4582118131f5        27 seconds ago      886MB
golang              1.15.5-buster       6d8772fbd285        13 days ago         839MB
```

# Deploy to Cloud Run

Before you can deploy to Cloud Run you need to push the `sum` container image to Google's [Container Registry](https://cloud.google.com/container-registry) or [Artifact Registry](https://cloud.google.com/artifact-registry) as described in [Cloud Run docs](https://cloud.google.com/run/docs/deploying#images)

In this section we are going to push the `sum` container image to the same project we plan to deploy to later.

Capture the current GCP project ID:

```
PROJECT_ID=$(gcloud config get-value project)
```

Tag the `sum` container image using a [valid Container Registry name](https://cloud.google.com/container-registry/docs/pushing-and-pulling#tag_the_local_image_with_the_registry_name):

```
docker tag sum:0.0.1 gcr.io/${PROJECT_ID}/sum:0.0.1
```

```
docker images
```
```
REPOSITORY                 TAG                 IMAGE ID            CREATED             SIZE
sum                        0.0.1               39e4b4b3bb47        2 minutes ago       17.4MB
gcr.io/hightowerlabs/sum   0.0.1               39e4b4b3bb47        2 minutes ago       17.4MB
<none>                     <none>              4582118131f5        2 minutes ago       886MB
golang                     1.15.5-buster       6d8772fbd285        13 days ago         839MB
```

Before you can push to the container registry you need to authenticate:

```
gcloud auth configure-docker
```

Push the `gcr.io/${PROJECT_ID}/sum:0.0.1` image to the container registry:

```
docker push gcr.io/${PROJECT_ID}/sum:0.0.1
```
```
The push refers to repository [gcr.io/hightowerlabs/sum]
dfcf3d04c699: Pushed 
2745df127edc: Layer already exists 
bd501ff22e48: Pushed 
0.0.1: digest: sha256:87fd1dcfc1d9221b28d4d20d032bf8597e23c4307db06835c8c187576d03c8bf size: 946
```

## Create the Cloud Run Service

With the `sum` container image in place you are now ready to deploy it to Cloud Run.

Capture the current GCP project ID:

```
PROJECT_ID=$(gcloud config get-value project)
```

Deploy the `sum` Cloud Run service:

```
gcloud run deploy sum \
  --allow-unauthenticated \
  --command "/aws-lambda-rie" \
  --args "/sum" \
  --concurrency 80 \
  --cpu 1 \
  --image gcr.io/${PROJECT_ID}/sum:0.0.1 \
  --memory '1G' \
  --platform managed \
  --port 8080 \
  --region us-west1 \
  --timeout 30
```

```
Deploying container to Cloud Run service [sum] in project [hightowerlabs] region [us-west1]
✓ Deploying new service... Done.
  ✓ Creating Revision... Deploying Revision.
  ✓ Routing traffic...
  ✓ Setting IAM Policy...
Done.
Service [sum] revision [sum-00001-vev] has been deployed and is serving 100 percent of traffic.
Service URL: https://sum-XXXXXXXXXX-uw.a.run.app
```

## Test the Cloud Run Service

Capture the `sum` Cloud Run service URL:

```
CLOUD_RUN_URL=$(gcloud run services describe sum \
  --platform managed \
  --region us-west1 \
  --format='value(status.url)')
```

Submit an event to the `sum` Cloud Run service:

```
curl -i -X POST \
  ${CLOUD_RUN_URL}/2015-03-31/functions/function/invocations \
  -d '{"input": [1,2,3]}'
```

```
HTTP/2 200 
date: Wed, 02 Dec 2020 16:54:04 GMT
content-length: 9
content-type: text/plain; charset=utf-8
server: Google Frontend

{"sum":6}
```

## Deploy to Lambda

I'll add more details later, but these are the commands to tag and push the `sum` container image to ECR, deploy it to Lambda, and invoke the `sum` function.

Create an ECR repository:

```
aws ecr create-repository --repository-name sum
```

Capture the registry id:

```
AWS_REGISTRY_ID=$(aws ecr describe-repositories \
  --repository-name sum \
  --query 'repositories[0].registryId' \
  --output text)
```

Authenticate to the ECR repository:

```
aws ecr get-login-password --region us-west-2 | \
  docker login \
    --username AWS \
    --password-stdin \
    ${AWS_REGISTRY_ID}.dkr.ecr.us-west-2.amazonaws.com
```

Capture the ECR repository URI:

```
AWS_REPOSITORY_URI=$(aws ecr describe-repositories \
  --repository-name sum \
  --query 'repositories[0].repositoryUri' \
  --output text)
```

Tag the `sum` container image:

```
docker tag sum:0.0.1 ${AWS_REPOSITORY_URI}:0.0.1
```

```
docker images
```
```
REPOSITORY                                         TAG                 IMAGE ID            CREATED             SIZE
231532395880.dkr.ecr.us-west-2.amazonaws.com/sum   0.0.1               39e4b4b3bb47        2 hours ago         17.4MB
sum                                                0.0.1               39e4b4b3bb47        2 hours ago         17.4MB
gcr.io/hightowerlabs/sum                           0.0.1               39e4b4b3bb47        2 hours ago         17.4MB
<none>                                             <none>              4582118131f5        2 hours ago         886MB
golang                                             1.15.5-buster       6d8772fbd285        13 days ago         839MB
```

Push the container image to GCR:

```
docker push ${AWS_REPOSITORY_URI}:0.0.1
```

```
The push refers to repository [231532395880.dkr.ecr.us-west-2.amazonaws.com/sum]
dfcf3d04c699: Pushed 
2745df127edc: Pushed 
bd501ff22e48: Pushed 
0.0.1: digest: sha256:87fd1dcfc1d9221b28d4d20d032bf8597e23c4307db06835c8c187576d03c8bf size: 946
```

Create an IAM role for the `sum` lambda function:

```
aws iam create-role \
  --role-name lambda \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{ "Effect": "Allow", "Principal": {"Service": "lambda.amazonaws.com"}, 
    "Action": "sts:AssumeRole"}]
  }'
```

Capture the role ARN:

```
LAMBDA_ROLE_ARN=$(aws iam get-role \
  --role-name lambda \
  --query 'Role.Arn' \
  --output text)
```

### Create the Lambda Function

```
aws lambda create-function \
  --code "ImageUri=${AWS_REPOSITORY_URI}:0.0.1" \
  --function-name sum \
  --package-type Image \
  --region us-west-2 \
  --role ${LAMBDA_ROLE_ARN}
```

### Test the Lambda Function

```
aws lambda invoke \
  --cli-binary-format raw-in-base64-out \
  --function-name sum \
  --payload '{"input": [1,2,3]}' \
  response.json
```

```
{
    "StatusCode": 200,
    "ExecutedVersion": "$LATEST"
}
```

```
cat response.json
```

```
{"sum":6}
```
