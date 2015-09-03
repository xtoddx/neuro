# TODO:
# * deploy: check for update v. create function (store ARN somewhere?)
# * add: update a swagger spec
# * import: batch create endpoints from swagger spec
# * inventory: show known endpoints (akin to `rake routes`)
# * clone: use an existing git repo of fuction endpoints
# * commit to git on deploy
# * doc how to wrap common things (auth, etc) into a node package to deploy w/

function new {
  local app_name=$1
  mkdir -p ${app_name}/.repository/endpoints
  (cd ${app_name}/.repository && git init --quiet)
  cat <<EOF > ${app_name}/config.env
LAMBDA_EXECUTION_ROLE=arn:aws:iam::ACCOUNT_NUMBER:role/lambda_basic_execution
EOF
  echo -n "Great! Now cd into ${app_name} and "
  echo    "\`neuro add /posts/new get\`"
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
  aws lambda create-function --function-name "${fn_name}" \
                             --runtime nodejs \
                             --handler index.handler \
                             --role ${LAMBDA_EXECUTION_ROLE} \
                             --zip-file fileb://${fn_name}.zip
  rm ${fn_name}.zip
}

function invoke {
  local method=`readlink index.js | sed -e 's!.repository/endpoints!!' \
                                        -e 's/.js$//' | awk -F. '{print $NF}'`
  local path=`readlink index.js | sed -e 's!.repository/endpoints!!' \
                                      -e 's/.js$//' -e "s/.${method}$//"`
  local fn_name=`echo ${method}${path} | sed -e 's./._.g'`
  aws lambda invoke --function-name ${fn_name} \
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

fn=$1 ; shift
fn_name=`echo ${fn} | sed -e 's.-._.'`
source config.env
${fn_name} $*
