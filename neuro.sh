# TODO:
# * add: update a swagger spec
# * import: batch create endpoints from swagger spec
# * inventory: show known endpoints (akin to `rake routes`)
# * clone: use an existing git repo of fuction endpoints
# * commit to git on deploy
# * doc how to wrap common things (auth, etc) into a node package to deploy w/

set -e

function new {
  local app_name=$1
  mkdir -p ${app_name}/.repository/endpoints
  (cd ${app_name}/.repository && git init --quiet)
  cat <<EOF > ${app_name}/config.env
LAMBDA_EXECUTION_ROLE=arn:aws:iam::ACCOUNT_NUMBER:role/lambda_basic_execution
AWSCLI_DEFAULT_PROFILE=default
AWSCLI_BOOTSTRAP_PROFILE=dangerous_profile_with_iam_policy_permissions
AWSCLI_LAMBDA_UPLOAD_PROFILE=\${AWSCLI_DEFAULT_PROFILE}
AWSCLI_LAMBDA_LIST_PROFILE=\${AWSCLI_DEFAULT_PROFILE}
AWSCLI_LAMBDA_INVOKE_PROFILE=\${AWSCLI_DEFAULT_PROFILE}
EOF
  echo "Great! Now cd into ${app_name} and get started building your application."
  echo "Next steps:"
  echo "  * Edit config.env to set your profiles and roles."
  echo "  * Add an endpoint (try: \`neuro add /posts/new get\`)"
  echo "  * Deploy the lambda function for the endpoint (\`neuro deploy\`)"
  echo "  * Invoke the lambda function (\`neuro invoke\`, passes valid.json to function)"
  echo "  * Change which endpoint you're working on with \`neuro edit /posts/new get\`"
}

function add {
  local href=$1
  local method=$2 # TODO: default to GET maybe?
  local lambda_name="${href}.${method}.js"
  local lambda_dir=`dirname ${lambda_name}`
  mkdir -p .repository/endpoints${lambda_dir}
  cat <<EOF > .repository/endpoints${lambda_name}
// ${method} ${href}

exports.handler = function(event, context) {
  context.succeed('Good Job!');
};
EOF
  cat <<EOF > .repository/endpoints${href}.${method}.valid.json
{}
EOF
  edit ${href} ${method}
}

function edit {
  local href=$1
  local method=$2 # TODO: optional if there is only one method
  if [ -f index.js ] ; then rm index.js ; fi
  if [ -f valid.json ] ; then rm valid.json ; fi
  ln -s .repository/endpoints${href}.${method}.js index.js
  ln -s .repository/endpoints${href}.${method}.valid.json valid.json
}

function deploy {
  local method=`readlink index.js | sed -e 's!.repository/endpoints!!' \
                                        -e 's/.js$//' | awk -F. '{print $NF}'`
  local path=`readlink index.js | sed -e 's!.repository/endpoints!!' \
                                      -e 's/.js$//' -e "s/.${method}$//"`
  local fn_name=`echo ${method}${path} | sed -e 's./._.g'`
  zip -q ${fn_name}.zip index.js

  neuro.function_exists $fn_name
  if [ $? == 0 ] ; then
    aws --profile ${AWSCLI_LAMBDA_UPLOAD_PROFILE} \
        lambda update-function-code --function-name "${fn_name}" \
                                    --zip-file fileb://${fn_name}.zip
  else
    aws --profile ${AWSCLI_LAMBDA_UPLOAD_PROFILE} \
        lambda create-function --function-name "${fn_name}" \
                               --runtime nodejs \
                               --handler index.handler \
                               --role ${LAMBDA_EXECUTION_ROLE} \
                               --zip-file fileb://${fn_name}.zip
  fi

  rm ${fn_name}.zip
}

function invoke {
  local method=`readlink index.js | sed -e 's!.repository/endpoints!!' \
                                        -e 's/.js$//' | awk -F. '{print $NF}'`
  local path=`readlink index.js | sed -e 's!.repository/endpoints!!' \
                                      -e 's/.js$//' -e "s/.${method}$//"`
  local fn_name=`echo ${method}${path} | sed -e 's./._.g'`
  aws --profile ${AWSCLI_LAMBDA_INVOKE_PROFILE} \
      lambda invoke --function-name ${fn_name} \
                    --invocation-type RequestResponse \
                    --log-type Tail \
                    --payload fileb://valid.json \
                    output.txt > log.txt
  cat output.txt
  echo
  rm output.txt
  echo ----
  local status=`cat log.txt | grep StatusCode | awk -F: '{print $2}'`
  echo status: ${status}
  cat log.txt | grep LogResult | awk -F: '{print $2}' | \
     sed -e 's/^\s*"//' -e 's/".*$//' | base64 --decode
  rm log.txt
}

function bootstrap_aws {
  local role_name=neuro_lambda_bootstrap
  cat <<EOF > assume_role_policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
  role_arn=$(
  aws --profile ${AWSCLI_BOOTSTRAP_PROFILE} \
      --query "Role.Arn" \
      iam create-role \
      --role-name ${role_name} \
      --assume-role-policy-document file://assume_role_policy.json
  )
  rm assume_role_policy.json
  cat <<EOF > exe_policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
EOF
  aws --profile ${AWSCLI_BOOTSTRAP_PROFILE} \
      iam put-role-policy \
      --role-name ${role_name} \
      --policy-name neuro_bootstrap_exe_policy \
      --policy-document file://exe_policy.json
  rm exe_policy.json
  echo "created IAM role ${role_name}"
  echo "You should put the value"
  echo -n "    LAMBDA_EXECUTION_ROLE="
  echo ${role_arn}
  echo "into your config.env file to use this exeuction role"
  echo "(replacing any value that is currently there.)"
}

function __help {
  help $*
}

function help {
  echo "Available Commands"
  echo " *  bootstrap-aws"
  echo " *  new PROJECTNAME"
  echo " *  add HREF HTTPMETHOD"
  echo " *  edit HREF HTTPMETHOD"
  echo " *  deploy"
  echo " *  invoke"
}

function neuro.function_exists {
  local fn_name=$1
  aws --profile ${AWSCLI_LAMBDA_LIST_PROFILE} \
      lambda get-function --function-name ${fn_name} 2>&1 > /dev/null
  return $?
#  aws --profile ${AWSCLI_LAMBDA_LIST_PROFILE} \
#      --query "Functions[?FunctionName == '$1'].FunctionName | [0]" \
#      lambda list-functions
}

fn=$1 ; shift
fn_name=`echo ${fn} | sed -e 's.-._.g'`
if [ -f config.env ] ; then
  source config.env
fi
${fn_name} $*
