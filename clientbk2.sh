#!/bin/bash
first_time=0
mdp=""
id=""
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
#touch /tmp/outputclient
nc -l -k $port_in >outputclient 2>>log.txt & # launch daemon
while (( $(wc -c outputclient | cut -d " " -f 1) <= 1  ))
do
#debug
sleep 1
done 
echo "received parameter"
sleep 2
#openssl genpkey -genparam -algorithm  DH -out dhp.pem
openssl genpkey -paramfile outputclient -out dhkey1.pem
openssl pkey -in dhkey1.pem -pubout -out dhpub1.pem
echo "" > outputclient
echo "sending public key"
sleep 5
cat  dhpub1.pem
cat dhpub1.pem | nc -N -w 1 localhost $port_out # sending 
echo "listenig for public key"
sleep 5
#echo "ready" | nc -N -q 1 $host $port
#nc -l 1301 > /tmp/outputclient
#rm -rf outputclient
while [ ! -s outputclient ] 
do
echo "" > /dev/null
done
echo "received key" 
sleep 2
cat outputclient | tail -n +2
openssl pkeyutl -derive -inkey dhkey1.pem -peerkey <(cat outputclient | tail -n +2 | tr -d "\000") -out bob_shared_secret.bin
echo "secret"
base64 bob_shared_secret.bin #debug
#echo ""> /tmp/outputclient #erase file for security
echo "" >outputclient
# secure exchange begin here
#sleep 5
send() {
echo "$1" | openssl enc -aes256 -base64 -kfile bob_shared_secret.bin -e 2>aeslog.txt | nc -w 1 $host $port_out
}

receive(){
cat outputclient | tr -d '\000'| grep -q -E '[A-Za-z+/\\=]+'
	while (( $? > 0))
	do	
	#printf "."
		sleep 1
		cat outputclient | tr -d '\000' | grep -q -E '^[A-Za-z+/\\=]+'
	done
	#printf "we have received\n"
	# RECEIVE LOOP 
	result=$(cat outputclient |tr -d '\000' | grep -E '^[A-Za-z+/\\=]+' | openssl enc -aes256 -base64 -kfile alice_shared_secret.bin -d 2>/dev/null )
	echo result
echo "">outputclient
}


##begin(){
#echo "Bonjour, que voulez vous faire ?"
#echo "q pour quiter"
#if (( first_time == 0 ))
#then
#	echo "que voulez vous être ? "
#	echo "1 pour un elf"
#	echo "2 pour un orc"
#	echo "3 pour un humain"
#	read -r -p "choix ? :" type_game
#	if (($type_game == 0 )) then
		# GAME
#}

#MAIN
while true
do
IFS=""
#begin
read -r -p "input : " input
if echo $input | tr -d " " | grep -E '^q'
then
send "q"
echo "pid to kill" $!
pkill $!
rm -rf outputclient
exit
else
#echo "$input" # debug
send "$input"
#echo "$(receive)"
fi
done
