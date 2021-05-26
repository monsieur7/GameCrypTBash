#!/bin/bash

first_time=0

#detection de si le fichier est exécuté avec ou sans argument (hôte et port)
if (($# != 3)) 
then	
	host="localhost"
	port_in="1302"
	port_out="1301"
else
	host=$1
	port_in=$2
	port_out=$3
fi

#touch /tmp/outputclient #debug
nc -l -k $port_in >outputclient 2>>log.txt & # launch daemon

#regarde si le fichier est vide
while (( $(wc -c outputclient | cut -d " " -f 1) <= 1  ))
do
	#debug
	sleep 1
done 

echo "received parameter"

sleep 2

#openssl genpkey -genparam -algorithm  DH -out dhp.pem
openssl genpkey -paramfile outputclient -out dhkey1.pem #clef privée
openssl pkey -in dhkey1.pem -pubout -out dhpub1.pem #clef publique

echo "" > outputclient
echo "sending public key"

#sleep 2

#affiche la clef publique et l'envoie au serveur
cat  dhpub1.pem
cat dhpub1.pem | nc -N -w 1 localhost $port_out # sending 
echo "listenig for public key"

sleep 2

#echo "ready" | nc -N -q 1 $host $port
#nc -l 1301 > /tmp/outputclient
#rm -rf outputclient

#teste si la clef est reçue
while [ ! -s outputclient ] 
do
	echo "" > /dev/null
done
echo "received key" 

sleep 2

cat outputclient | tail -n +2 #debug
openssl pkeyutl -derive -inkey dhkey1.pem -peerkey <(cat outputclient | tail -n +2 | tr -d "\000") -out bob_shared_secret.bin #créer le secret; le tr sert à supprimer le binaire car openssh n'aime pas le binaire

echo "secret"
base64 bob_shared_secret.bin #debug

#echo ""> /tmp/outputclient #erase file for security
echo "" >outputclient

# secure exchange begin here
#sleep 5

#fonction qui propose à l'utilisateur de quitter et permet de quitter
quit() {
	printf "\n"
	read -r -p "quitter ? (q) : " input
	if echo $input | tr -d " " | grep -E '^q'
	then
		send "q"
		echo "pid to kill" $!
		pkill $!
                pkill -f "nc -l -k $port_in"
		pkill -f "nc -l -k $port_out"
		rm -rf outputclient
		exit
	fi

}

#fonction qui permet de quitter
force_quit() {
	printf "\n"
	send "q"
	echo "pid to kill" $!
	pkill $!
        pkill -f "nc -l -k $port_in"
	pkill -f "nc -l -k $port_out"
	rm -rf outputclient
	exit

}

# Envoie un message au serveur
# @param $1: message à envoyer
send() {
	echo "$1" | openssl enc -aes256 -base64 -kfile bob_shared_secret.bin -e 2>>aeslog.txt | nc -w 1 $host $port_out
}

# Reçoit le message
receive(){

	cat outputclient | tr -d '\000'| grep -q -E '[0-9A-Za-z/\\=]+'
	
	while (( $? > 0))
	do
		#printf "."
		#sleep 1
		cat outputclient | tr -d '\000' | grep -q -E '^[0-9A-Za-z/\\=]+'
	done
	
	#printf "\n"
	# RECEIVE LOOP
	
	echo "$(cat outputclient |tr -d '\000' | grep -E '^[0-9A-Za-z/\\=]+' | openssl enc -aes256 -base64 -kfile alice_shared_secret.bin -d 2>/dev/null)"
	echo "" > outputclient
}


authentification(){

	echo "Bonjour, bienvenue sur un super serveur jeu de rôle !"

	read -p "Etes-vous d'ores et déjà inscrit (Oui:1/Non:0)? " first_time

	#First authentification on the server
	if (( $first_time == 0 ))
	then
		read -p "Quel sera le nom de votre personnage ? " new_client_name
		read -p "Quel sera votre personnage (1 : guerrier solide, 2 : mage puissant, 3 : assassin furtif) : " new_client_perso		
		read -s -p "Entrez votre nouveau mot de passe (celui-ci ne s'affiche pas) : " new_client_mdp
		printf "\n"		
		read -s -p "Confirmez votre mot de passe (celui-ci ne s'affiche pas) : " new_client_mdp2
		printf "\n"

		while (( "$new_client_mdp2" != "$new_client_mdp" ))
		do
			read -s -p "Mot de passe incorrect, veuillez réessayer : " new_client_mdp2
			printf "\n"
		done
		
		new_client_id=$(( $RANDOM % 10 ))$(( $RANDOM % 10 ))$(( $RANDOM % 10 ))$(( $RANDOM % 10 )) #Generates the id of the new client
		send "new $new_client_name $new_client_perso $new_client_name $new_client_mdp" 
		
		#Sends authentification information to the server
		send "auth $new_client_name $new_client_mdp"
		
	#Normal Authentification on the server	
	else
		read -p "Entrez le nom de votre personnage : " client_name
		read -s -p "Entrez votre mot de passe (celui-ci ne s'affiche pas) : " client_mdp
		printf "\n"		

		#Sends authentification information to the server in order to be checked
		send "auth $client_name $client_mdp"

		#Tests the existence of the authentification information: if does not exist, return value of receive is 1
		while (( $(receive) ))
		do
			echo "Authentification échouée, veuillez réessayer."

			read -p "Entrez le nom de votre personnage : " client_name
			read -s -p "Entrez votre mot de passe (celui-ci ne s'affiche pas) : " client_mdp
			printf "\n"
		
			#Sends authentification information to the server in order to be checked
			send "auth $client_name $client_mdp"
		done

		echo "Authentification réussie !"
	fi
}	


#MAIN
IFS=""

quit

authentification

#Texte d'accueil
echo "Enchanté $client_name ! Bienvenue dans notre paisible village."
echo "Enfin paisible... Pas depuis que 3 redoutables dragons ont fait leur apparition dans la région... La population est terrifiée."
echo "Nous avons besoin de votre aide ! Vous seul(e) êtes capable de le terrasser."
echo "Dirigez-vous vers le donjon et débarassez-vous de ce maudit gradon !"
echo "*Vous vous dirrigez vers le donjon*"
echo "*Vous entrez dans le donjon et entendez un grognement sourd provenant d'un peu plus loin. Vous avancez prudemment en direction du bruit. Soudain, un dragon surgit devant vous! *"
echo "Dragon : GROAR !"
echo "*Le combat s'engage*"

while true
do
	read -p "que voulez vous faire ? q pour quitter, 0 pour attaquer 1 pour les stats de votre personnage : " input
	if echo $input | tr -d " " | grep -E '^q'
	then
		# Quitter
		send "q"
		echo "pid to kill" $!
		pkill $!
                pkill -f "nc -l -k $port_in"
		pkill -f "nc -l -k $port_out"
		rm -rf outputclient
		exit
	elif [ "$input" == "0" ]
	then
		# Combat contre le dragon 
		send "donjon"
		echo "$(receive)"
		sleep 1
		send "attaque"
		echo "$(receive)"
	elif [ "$input" == "1" ] 
	then	
		# Affiche les statistiques du personnage
		send "stat"
		echo "$(receive)"
	fi
done

