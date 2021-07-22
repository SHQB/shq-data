#

intent="account for sleep time"


self=$(readlink -f "$0")
rootdir=$(dirname ${self%/*})

cd $rootdir
find . -name "*~1" -delete

date
tics=$(date +%s)
time=$(date +%H:%M)

if [ "x$1" != 'x' ]; then
echo "$tics: wake $*"
echo "$tics: wake $* # $time" >> $rootdir/_data/sleep.yml
tic=$(date +%s%N | cut -c-13)
qm=$(ipfs add -r . -Q)
echo $tic: $qm >> qm.log
else
qm=$(ipfs add -r . -Q)
fi
if ipfs swarm addrs local 1>/dev/null 2>&1; then
gwp=$(ipfs config Addresses.Gateway | cut -d'/' -f 5)
echo url: http://127.0.0.1:$gwp/ipfs/$qm
fi

exit $?;

