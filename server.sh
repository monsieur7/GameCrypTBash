#!/bin/bash
new="0"
auth="0"
#INVENTAIRE # variables globales non utilisés
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
if [ $# != 3 ] # si host + ports précisés, on les prends
then
	host="localhost"
	port_in="1301"
	port_out="1302"
else # sinon on prends les ports par défauts
	host=$1
	port_out=$2
	port_in=$3

fi
echo $host $port_in $port_out # DEBUG
# loading mdp + id
if [ ! -s player.txt ] # si le fichier du joueur n'est pas crée on le crée
then
	touch player.txt
	echo "type:1 mdp:0 id:0 nom:0 argent:0 level:0 xp:0 health:10 health_boss:20" >player.txt
	echo "creating default player file"
fi
cat player.txt # DEBUG 
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



nc -l -k $port_in >output 2>>log_server.txt & # launch listening daemon
if [ ! -s dhb2.pem ] # OPENSSL si les paramètres ne sont pas générés on les génère (car les paramètres prennent du temps a être generé (nombres premiers ...))
then 
	openssl genpkey -genparam -algorithm DH -out dhb2.pem #genparam Diffie-Hellman
fi
openssl genpkey -paramfile dhb2.pem -out dhkey2.pem #private key
openssl pkey -in dhkey2.pem -pubout -out dhpub2.pem #public key
#sleep 2

nc -z $host $port_out
while [ $? != 0 ] # on attends que le client se connecte (do while)
do
	echo "" >/dev/null
	nc -z $host $port_out
done
echo "ready to send : a client is listening"  
echo "sending parameters" 
cat dhb2.pem # debug
cat dhb2.pem | netcat -w 1 $host $port_out # on envoir les paramètres
sleep 2	

echo "listening for public key"
#nc -l -p 1301 > /tmp/output
while [ ! -s output ]  
# on attends la clé publique
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
cat dhpub2.pem | nc -w 1 $host $port_out # on envoye la clé publique	

openssl pkeyutl -derive -inkey dhkey2.pem -peerkey <(cat output | tr -d "\000") -out alice_shared_secret.bin # generating secret, le tr est pour enlever le binaire du fichier, openssl n'aime pas le binaire
base64 alice_shared_secret.bin # DEBUG
#echo "" > output #erase buffer

echo "secret"
base64 alice_shared_secret.bin #debug

#secure exchange begin here
#sleep 5
send() { # envoyer qq chose en paramètre $1
echo "$1" | openssl enc -aes256 -base64 -kfile bob_shared_secret.bin -e 2>/dev/null | nc -w 1 $host $port_out
}
quit(){ # quitter
rm -rf output
	#./clean.sh
	echo $!
	echo "pid to kill " $!
	pkill "$!"
	pkill -f "nc -l -k $port_in" # killing daemons
	pkill -f "nc -l -k $port_out" # killing daemons
	#echo "type:$type mdp:$mdp id:$id nom:$nom argent:$argent level:$level xp:$xp health:$health health_boss:$health_boss" >player.txt # mettre nomduchamp:champ
	echo " player.txt : " && cat player.txt # DEBUG
	#echo $argent $level $xp $health
	exit
}
init_dungeon(){ # init donjon
echo "init donjon"
level_dungeon=$(read_var level) # lire la variable lever dans le fichier player.txt
echo $level_dungeon
if [ "$level_dungeon" == "1" ] # level 1
then
	modif health_boss 10
	echo "level 1" # debug 
	return
elif [ "$level_dungeon" == "2" ] # level 2
then

	modif health_boss 15
	echo "level 2"
	return
elif [ "$level_dungeon" == "3" ]  # level 3
then
	echo "level 3"
	modif health_boss 20
	return
fi
}

dungeon(){ # message du donjon quand on entre
level_dungeon=$(read_var level)
#echo $level_dungeon
if [ "$level_dungeon" == "1" ]
then
	send "Attention ! Un dragon arrive !"
#	health_boss="10"
elif [ "$level_dungeon" == "2" ]
then
	send "Attention ! Un gros Dragon arrive !"
#	health_boss="15"
elif [ "$level_dungeon" == "3" ]
then
	send "Attention ! un très gros Dragon arrive !"
#	health_boss="20"
fi
}

modif(){ # écrire la variable en argument 1 avec la valeur en argument 2
#echo "$1" "value:$2"
# modif variable in file
if echo "$1" | grep -q "^health$" # si variable est health
then
	#echo "in health"
	# modif
	sed -i  "s/health:$(read_var health)/health:$2/g" player.txt # modifie la varaible sous le format nom:valeur  
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

read_var(){ # lis la variable en argument 1 et retourne (echo) la valeur
#read var in file

if [ $1 == health ] # si la variable est la vie
then
	cat player.txt | cut -d " " -f 8 | cut -d ":" -f 2 # lie la variable sous le format nom_variable:valeur

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


health_calc() { # calcule la vie du personage / boss
msg=""
health_calc=$(read_var health)
health_boss_calc=$(read_var health_boss)
echo "before :boss" $health_boss_calc "player" $health_calc
# calcule HEALTH
if [ "$(read_var type)" == "1" ] # guerrier
then
	health_boss_calc="$(echo $health_boss_calc - 1 | bc)"
	msg+="vous avez infligez 1 de degats au dragon "
	# DRAGON - 1 # 1 de dégats 1 fois sur 4
	#HEALTH - 1 3 fois sur 4 # 3 foissur 4 on prends 1 de dégats sinon rien
	if [ "$[RANDOM % 4]" == "3" ]
	then
		 msg+="vous n'avez pas pris de degats "
	else
		msg+="vous avez pris 1 de degats "
		health_calc="$(echo $health_calc - 1 | bc)"
	fi
elif [ "$(read_var type)" == "2" ] # MAGE
then
	if [ "$[RANDOM % 2]" == "1" ] # 3 de dégats une fois sur 2 sinon 2
	then
		msg+="vous avez infliger 3 de degats au dragon "
		health_boss_calc="$(echo $health_boss_calc - 3 | bc)"
	else
		msg+="vous avez infligez 2 de degats au dragon "
		health_boss_calc="$(echo $health_boss_calc - 2 | bc)"
	fi
	if [ "$[RANDOM % 4]" == "3" ] # pas de dégats pris 1 fois sur 4 sinon 2 de dégats
	then 
		 msg+="vous n'avez pas pris de degats "
	else
		msg+="vous avez prix 2 de degats "
		health_calc="$(echo $health_calc - 2 | bc)"
	fi
	#DRAGON - 2 1 fois sur 2 sinon -1
	#HEALTH - 2
else # ASSASSIN
	health_boss_calc="$(echo $health_boss_calc - 3 | bc)"
	msg+="vous avez infligez trois de degats au dragon "
	#DRAGON - 3 " 3 de dégats au dragon
	if [ "$[RANDOM % 4]" == "3" ] # pas de dégats 1 fois sur 4 sinon 2 de dégats
	then
		 msg+="vous n'avez pas pris de degats"
	else
		msg+="vous avez pris 2 de degats"
		health_calc="$(echo $health_calc - 2 | bc)"
	fi
	#HEALTH - 2
fi

if [ $health_calc -le 0 ] # si le personnage est mort, on reset et on quitte
then
	msg+="vous avez perdu : le jeu est fini"
	health_calc=10
	echo "finished" $health_calc
	modif level 1
	init_dungeon #reset donjon
	echo "boss" $health_boss_calc "player" $health_calc # debug
	modif "health" $health_calc #reset vie du perso
	#modif "health_boss" $health_boss_calc
	echo "$msg"
	send "$msg"
	return
elif [ $health_boss_calc -le 0 ] # si le dragon / boss est mort
then 
	msg+="le dragon est mort : vous gagnez un niveau"
	temp=$(read_var level)
	echo "level bfore $temp"
	if [ "$(read_var level)" == "3" ] # le jeu est fini 
	then
		echo "level = 1"
		msg+="le jeu est fini vous avez gagne"
		health_calc=10 # RESET
		modif level 1
		modif xp 0
		init_dungeon

		
	else 
		echo "level + 1" # on gagne un level 
		temp=$(echo "$temp + 1" | bc)
		echo "level after $temp"
		modif level $temp
		init_dungeon
	fi
	health_calc=10 #reset vie
	echo "boss after dead " $health_boss_calc "player" $health_calc
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
process() { # fonction process des commandes new, auth, attaque, donjon
echo "$1"
if echo "$1" | grep -q -E "^new" # crée un perso
then
	#echo "$(echo $1 | cut -d " " -f 2)"
	modif "nom" "$(echo $1 | cut -d " " -f 2)" # nom
	#echo "$(echo $1 | cut -d " " -f 3)"
	modif "type" "$(echo $1 | cut -d " " -f 3)" # type de perso 1 guerrier 2 mage 3 assassin
	#echo "$(echo $1 | cut -d " " -f 4)"
	modif "id" "$(echo $1 | cut -d " " -f 4)" # ID = nom (mais pour le serveur l'ID et le nom sont séparés, le client choisie un id qui est le même que le nom
	#echo "$(echo $1 | cut -d " " -f 5)"
	modif "mdp" "$(echo $1 | cut -d " " -f 5)" # mot de passe
	#argent=0
	modif "argent" "0" # argent pas implémentée
	#level=1
	modif "level" 1 # level de 1 à 3
	#xp=0
	modif "xp" 0  # pas implémentée
	#health_boss = 120
	modif health_boss 10 # vie de base du boss
	#health = 10
	modif health 10 # vie du perso
	echo "player.txt file new"
	cat player.txt
elif  echo "$1" | grep -q -E "^inv" # PAS IMPLEMENTEE
then
	if [ "$(echo "$1" | cut -d " " -f 2)"  == "print" ] 
	then
		#print inv
		send "inv : !" #TODO
	fi
elif  echo "$1" |  grep -q -E "^auth" # authentification
then
	echo "id $(read_var id)" $(echo $1 | cut -d " " -f 2) # lis l'ID du fichier player.txt
	echo "mdp $(read_var mdp)" $(echo $1 | cut -d " " -f 3) # lis l mot de passe du fichier player.txt
	if [ $(echo $1 | cut -d " " -f 2) == $(read_var id) ] && [ $(echo $1 | cut -d " " -f 3) == $(read_var mdp) ] # si l'id et le mdp sont bons
	then
		send "0"
		echo "bonjour $(read_var nom)"
		auth=1
	else  # sinon authentification est faux
		echo "authentification has failed"
		send "1"
	fi
elif echo "$1" |  grep -q -E "^donjon" # appelle donjon
then
	dungeon "$(read_var level)"

elif echo "$1" |  grep -q -E "^attaque" # commande attaque
then
	echo "attaque"
	if [ "$(read_var type)" == "1" ] # type guerrier
	then
		health_calc 1
	elif [ "(read_var type)" == "2" ] # type mage
	then
		health_calc 2
	else # type assassin
		health_calc 3
	fi
elif echo $1 | grep -q -E "^stat" # stat du perso
then
	send "vie:$(read_var health) boss:$(read_var health_boss) level:$(read_var level) xp:$(read_var xp) argent:$(read_var argent)" # envoie les stats du perso
fi
}
echo $1
echo "" >output
echo "beginning receiving"
while true
do # do while en attendant de recevoir qq chose du démon de réception 
	cat output | tr -d '\000'| grep -q -E '[0-9A-Za-z+/\\=]+' # grep base 64, teste si il y a qq chose d'intéréssant dnas le fichier en enlevant le binaire dans le fichier pour le do while
	while (( $? > 0 )) # teste le résultat de la commande
	do	
	#printf "."
		sleep 1
		cat output | tr -d '\000' | grep -q -E '^[0-9A-Za-z+/\\=]+' # grep base 64, teste si il y a qq chose d'intéréssant dnas le fichier en enlevant le binaire dans le fichier
	done
	printf "we have received\n"
	# RECEIVE LOOP 
	result=$(cat output |tr -d '\000' | grep -E '^[0-9A-Za-z+/\\=]+' | openssl enc -aes256 -base64 -kfile alice_shared_secret.bin -d 2>/dev/null ) # on a recu qq chose, on le décrypte  tr -d '\000' pour enlever le binaire, openssl n'aime pas le binaire (il est en mode base64)
	if echo "$result" | tr -d " " | grep "^q$" # on quitte
	then
		rm -rf output
		#./clean.sh
		echo $!
		echo "pid to kill " $!
		pkill "$!"
		pkill -f "nc -l -k $port_in" # tue les démons du client (a	u cas ou )+ serveur 
		pkill -f "nc -l -k $port_out"
		#echo "type:$type mdp:$mdp id:$id nom:$nom argent:$argent level:$level xp:$xp health:$health health_boss:$health_boss" >player.txt # mettre nomduchamp:champ
		echo " player.txt : " && cat player.txt
		#echo $argent $level $xp $health
		exit
	elif echo "$result" | tr -d " " | grep "^clear$" # clear pour clear (DEBUG)
	then
		clear
	else
		process "$result" # on process les autres commandes
	fi
	echo "" >output # on vide le fichier d'écoute (supprimer le fichier peut faire crasher le démon dans certains cas)
done





