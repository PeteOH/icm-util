#!/bin/bash -e
source envs.sh

if [ ! -e iris.key ]; then
  echo "License key (iris.key) doesn't exist."
  exit 1
fi

if [ $provider = "aws" ]; then
  if [ ! -e ~/.aws/credentials ]; then
    echo "AWS credential doesn't exist."
    exit 1
  fi
fi

if [ ! -d $provider/$targetos ]; then
    echo "json files directory doesn't exist."
    exit 1
fi

if [ ! -e $kitname ]; then
  echo "Kit $kitname doesn't exist."
  exit 1
fi

# Don't re-use the container
docker stop $icmname | true
docker rm $icmname | true

docker run -d --name $icmname $icmimg tail -f /dev/null
docker exec $icmname sh -c "keygenTLS.sh; keygenSSH.sh"
docker exec $icmname mkdir -p /Production/license

docker cp $kitname $icmname:/root
docker exec $icmname mkdir -p $icmdata
docker cp $provider/$targetos/$defaults $icmname:$icmdata/defaults.json
# pick a definitions.json to use here.
docker cp definitions-shard.json $icmname:$icmdata/definitions.json

# need to aquire a valid aws credential beforehand
if [ $provider = "aws" ]; then
  docker cp ~/.aws/credentials $icmname:$icmdata/credentials
fi
#; place your valid license key here
docker cp iris.key $icmname:/Production/license/

docker exec $icmname sh -c "cd $icmdata; icm provision; icm scp -localPath /root/$kitname -remotePath /tmp; icm install"

# ++ ICM uses public ip for shard members. I want to avoid it. ++
# try to get private IPs
docker exec $icmname sh -c "cd $icmdata; icm ps -json > /dev/null; cat response.json" > res.json
docker exec $icmname sh -c "cd $icmdata; icm ps -json > /dev/null; cat response.json" | python3 decode-pubip.py > pubip.txt

if [ $targetos = "ubuntu" ]; then
  rm cmd.sh | true
  while read line
  do
    if [ $provider = "aws" ]; then
      printf "docker exec $icmname sh -c \"ssh -i /Samples/ssh/insecure -oStrictHostKeyChecking=no ubuntu@$line 'curl -s http://169.254.169.254/latest/meta-data/local-ipv4'; echo ''\"\n" >> cmd.sh
    fi
    if [ $provider = "azure" ]; then
      printf "docker exec myicm sh -c \"ssh -i /Samples/ssh/insecure -oStrictHostKeyChecking=no ubuntu@$line ip -4 -br a show dev eth0 | awk '{ print \\\$3}' | awk -F'/' '{ print \\\$1 }'\"\n" >> cmd.sh
    fi
  done < ./pubip.txt
  ./cmd.sh > privateip.txt

  # copy ip infos to DM to run helper routine which deassigns/assigns shards.
  docker cp pubip.txt $icmname:/root
  docker cp privateip.txt $icmname:/root
  docker cp helper.mac $icmname:/root
  docker cp reassign-shard.sh $icmname:/root
  docker exec $icmname /root/reassign-shard.sh $icmdata
fi
# -- ICM uses public ip for shard members. I want to avoid it. --

# install app classes
docker cp install-apps.sh $icmname:/root
docker cp icmcl-atelier-prj $icmname:/root
docker exec $icmname /root/install-apps.sh $icmdata
# verification
ip=$(docker exec $icmname sh -c "cd $icmdata; icm ps -json > /dev/null; cat response.json" | python3 decode-dmname.py)
curl -H "Content-Type: application/json; charset=UTF-8" -H "Accept:application/json" "http://$ip:52773/csp/myapp/get" --user "SuperUser:sys"