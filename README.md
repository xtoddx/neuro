# Neuro: Building nets one connection at a time

Use AWS Lambda + API Gateway for serverless apps in the cloud.

Currently, `neuro` is built as a bash shell script that uses AWS command line
tools to perform the heavy lifting.
It uses git to build a repository to host the lambda functions
and permission definitions for the roles that execute the functions.

### Development Setup

You will need [aws command line tools][aws-cli] installed.
You will need to have `bash`, `git`, `base64` and `zip` installed.

Neuro lets you specify credential profiles for the aws command line tools
so that each operation can be performed with only the required permissions.
Place the name of the profile in your project's config.env file.

Example:

    aws --profile root # provide credentials for admin level functions
    echo "AWS_POLICY_PROFILE=root" >> config.env
    echo "AWS_BOOTSTRAP_PROFILE=root" >> config.env

    aws --profile lambda # provide credentials for user with lambda permissions
    echo "AWS_LAMBDA_UPLOAD_PROFILE=lambda" >> config.env
    echo "AWS_LAMBDA_LIST_PROFILE=lambda" >> config.env
    echo "AWS_LAMBDA_INVOKE_PROFILE=lambda" >> config.env

#### AWS Setup

The best way to start using neuro is to run `neuro bootstrap-aws`
to create an execution role that lambda will use to run functions.
You will need to copy the ARN of the role into your projects config.env file.

You can use neuro to build execution roles and manage permissions that
are used by lambda to run your scripts.
    neuro add-role basic-execution
    # change policy.json if desired, eg: add access to RDS
    neuro deploy-role

You can use the per-function configuration (config.function.env) to specify
a different execution profile for the given function.
In this way you can build profiles that access services like RDS,
but not give those permissions to all the functions running in your API.

[aws-cli]: https://aws.amazon.com/cli/
