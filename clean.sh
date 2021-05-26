# script de clean 
pkill -f "nc -l -k 1301" && pkill -f "nc -l -k 1302" && rm -rf /tmp/output* && rm -rf outputclient
