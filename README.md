# Neuro: Building nets one connection at a time

Use AWS Lambda + API Gateway for serverless apps in the cloud.

Currently, `neuro` is built as a bash shell script that uses AWS command line
tools to perform the heavy lifting. It uses git 

### Development Setup

You will need [aws command line tools][aws-cli] (`sudo pip install awscli`).
You will need to have `bash`, `git`, and `zip` installed.


#### AWS Setup

TODO: have a script that will run with root credentials to provision the rest.

You will need an AWS IAM User with rights to publish lambda functions.
You will need a IAM profile for running lambda commands.
You will need an AWS IAM User with rights to API Gateway.

[aws-cli]: https://aws.amazon.com/cli/
