#!/usr/bin/env bash
set -eu

earth=${earth:=earth}
echo "running tests with $earth"

# prevent the self-update of earth from running (this ensures no bogus data is printed to stdout,
# which would mess with the secrets data being fetched)
echo $(date +%s) > /tmp/last-earth-prerelease-check

# test secrets ls / works
$earth secrets ls /

# fetch shared secret key (this step assums your personal user has access to the /earthly-technologies/ secrets org
ID_RSA=$($earth secrets get -n /earthly-technologies/github/other-service+github-cinnamon@earthly.dev/id_rsa)
GITHUB_PASSWORD=$($earth secrets get -n /earthly-technologies/github/other-service+github-cinnamon@earthly.dev/password)

# start up a new instance of ssh-agent, and add load the shared key
echo starting new instance of ssh-agent, and loading c
eval $(ssh-agent)
echo "$ID_RSA" | ssh-add -

# test the key got loaded
ssh-add -l | grep cinnamonthecat

# test exactly one key exists
test `ssh-add -l | wc -l` = "1"

# Test a private repo can be cloned
echo === Test 1 ===
docker image rm -f test-private:latest
$earth -VD github.com/cinnamonthecat/test-private:main+docker
docker run --rm test-private:latest | grep "Salut Lume"

# Test public repo can be cloned without ssh, when GIT_URL_INSTEAD_OF is set as recommended by our CI docs
echo === Test 2 ===
docker image rm -f cpp-example:latest
SSH_AUTH_SOCK="" GIT_URL_INSTEAD_OF="https://github.com/=git@github.com:" $earth -VD github.com/earthly/earthly/examples/cpp:main+docker
docker run --rm cpp-example:latest | grep fib

#TODO FIXME, this actually doesn't work as-is unless a user and password is also given.
# Test public repo can be cloned via https when configured via ~/.earthly/config.yml
#echo === Test 3 ===
#cat << EOF > /tmp/earthconfig.https
#git:
#  github.com:
#    auth: https
#EOF
#docker image rm -f cpp-example:latest
#SSH_AUTH_SOCK="" $earth -VD github.com/earthly/earthly/examples/cpp:main+docker
#docker run --rm cpp-example:latest | grep fib

# Test a private repo can be cloned using https
echo === Test 4 ===

cat << EOF > /tmp/earthconfig.https
git:
  github.com:
    auth: https
    user: cinnamonthecat
    password: "$GITHUB_PASSWORD"
EOF
cat /tmp/earthconfig.https

docker image rm -f other-test-private:latest
SSH_AUTH_SOCK="" $earth -VD --config /tmp/earthconfig.https github.com/cinnamonthecat/other-test-private:main+docker
docker run --rm other-test-private:latest | grep "Salut le monde"

# Test a private repo can be cloned using https, as setup via args
echo === Test 5 ===

docker image rm -f other-test-private:latest
SSH_AUTH_SOCK="" $earth -VD --git-username=cinnamonthecat --git-password="$GITHUB_PASSWORD" github.com/cinnamonthecat/other-test-private:main+docker
docker run --rm other-test-private:latest | grep "Salut le monde"
