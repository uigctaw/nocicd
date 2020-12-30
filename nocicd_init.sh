#!/bin/bash

set -e

USAGE="
What it does:
1) Clones repos in local, dev and uat environments.
2) Creates a script executing CI/CD (continuous integration /
   continuous delivery) script.

Note:
1) This script is just an example. Customize it.
2) SSH setup is not handled here in any way whatsoever.
3) The assumption is that the repository already exists on GitHub.


Parameters:

-d --rd --repos_dir : 
    Directory relative to \$HOME in which the repository will be located.

-g --gu --github_user :
    Github user name.

-r --repo :
    Repository name.


Optional parameters:

-b --rc --release_candidate (default release-candidate) :
    Name of git branch that will contain release candidates.

-h --help :
    Displays this documentation.

-n --no --nocicd --nocicd_script (default nocicd.sh) :
    Name of the script that will execute the CI/CD pipeline.

--poetry :
    Adds line 'poetry install' to remotely executed commands. Python Poetry.

-t --ts --test --tests --test_script (default run_tests.sh) :
    Name of the script that executes tests.
"

while [[ $# -gt 0 ]]; do
    case $1 in 
        -d|--rd|--repos_dir) REPOS_DIR=$2; shift;;
        -g|--gu|--github_user) GITHUB_USER=$2; shift;;
        -r|--repo) REPO_NAME=$2; shift;;
        -b|--rc|--release_candidate) REPO_NAME=$2; shift;;
        -h|--help) HELP=1;;
        -n|--no|--nocicd|--nocicd_script) NOCICD_SCRIPT=$2; shift;;
        --poetry) POETRY=1;;
        -t|--ts|--test|--tests|--test_script) TEST_SCRIPT=$2; shift;;
        *) UNHANDLEDED_PARAMETER=$1;;
    esac
    if [[ $UNHANDLEDED_PARAMETER != "" ]]; then
        echo "I do not understand $UNHANDLEDED_PARAMETER"
        echo "Type -h for help"
    fi
    shift
done

if [[ $HELP == "1" ]]; then
    echo "$USAGE"
    exit 0
fi

if [[ $REPOS_DIR == "" || $GITHUB_USER == "" || $REPO_NAME == "" ]]; then
    echo "Missing -r, -d or -g"
    echo "Type -h for help"
    exit 1
fi

# defaults (reasonable?)
if [[ $NOCICD_SCRIPT == "" ]]; then
    NOCICD_SCRIPT=nocicd.sh
fi
if [[ $POETRY == 1 ]]; then
    POETRY="poetry install;"
else
    POETRY=""
fi
if [[ $RELEASE_CANDIDATE_BRANCH == "" ]]; then
    RELEASE_CANDIDATE_BRANCH=release-candidate
fi
if [[ $TEST_SCRIPT == "" ]]; then
    TEST_SCRIPT=run_tests.sh
fi

GIT_CLONE_SSH="git clone git@github.com:/$GITHUB_USER/$REPO_NAME.git"

cd $HOME/$REPOS_DIR
$GIT_CLONE_SSH
cd $REPO_NAME

git checkout -b $RELEASE_CANDIDATE_BRANCH
git push -u origin $RELEASE_CANDIDATE_BRANCH
git checkout main

echo '#!/bin/bash' > $TEST_SCRIPT
echo 'exit 0' >> $TEST_SCRIPT
chmod u+x $TEST_SCRIPT

git add .
git commit -am 'initial boilerplate' --allow-empty
git push

ssh dev@localhost -T "
    cd $REPOS_DIR;\
    git clone https://github.com/$GITHUB_USER/$REPO_NAME;\
    "

ssh uat@localhost -T "
    cd $REPOS_DIR;\
    $GIT_CLONE_SSH;\
    "

cat << EOF > $NOCICD_SCRIPT
#!/bin/bash

set -e

REPO_PATH=$REPOS_DIR/$REPO_NAME
RELEASE_CANDIDATE_BRANCH=$RELEASE_CANDIDATE_BRANCH
TEST_SCRIPT=$TEST_SCRIPT

./\$TEST_SCRIPT

ssh dev@localhost -T "\\
    set -e;\\
    . .profile;\\
    cd \$REPO_PATH;\\
    $POETRY\\
    echo 'dev: checkout main and pull';\\
    git checkout main;\\
    git pull;\\
    echo 'dev: run tests';\\
    ./\$TEST_SCRIPT;\\
    " 
ssh uat@localhost -T "\\
    set -e;\\
    . .profile;\\
    cd \$REPO_PATH;\\
    $POETRY\\
    echo 'uat: checkout main and pull';\\
    git checkout main;\\
    git pull;\\
    echo 'uat: run tests';\\
    ./\$TEST_SCRIPT;\\
    echo 'uat: checkout \$RELEASE_CANDIDATE_BRANCH and pull';\\
    git checkout \$RELEASE_CANDIDATE_BRANCH;\\
    git pull;\\
    echo 'uat: merge main to \$RELEASE_CANDIDATE_BRANCH';\\
    git merge main;\\
    echo 'uat: run tests';\\
    ./\$TEST_SCRIPT;\\
    git push;\\
    " 
EOF

chmod u+x nocicd.sh
