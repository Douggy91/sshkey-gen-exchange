#!/bin/bash

#echo "press your Ip"
#read my_ip
apt-get install -y net-tools expect
hostnamectl set-hostname RKE-CONS0

echo "please write bastion ip"
read my_ip

controlArr=()
i=0
answer_con=n

echo "add Control Plane?(y/n)"
read addmore

if [ "$addmore" == "y" ]; then
	while [ "$answer_con" == "n" ]
	do
		echo "press control_ip"
		read control_ip
		controlArr[$i]=$control_ip
		echo "is done? [y/n]"
		read answer_con
		let "i+=1"
	done
fi
workerArr=()
i=0
answer=n

while [ "$answer" == "n" ]
do
	echo "press worker_ip"
	read worker_ip
	workerArr[$i]=$worker_ip
	echo "is done? [y/n]"
	read answer
	let "i+=1"
done

allArr=(${controlArr[@]} ${workerArr[@]}) 

#ssh certification
echo -e "press password\nplease before starting this script,set all node password same password"
read password

echo "use LB?"
read use_LB

if [ "$use_LB" == "y" ]; then
  echo "press LB_ip"
	read LB_ip
	cp /etc/hosts hosts
	echo "$my_ip  RKE-CONS0" >> hosts
	for (( i=0; i<${#controlArr[@]};i++)); do
		v=$i
		let "v+=1"
		echo "${controlArr[$i]}  RKE-CONS$v" >> hosts
	done
	expect <<EOF
	spawn scp hosts $LB_ip:/etc/hosts
	expect "connecting"
	send "yes\r"
	expect "password"
	send "${password}\r"
	expect eof
EOF
else
  $LB_ip=$my_ip
fi

echo " 
apt-get install -y expect
expect <<EOF
spawn ssh-keygen -t rsa
set timeout 3
expect \"save the key\"
send \"\\r\"
expect \"passphrase\"
send \"\\r\"
expect \"same passphrase\"
send \"\\r\"
spawn ssh-keygen -t dsa
expect \"save the key\"
send \"\\r\"
expect \"passphrase\"
send \"\\r\"
expect \"same passphrase\"
send \"\\r\"
expect eof
EOF
cat /root/.ssh/*.pub > /root/.ssh/authorized_pub
"> ssh_generate_server.sh

source ssh_generate_server.sh

if [ "$addmore" == "y" ]; then
	for (( i=0; i<${#controlArr[@]};i++)); do
		v=$i
		let "v+=1"
		echo "
		apt-get install expect -y
		expect <<EOF
		spawn ssh-keygen -t rsa
		set timeout 3
		expect \"save the key\"
		send \"\\r\"
		expect \"passphrase\"
		send \"\\r\"
		expect \"same passphrase\"
		send \"\\r\"
		spawn ssh-keygen -t dsa
		expect \"save the key\"
		send \"\\r\"
		expect \"passphrase\"
		send \"\\r\"
		expect \"same passphrase\"
		send \"\\r\"
		expect eof
		EOF
		cat /root/.ssh/*.pub > /root/.ssh/authorized_pub
		expect <<EOF
		spawn scp /root/.ssh/authorized_pub ${my_ip}:/root/.ssh/${controlArr[$i]}_pub
		expect \"connecting\"
		send \"yes\\r\"
		expect \"password\"
		send \"${password}\\r\"
		expect eof
EOF
		" > ssh_generate_s$v.sh

		expect <<EOF 
		spawn ssh ${controlArr[$i]} hostnamectl set-hostname RKE-CONS$v
		expect "connecting"
		send "yes\r"
		expect "password"
		send "${password}\r"

		spawn scp /root/ssh_generate_s$v.sh ${controlArr[$i]}:/root/ssh_generate_s$v.sh
		expect "password"
		send "${password}\r"

		spawn ssh ${controlArr[$i]} source /root/ssh_generate_s$v.sh
		expect "password"
		send "${password}\r"
		expect eof
EOF
	done
fi

for (( i=0; i<${#workerArr[@]};i++)); do
	v=$i
	let "v+=1"
			echo "
		apt-get install expect -y
		expect <<EOF
		spawn ssh-keygen -t rsa
		set timeout 3
		expect \"save the key\"
		send \"\\r\"
		expect \"passphrase\"
		send \"\\r\"
		expect \"same passphrase\"
		send \"\\r\"
		spawn ssh-keygen -t dsa
		expect \"save the key\"
		send \"\\r\"
		expect \"passphrase\"
		send \"\\r\"
		expect \"same passphrase\"
		send \"\\r\"
		expect eof
		EOF
		cat /root/.ssh/*.pub > /root/.ssh/authorized_pub
		expect <<EOF
		spawn scp /root/.ssh/authorized_pub ${my_ip}:/root/.ssh/${workerArr[$i]}_pub
		expect \"connecting\"
		send \"yes\\r\"
		expect \"password\"
		send \"${password}\\r\"
		expect eof
EOF
		" > ssh_generate_a$v.sh
	expect <<EOF 
	spawn ssh ${workerArr[$i]} hostnamectl set-hostname RKE-WORKER$v
	expect "connecting"
	send "yes\r"
	expect "password"
	send "${password}\r"

	spawn scp /root/ssh_generate_a$v.sh ${workerArr[$i]}:/root/ssh_generate_a$v.sh
	expect "password"
	send "${password}\r"

	spawn ssh ${workerArr[$i]} source /root/ssh_generate_a$v.sh
	expect "password"
	send "${password}\r"
	expect eof
EOF
done

cat /root/.ssh/*_pub > /root/.ssh/authorized_keys

for (( i=0; i<${#allArr[@]};i++)); do
        v=$i
        let "v+=1"
        expect <<EOF
	spawn scp /root/.ssh/authorized_keys ${allArr[$i]}:/root/.ssh/authorized_keys
	expect "password"
	send "${password}\r"
	expect eof
EOF
done


