#!/bin/bash
new="0"
auth="0"
#INVENTAIRE
type=""
mdp=""
id=""
nom=""
argent=0
level=1
xp=0
health_boss=0
health=10
msg=""
if (($# != 3)) 
then
	host="localhost"
	port_in="1301"
	port_out="1302"
else
	host=$1
	port_out=$2
	port_in=$3

fi
# loading mdp + id
if [ ! -s player.txt ]
then
touch player.txt
fi
#	echo "player.txt exist"
#	type="$(cat player.txt | cut -d " " -f 1)"
#	mdp="$(cat player.txt | cut -d " " -f 2)"
#	id="$(cat player.txt | cut -d " " -f 3)"
#	nom="$(cat player.txt | cut -d " " -f 4)"
#	argent="$(cat player.txt | cut -d " " -f 5)"
#	level="$(cat player.txt | cut -d " " -f 6)"
#	xp="$(cat player.txt | cut -d " " -f 7)"
#	health="$(cat player.txt | cut -d " " -f 8)"
#	cat player.txt
#else 
#	touch player.txt
#0	echo "creating file"
fi



nc -l -k $port_in >output 2>>log_server.txt & # launch daemon
if [ ! -s dhb2.pem ] # OPENSSL
then 
	openssl genpkey -genparam -algorithm DH -out dhb2.pem #genparam
fi
openssl genpkey -paramfile dhb2.pem -out dhkey2.pem #private key
openssl pkey -in dhkey2.pem -pubout -out dhpub2.pem #public key
#sleep 2

nc -z $host $port_out
while (( $? != 0 )) 
do
	echo "" >/dev/null
	nc -z $host $port_out
done
echo "ready to send : a client is listening"  
echo "sending parameters"
cat dhb2.pem
cat dhb2.pem | netcat -w 1 $host $port_out
sleep 2	

echo "listening for public key"
#nc -l -p 1301 > /tmp/output
while [ ! -s output ] 
do
 	# debug
	sleep 1
done
echo "received public key"
#sleep 2
cat output
echo "sending public key"
cat  dhpub2.pem
#sleep 2
cat dhpub2.pem | nc -w 1 $host $port_out

openssl pkeyutl -derive -inkey dhkey2.pem -peerkey <(cat output | tr -d "\000") -out alice_shared_secret.bin
base64 alice_shared_secret.bin
#echo "" > output #erase buffer

echo "secret"
base64 alice_shared_secret.bin #debug

#secure exchange begin here
#sleep 5
send() {
echo "$1" | openssl enc -aes256 -base64 -kfile bob_shared_secret.bin -e 2>/dev/null | nc -w 1 $host $port_out
}
dungeon(){
level_dungeon=$1
#echo $level_dungeon
if (( "$level_dungeon" == "1" ))
then
	send "Attention ! Un dragon arrive !"
	health_boss="10"
elif (( "$level_dungeon" == "2" ))
then
	send "Attention ! Un gros Dragon arrive !"
	health_boss="15"
elif (( "$level_dungeon" == "3" ))
then
	send "Attention ! un très gros Dragon arrive !"
	health_boss="20"
fi
}

modif() {
# modif variable in file
if (( $1 == "health" ))
then
	# modif
	sed -i "s/health:$(read_var health)/health:$2/g" player.txt

fi
}

read_var() {
#read var in file
if (( $1 == "health" ))
then
	cat player.txt | cut -d " " -f 8 | cut -d ":" -f 2
fi


}
health_calc() {
msg=""
health_calc=$1
health_boss_calc=$2
# calcule HEALTH
if (( "$1" == "1" ))
then
	health_boss="$(echo $health_boss - 1 | bc)"
	msg+="vous avez infligez 1 de dégats au dragon"
	# DRAGON - 1
	#HEALTH - 1 3 fois sur 4
	if (( "$((RANDOM % 4))" == "3" ))
	then
		 msg+="vous n'avez pas pris de dégats"
	else
		msg+="vous avez prix 1 de dégats"
		$health_calc="$(echo $health_calc - 1 | bc)"
	fi
elif (( "$1" == "2" ))
then
	if (( "$((RANDOM % 2))" == "1" ))
	then
		msg+="vous avez infliger 2 de dégats au dragon"
	else
		msg+="vous avez pris 1 de dégats"
		$health_calc="$(echo $health_calc - 1 | bc)"
	fi
	if (( "$((RANDOM % 4))" == "3" ))
	then
		 msg+="vous n'avez pas pris de dégats"
	else
		msg+="vous avez prix 2 de dégats"
		$health_calc="$(echo $health_calc - 2 | bc)"
	fi
	#DRAGON - 2 1 fois sur 2 sinon -1
	#HEALTH - 2
else 
	health_boss_calc="$(echo $health_boss_calc - 3 | bc)"
	msg+="vous avez infliez trois de dégats au dragon"
	#DRAGON - 3
	if (( "$((RANDOM % 4))" == "3" ))
	then
		 msg+="vous n'avez pas pris de dégats"
	else
		msg+="vous avez prix 2 de dégats"
		$health_calc="$(echo $health_calc - 2 | bc)"
	fi
	#HEALTH - 2
fi	
send $msg
modif "health" $health
modif "health_boss" $health
}
process() {
echo "$1"
if echo "$1" | grep -q -E "^new" 
then
	nom="$(echo $1 | cut -d " " -f 2)"
	type="$(echo $1 | cut -d " " -f 3)"
	id="$(echo $1 | cut -d " " -f 4)"
	mdp="$(echo $1 | cut -d " " -f 5)"
	argent=0
	level=1
	xp=0
	echo "$type $mdp $id $nom $argent $level $xp $health"
elif  echo "$1" | grep -q -E "^inv" 
then
	if (( "$(echo "$1" | cut -d " " -f 2)"  == "print" )) 
	then
		#print inv
		send "inv : !" #TODO
	fi
elif  echo "$1" |  grep -q -E "^auth" 
then
	if (( "$(echo "$1" | cut -d " " -f 2)" == "$id" ))  && (( "$(echo "$1" | cut -d " " -f 3)" == "$mdp" ))
	then
		send "0"
		echo "bonjour $nom"
		auth=1
	else 
		echo "authentification has failed"
		send "1"
	fi
elif echo "$1" |  grep -q -E "^donjon"
then
	echo "$2"
	dungeon $2

elif echo "$1" |  grep -q -E "^attack"
then
	if (( "$type" == "1" ))
	then
		health_calc 1
	elif (( "$type" == "2" ))
	then
		health_calc 2
	else
		health_calc 3
	fi
fi
}
echo $1
echo "" >output
echo "beginning receiving"
while true
do
	cat output | tr -d '\000'| grep -q -E '[A-Za-z+/\\=]+'
	while (( $? > 0))
	do	
	#printf "."
		sleep 1
		cat output | tr -d '\000' | grep -q -E '^[A-Za-z+/\\=]+'
	done
	printf "we have received\n"
	# RECEIVE LOOP 
	result=$(cat output |tr -d '\000' | grep -E '^[A-Za-z+/\\=]+' | openssl enc -aes256 -base64 -kfile alice_shared_secret.bin -d 2>/dev/null )
	if echo "$result" | tr -d " " | grep "^q$" 
	then
		rm -rf output
		#./clean.sh
		echo $!
		echo "pid to kill " $!
		pkill "$!"
		pkill -f "nc -l -k $port_in"
		pkill -f "nc -l -k $port_out"
		echo "type:$type mdp:$mdp id:$id nom:$nom argent:$argent level:$level xp:$xp health:$health health_boss:$health_boss" >player.txt # mettre nomduchamp:champ
		echo " player.txt : " && cat player.txt
		echo $argent $level $xp $health
		exit
	elif echo "$result" | tr -d " " | grep "^clear$"
	then
		clear
	else
		process "$result" $level
	fi
	echo "" >output
done
#NPC




