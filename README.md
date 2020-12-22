# nocicd

Agentless CI/CD script.

*nocicd* as in "No CI/CD" where "no" means minimal or agentless.
CI/CD stands for continuous integration / continuous delivery.

If one wanted to have CI/CD in a personal project or within a small team,
using something like Jenkins feels a bit too much. There are more lightweight
solutions but we can do better. Or lighter.

As far as I can tell a small bash script is enough.

Pros:

- No or minimal installation.
- Customizable. Sky is the limit.

## The idea

After pushing code it would be nice for higher environments to be built
and tests executed. But instead of having agent based solution we can
achieve this basic functionality with a script that, for example:

1. Updates a higher environment, say `dev`, and runs tests there.
2. If successful, updates an environment higher than that, say `uat`,
   runs tests there and creates a release-candidate.
3. And whatever more is needed (like doing actual deployment).

## Usage example

1. Create a new GitHub repository *some_repo*.
2. Execute "nocicd_init.sh" script.

You could do

```shell
bash <(curl $INIT) -d <your_directory> -g <your_github_user> -r <some_repo>
```

where

```shell
INIT=https://raw.githubusercontent.com/uigctaw/nocicd/main/nocicd_init.sh
```

But given it's just an example, quite likely you will need to modify
or re-write the script before running it. So suggest doing `wget $INIT`
first and then modifying the script locally.

Roughly, what this particular script does:

1. Clones a repository locally and on `dev` and `uat` users (which represent
   the respective environments).
2. Creates script "nocicd.sh" (+ contrived "run_tests.sh" script) that:
    1. Connects to `dev` via SSH (in this example it's on localhost)
       and git pulls main branch and then runs the test script.
    2. Connects to `uat` and git pulls main, runs tests, git pulls
       *release-candidate* branch, merges main to it, runs tests
       and finally git pushes.

With it the workflow is:

1. Work on your project.
2. Once you are done with everything locally, push to main.
3. Execute "nocicd.sh" script to trigger relevant actions to be executed
   in higher environments.

----
    
Everything here has been written on Ubuntu 20.
