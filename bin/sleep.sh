#

# options:
if [ "o$1" = 'o-n' ]; then
  sim=1; shift;
fi

self=$(readlink -f "$0")
rootdir=$(dirname ${self%/*})
if [ ! -d "$rootdir/_data" ]; then mkdir -p "$rootdir/_data"; fi

pgm=${0##*/}
rname=${pgm%.*}

intent="account for life surprises and $rname's"
echo "--- # $pgm"
echo "intent: $intent"
echo "date: $(date)"
echo "self: $self"
echo "rootdir: $rootdir"

cd $rootdir
find . -name "*~1" -delete

tics=$(date +%s)
time=$(date +%H:%M)
if [ "_$rname" = '_plog' ]; then
 what="$1"
 shift;
else
 what="$pgm"
fi
if [ -e $rootdir/_data/${what%.*}.yml ]; then
  plogf=${what%.*}
  whatp=''
else
 case "$what" in
   "I am") plogf=mood;;
   *am) plogf=mood;;
   *have) plogf=$rname;;
   *had) plogf=$rname;;
   peed*) plogf=peelog;;
   breakfast) plogf=meals;;
   lunch) plogf=meals;;
   snack) plogf=meals;;
   dinner) plogf=meals;;
   *) plogf=$rname;
 esac
 whatp=" $what"
fi

if [ "x$1" != 'x' ]; then
echo "$tics: $what $*"
echo "$tics:$whatp $* # $time" >> $rootdir/_data/$plogf.yml
if [ -e qm.log.ots ]; then
ots upgrade qm.log.ots
git add qm.log.ots
mv -f qm.log.ots qmprev.log.ots
rm -f qmprev.log.ots.bak
ots upgrade qmprev.log.ots
fi
tic=$(date +%s%N | cut -c-13)
qm=$(ipfs add -r . -Q)
echo $tic: $qm >> qm.log
ots stamp qm.log
else
qm=$(ipfs add -r . -Q)
if [ -e qm.log.ots ]; then
  #rm -f qm.log.ots.bak
  ots upgrade qm.log.ots
  git add qm.log.ots
else
  ots stamp qm.log
fi
fi

if [ "do$sim" = 'do' ]; then
 ipfs files rm -r /public/data 
 ipfs files cp /ipfs/$qm/_data /public/data
 ipfs files stat /ipfs/$qm/_data
fi
 symb=shq-data
 gwp=$(ipfs config Addresses.Gateway | cut -d'/' -f 5)
 key=$(ipfs key list -l --ipns-base=b58mh | grep -w $symb | head -1 | cut -d' ' -f1)
 echo url: http://127.0.0.1:$gwp/ipfs/$qm/_data/$plogf.yml
if ipfs swarm addrs local 1>/dev/null 2>&1; then
 ipfs name publish --allow-offline --key=$symb /ipfs/$qm/_data 1>/dev/null 2>&1 &
 echo url: http://127.0.0.1:$gwp/ipns/$key/$plogf.yml
 k171=$(echo "opendata 4.0" | ipfs add --pin=true -Q --hash sha3-224 --cid-base base36)
 echo token: $k171
 echo  ipfs dht findprovs -n 1 /ipfs/$k171
 ipfs dht provide $k171 &
 ipfs dht provide $qm &
 echo url: https://gateway.ipfs.io/ipns/$key/
fi

exit $?;
true; # vim:ft=sh
