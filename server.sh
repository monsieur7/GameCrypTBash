#!/bin/bash
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
nc -l -k $port_in >output 2>>log_server.txt & # launch daemon
if [ ! -s dhb2.pem ] 
then 
openssl genpkey -genparam -algorithm DH -out dhb2.pem 
fi
openssl genpkey -paramfile dhb2.pem -out dhkey2.pem 
openssl pkey -in dhkey2.pem -pubout -out dhpub2.pem 
sleep 2

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
sleep 2
cat output
echo "sending public key"
cat  dhpub2.pem
sleep 2
cat dhpub2.pem | nc -w 1 $host $port_out

openssl pkeyutl -derive -inkey dhkey2.pem -peerkey <(cat output | tr -d "\000") -out alice_shared_secret.bin
base64 alice_shared_secret.bin
#echo "" > output #erase buffer

echo "secret"
base64 alice_shared_secret.bin #debug

#secure exchange begin here
sleep 5
send() {
echo "$1" | openssl enc -aes256 -base64 -kfile bob_shared_secret.bin -e 2>/dev/null | nc -w 1 $host $port_out
}

echo "" >output
echo "beginning receiving"
while true
do
#echo "waiting"
cat output | tr -d '\000'| grep -q -E '[A-Za-z/\\=]+'
while (( $? > 0))
do
#printf "."
sleep 1
cat output | tr -d '\000' | grep -q -E '^[A-Za-z/\\=]+'
done
printf "\n"
#echo "decoding"
result=$(cat output |tr -d '\000' | grep -E '^[A-Za-z/\\=]+' | openssl enc -aes256 -base64 -kfile alice_shared_secret.bin -d 2>/dev/null )
if echo "$result" | tr -d " " | grep "^q$" 
then
rm -rf output
#./clean.sh
echo $!
echo "pid to kill " $!
pkill $!
exit
elif echo "$result" | tr -d " " | grep "^clear$"
then
clear
else
echo $result
fi
echo "" >output
done
