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
if [ $# != 3 ] 
then
	host="localhost"
	port_in="1301"
	port_out="1302"
else
	host=$1
	port_out=$2
	port_in=$3

fi
echo $host $port_in $port_out
# loading mdp + id
if [ ! -s player.txt ]
then
	touch player.txt
	echo "type:1 mdp:0 id:0 nom:0 argent:0 level:0 xp:0 health:10 health_boss:20" >player.txt
	echo "creating default player file"
fi
cat player.txt
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
#fi



nc -l -k $port_in >output 2>>log_server.txt & # launch daemon
if [ ! -s dhb2.pem ] # OPENSSL
then 
	openssl genpkey -genparam -algorithm DH -out dhb2.pem #genparam
fi
openssl genpkey -paramfile dhb2.pem -out dhkey2.pem #private key
openssl pkey -in dhkey2.pem -pubout -out dhpub2.pem #public key
#sleep 2

nc -z $host $port_out
while [ $? != 0 ] 
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
quit(){
rm -rf output
	#./clean.sh
	echo $!
	echo "pid to kill " $!
	pkill "$!"
	pkill -f "nc -l -k $port_in"
	pkill -f "nc -l -k $port_out"
	#echo "type:$type mdp:$mdp id:$id nom:$nom argent:$argent level:$level xp:$xp health:$health health_boss:$health_boss" >player.txt # mettre nomduchamp:champ
	echo " player.txt : " && cat player.txt
	#echo $argent $level $xp $health
	exit
}
init_dungeon(){
echo "init donjon"
level_dungeon=$(read_var level)
echo $level_dungeon
if [ "$level_dungeon" == "1" ]
then
	modif health_boss 10
	echo "level 1"
	return
elif [ "$level_dungeon" == "2" ]
then

	modif health_boss 15
	echo "level 2"
	return
elif [ "$level_dungeon" == "3" ]
then
	echo "level 3"
	modif health_boss 20
	return
fi
}

dungeon(){
level_dungeon=$(read_var level)
#echo $level_dungeon
if [ "$level_dungeon" == "1" ]
then
	send "Attention ! Un dragon arrive !"
	health_boss="10"
elif [ "$level_dungeon" == "2" ]
then
	send "Attention ! Un gros Dragon arrive !"
	health_boss="15"
elif [ "$level_dungeon" == "3" ]
then
	send "Attention ! un très gros Dragon arrive !"
	health_boss="20"
fi
}

modif(){
#echo "$1" "value:$2"
# modif variable in file
if echo "$1" | grep -q "^health$"
then
	#echo "in health"
	# modif
	sed -i  "s/health:$(read_var health)/health:$2/g" player.txt
elif echo "$1" | grep -q "health_boss"
then	
	#echo "in health boss"
	# modif
	sed -i  "s/health_boss:$(read_var health_boss)/health_boss:$2/g" player.txt
elif echo "$1" | grep -q "xp"
then
	# modif
	sed -i  "s/xp:$(read_var xp)/xp:$2/g" player.txt
elif echo "$1" | grep -q "level"
then
	# modif
	sed -i  "s/level:$(read_var level)/level:$2/g" player.txt
elif echo "$1" | grep -q "argent"
then
	#echo "$(read_var argent)"	# modif
	sed -i "s/argent:$(read_var argent)/argent:$2/g" player.txt

elif echo "$1" | grep -q "id"
then
	# modif
	sed -i   "s/id:$(read_var id)/id:$2/g" player.txt
elif echo "$1" | grep -q "nom"
then
	# modif
	sed -i   "s/nom:$(read_var nom)/nom:$2/g" player.txt
elif echo "$1" | grep -q "mdp"
then
	# modif
	sed -i   "s/mdp:$(read_var mdp)/mdp:$2/g" player.txt
elif echo "$1" | grep -q "type"
then
	# modif
	sed -i   "s/type:$(read_var type)/type:$2/g" player.txt
else echo "problem"
fi

}

read_var(){
#read var in file

if [ $1 == health ]
then
	cat player.txt | cut -d " " -f 8 | cut -d ":" -f 2

elif [ "$1" == "health_boss" ]
then
	cat player.txt | cut -d " " -f 9 | cut -d ":" -f 2

elif [ "$1" == "mdp" ]
then
	cat player.txt | cut -d " " -f 2 | cut -d ":" -f 2

elif [ "$1" == "id" ]
then
	cat player.txt | cut -d " " -f 3 | cut -d ":" -f 2

elif [ "$1" == "type" ]
then
	cat player.txt | cut -d " " -f 1 | cut -d ":" -f 2

elif [ "$1" == "nom" ]
then
	cat player.txt | cut -d " " -f 4 | cut -d ":" -f 2

elif [ "$1" == "argent" ]
then
	cat player.txt | cut -d " " -f 5 | cut -d ":" -f 2

elif [ "$1" == "level" ]
then
	cat player.txt | cut -d " " -f 6 | cut -d ":" -f 2

elif [ "$1" == "xp" ]
then
	cat player.txt | cut -d " " -f 7 | cut -d ":" -f 2
fi

}


health_calc() {
msg=""
health_calc=$(read_var health)
health_boss_calc=$(read_var health)
echo "before :boss" $health_boss_calc "player" $health_calc
# calcule HEALTH
if [ "$(read_var type)" == "1" ]
then
	health_boss_calc="$(echo $health_boss_calc - 1 | bc)"
	msg+="vous avez infligez 1 de degats au dragon "
	# DRAGON - 1
	#HEALTH - 1 3 fois sur 4
	if [ "$[RANDOM % 4]" == "3" ]
	then
		 msg+="vous n'avez pas pris de degats "
	else
		msg+="vous avez prix 1 de degats "
		health_calc="$(echo $health_calc - 1 | bc)"
	fi
elif [ "$(read_var type)" == "2" ]
then
	if [ "$[RANDOM % 2]" == "1" ]
	then
		msg+="vous avez infliger 3 de degats au dragon "
		health_boss_calc="$(echo $health_boss_calc - 3 | bc)"
	else
		msg+="vous avez infligez 2 de degats au dragon "
		health_boss_calc="$(echo $health_boss_calc - 2 | bc)"
	fi
	if [ "$[RANDOM % 4]" == "3" ]
	then
		 msg+="vous n'avez pas pris de degats "
	else
		msg+="vous avez prix 2 de degats "
		health_calc="$(echo $health_calc - 2 | bc)"
	fi
	#DRAGON - 2 1 fois sur 2 sinon -1
	#HEALTH - 2
else 
	health_boss_calc="$(echo $health_boss_calc - 3 | bc)"
	msg+="vous avez infligez trois de degats au dragon "
	#DRAGON - 3
	if [ "$[RANDOM % 4]" == "3" ]
	then
		 msg+="vous n'avez pas pris de degats"
	else
		msg+="vous avez prix 2 de degats"
		health_calc="$(echo $health_calc - 2 | bc)"
	fi
	#HEALTH - 2
fi

if [ $health_calc -le 0 ]
then
	msg+="vous avez perdu : le jeu est fini"
	health_calc=10
	echo "finished" $health_calc
	modif level 1
	init_dungeon
	echo "boss" $health_boss_calc "player" $health_calc
	modif "health" $health_calc
	#modif "health_boss" $health_boss_calc
	echo "$msg"
	send "$msg"
	return
elif [ $health_boss_calc -le 0 ]
then 
	msg+="le dragon est mort : vous gagnez un niveau"
	temp=$(read_var level)
	echo "level bfore $temp"
	if [ "$(read_var level)" == "3" ]
	then
		echo "level = 1"
		msg+="le jeu est fini vous avez gagner"
		health_calc=10
		modif level 1
		modif xp 0
		init_dungeon

		
	else 
		echo "level + 1"
		temp=$(echo "$temp + 1" | bc)
		echo "level after $temp"
		modif level $temp
		init_dungeon
	fi
	health_calc=10
	echo "boss" $health_boss_calc "player" $health_calc
	modif "health" $health_calc
	#modif "health_boss" $health_boss_calc
	echo "$msg"
	send "$msg"
	return
fi
echo "boss" $health_boss_calc "player" $health_calc
modif "health" $health_calc
modif "health_boss" $health_boss_calc
echo "$msg"
send "$msg"
}
process() {
echo "$1"
if echo "$1" | grep -q -E "^new" 
then
	#echo "$(echo $1 | cut -d " " -f 2)"
	modif "nom" "$(echo $1 | cut -d " " -f 2)"
	#echo "$(echo $1 | cut -d " " -f 3)"
	modif "type" "$(echo $1 | cut -d " " -f 3)"
	#echo "$(echo $1 | cut -d " " -f 4)"
	modif "id" "$(echo $1 | cut -d " " -f 4)"
	#echo "$(echo $1 | cut -d " " -f 5)"
	modif "mdp" "$(echo $1 | cut -d " " -f 5)"
	#argent=0
	modif "argent" "0"
	#level=1
	modif "level" 1
	#xp=0
	modif "xp" 0 
	#health_boss = 120
	modif health_boss 10
	#health = 10
	modif health 10
	echo "player.txt file new"
	cat player.txt
elif  echo "$1" | grep -q -E "^inv" 
then
	if [ "$(echo "$1" | cut -d " " -f 2)"  == "print" ] 
	then
		#print inv
		send "inv : !" #TODO
	fi
elif  echo "$1" |  grep -q -E "^auth" 
then
	echo "id $(read_var id)" $(echo $1 | cut -d " " -f 2) 
	echo "mdp $(read_var mdp)" $(echo $1 | cut -d " " -f 3)
	if [ $(echo $1 | cut -d " " -f 2) == $(read_var id) ] && [ $(echo $1 | cut -d " " -f 3) == $(read_var mdp) ]
	then
		send "0"
		echo "bonjour $(read_var nom)"
		auth=1
	else 
		echo "authentification has failed"
		send "1"
	fi
elif echo "$1" |  grep -q -E "^donjon"
then
	dungeon "$(read_var level)"

elif echo "$1" |  grep -q -E "^attaque"
then
	echo "attque"
	if [ "$(read_var type)" == "1" ]
	then
		health_calc 1
	elif [ "(read_var type)" == "2" ]
	then
		health_calc 2
	else
		health_calc 3
	fi
elif echo $1 | grep -q -E "^stat"
then
	send "vie:$(read_var health) boss:$(read_var health_boss) level:$(read_var level) xp:$(read_var xp) argent:$(read_var argent)"
fi
}
echo $1
echo "" >output
echo "beginning receiving"
while true
do
	cat output | tr -d '\000'| grep -q -E '[A-Za-z+/\\=]+'
	while (( $? > 0 ))
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
		#echo "type:$type mdp:$mdp id:$id nom:$nom argent:$argent level:$level xp:$xp health:$health health_boss:$health_boss" >player.txt # mettre nomduchamp:champ
		echo " player.txt : " && cat player.txt
		#echo $argent $level $xp $health
		exit
	elif echo "$result" | tr -d " " | grep "^clear$"
	then
		clear
	else
		process "$result"
	fi
	echo "" >output
done
#NPC




