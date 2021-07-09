#!/bin/bash
source .env

if [ $# -eq 0 ]
  then
    clear
    echo "Usage
     ./create_service.sh
        -t TYPE (CX11 / CX21 / CX 31 / CX41)
        -n NAME (Server name; Domain will extend to *.$domain)
        -i INSTALLER (Nextcloud / Mail)
	-s SILENT (Silent output true/false)
	-d DNS (Add DNS Entries yes/no)
     "
    exit 0;
fi


while getopts s:t:n:i:d: option
do
case "${option}"
in
s) SILENT=${OPTARG};;
t) TYPE=${OPTARG};;
n) NAME=${OPTARG};;
i) INSTALLER=${OPTARG};;
d) DNS=${OPTARG};;
esac
done

serverName=$NAME
serverType=$TYPE

clear

if [ -z "$token" ]
then 
	clear
	echo "No API token defined! (please update .env)"
	exit 0;
fi

function docker_create {

	docker run \
	-e HCLOUD_TOKEN=$token \
	-v $(pwd)/init.yml:/tmp/init.yml \
	--rm askoproducts/hcloud \
	hcloud server create \
	--image $serverImage \
	--type $serverType \
	--ssh-key $sshKey \
	--user-data-from-file /tmp/init.yml \
	--network $networkID \
	--location $serverLocation \
	--name $serverName.$domain

}

function delay()
{
    sleep 0.2;
}

#
# Description : print out executing progress
# 
CURRENT_PROGRESS=0
function progress()
{
    PARAM_PROGRESS=$1;
    PARAM_STATUS=$2;

    if [ $CURRENT_PROGRESS -le 0 -a $PARAM_PROGRESS -ge 0 ]  ; then echo -ne "[..........................] (0%)  $PARAM_PHASE \r"  ; delay; fi;
    if [ $CURRENT_PROGRESS -le 5 -a $PARAM_PROGRESS -ge 5 ]  ; then echo -ne "[#.........................] (5%)  $PARAM_PHASE \r"  ; delay; fi;
    if [ $CURRENT_PROGRESS -le 10 -a $PARAM_PROGRESS -ge 10 ]; then echo -ne "[##........................] (10%) $PARAM_PHASE \r"  ; delay; fi;
    if [ $CURRENT_PROGRESS -le 15 -a $PARAM_PROGRESS -ge 15 ]; then echo -ne "[###.......................] (15%) $PARAM_PHASE \r"  ; delay; fi;
    if [ $CURRENT_PROGRESS -le 20 -a $PARAM_PROGRESS -ge 20 ]; then echo -ne "[####......................] (20%) $PARAM_PHASE \r"  ; delay; fi;
    if [ $CURRENT_PROGRESS -le 25 -a $PARAM_PROGRESS -ge 25 ]; then echo -ne "[#####.....................] (25%) $PARAM_PHASE \r"  ; delay; fi;
    if [ $CURRENT_PROGRESS -le 30 -a $PARAM_PROGRESS -ge 30 ]; then echo -ne "[######....................] (30%) $PARAM_PHASE \r"  ; delay; fi;
    if [ $CURRENT_PROGRESS -le 35 -a $PARAM_PROGRESS -ge 35 ]; then echo -ne "[#######...................] (35%) $PARAM_PHASE \r"  ; delay; fi;
    if [ $CURRENT_PROGRESS -le 40 -a $PARAM_PROGRESS -ge 40 ]; then echo -ne "[########..................] (40%) $PARAM_PHASE \r"  ; delay; fi;
    if [ $CURRENT_PROGRESS -le 45 -a $PARAM_PROGRESS -ge 45 ]; then echo -ne "[#########.................] (45%) $PARAM_PHASE \r"  ; delay; fi;
    if [ $CURRENT_PROGRESS -le 50 -a $PARAM_PROGRESS -ge 50 ]; then echo -ne "[##########................] (50%) $PARAM_PHASE \r"  ; delay; fi;
    if [ $CURRENT_PROGRESS -le 55 -a $PARAM_PROGRESS -ge 55 ]; then echo -ne "[###########...............] (55%) $PARAM_PHASE \r"  ; delay; fi;
    if [ $CURRENT_PROGRESS -le 60 -a $PARAM_PROGRESS -ge 60 ]; then echo -ne "[############..............] (60%) $PARAM_PHASE \r"  ; delay; fi;
    if [ $CURRENT_PROGRESS -le 65 -a $PARAM_PROGRESS -ge 65 ]; then echo -ne "[#############.............] (65%) $PARAM_PHASE \r"  ; delay; fi;
    if [ $CURRENT_PROGRESS -le 70 -a $PARAM_PROGRESS -ge 70 ]; then echo -ne "[###############...........] (70%) $PARAM_PHASE \r"  ; delay; fi;
    if [ $CURRENT_PROGRESS -le 75 -a $PARAM_PROGRESS -ge 75 ]; then echo -ne "[#################.........] (75%) $PARAM_PHASE \r"  ; delay; fi;
    if [ $CURRENT_PROGRESS -le 80 -a $PARAM_PROGRESS -ge 80 ]; then echo -ne "[####################......] (80%) $PARAM_PHASE \r"  ; delay; fi;
    if [ $CURRENT_PROGRESS -le 85 -a $PARAM_PROGRESS -ge 85 ]; then echo -ne "[#######################...] (90%) $PARAM_PHASE \r"  ; delay; fi;
    if [ $CURRENT_PROGRESS -le 90 -a $PARAM_PROGRESS -ge 90 ]; then echo -ne "[##########################] (100%) $PARAM_PHASE \r" ; delay; fi;
    if [ $CURRENT_PROGRESS -le 100 -a $PARAM_PROGRESS -ge 100 ];then echo -ne 'Setup finished. Here are your details: \n' ; delay; fi;

    CURRENT_PROGRESS=$PARAM_PROGRESS;

}

progress 10 "Initializing.."
sleep 1
progress 20 "Creating new cloud server.."

docker_create > /dev/null 2>&1

progress 50 "Cloud server successfully created.."

privateIP=$(docker run -it \
	-e HCLOUD_TOKEN=$token \
	--rm askoproducts/hcloud \
	hcloud server describe $serverName.$domain -o json | jq -r '.private_net[].ip')

publicIP=$(docker run -it \
        -e HCLOUD_TOKEN=$token \
        --rm askoproducts/hcloud \
        hcloud server describe $serverName.$domain -o json | jq -r '.public_net.ipv4.ip')

# New DNS entry

if [ "$DNS" == "yes" ]
then

progress 70 "Adding DNS records for instance.."

ssh root@inf1.extis.net > /dev/null 2>&1 << EOF
sed -i "/\;RECORDS/a d.$serverName A $privateIP" /containers/services/dns/zones/claxss.cloud.zone
sed -i "/\;RECORDS/a $serverName A $publicIP" /containers/services/dns/zones/claxss.cloud.zone
/containers/services/dns/reload.sh > /dev/null 2>&1

EOF

fi

progress 100 "Setup finished! Here are your server details:"
echo "Internal: $privateIP"
echo "Server: $serverName.$domain ($publicIP)"
echo "Docker Daemon: d.$serverName.$domain ($privateIP)"

