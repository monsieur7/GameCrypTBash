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
nc -l -k -p $port_in >/tmp/output 2>/dev/null & # launch daemon
if [ ! -s dhb2.pem ] 
then 
openssl genpkey -genparam -algorithm DH -out dhb2.pem 
fi
openssl genpkey -paramfile dhb2.pem -out dhkey2.pem 
openssl pkey -in dhkey2.pem -pubout -out dhpub2.pem 
sleep 2
echo "sending parameters"
cat dhb2.pem
cat dhb2.pem | netcat -q 1 $host $port_out
sleep 2

echo "listening for public key"
#nc -l -p 1301 > /tmp/output
while [ ! -s /tmp/output ] 
do
 # debug
sleep 1
done
echo "received public key"
sleep 2
cat /tmp/output
echo "sending public key"
cat  dhpub2.pem
sleep 2
cat dhpub2.pem | nc -q 1 $host $port_out

openssl pkeyutl -derive -inkey dhkey2.pem -peerkey <(cat /tmp/output) -out alice_shared_secret.bin
base64 alice_shared_secret.bin
echo "" > /tmp/output #erase buffer

echo "secret"
base64 alice_shared_secret.bin #debug

#secure exchange begin here
sleep 5
send() {
echo "$1" | openssl enc -aes256 -base64 -kfile bob_shared_secret.bin -e 2>/dev/null | nc -q 1 $host $port_out
}


echo "beginning receiving"
while true
do
#echo "waiting"
cat /tmp/output | tr -d '\000'| grep -q -E '[A-Za-z/\\=]+'
while (( $? > 0))
do
#printf "."
sleep 1
cat /tmp/output | tr -d '\000' | grep -q -E '^[A-Za-z/\\=]+'
done
printf "\n"
#echo "decoding"
result=$(cat /tmp/output |tr -d '\000' | grep -E '^[A-Za-z/\\=]+' | openssl enc -aes256 -base64 -kfile alice_shared_secret.bin -d 2>/dev/null )
echo "" >/tmp/output
if echo "$result" | tr -d " " | grep "^q$" 
then
pkill "nc -l -k -p $port_in"
./clean.sh
exit
elif echo "$result" | tr -d " " | grep "^clear$"
then
clear
else
echo $result
fi
done
