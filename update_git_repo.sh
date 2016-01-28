#!/usr/bin/env bash

## write expect file to interact with tty	
cat > set_passphrase.exp <<EOF
#!/usr/bin/env expect 

spawn ssh-add $HOME/.ssh/id_rsa
expect "Enter passphrase for $HOME/.ssh/id_rsa:"
send "mypassphrase\n";
interact
EOF

## change permissions
chmod 777 set_passphrase.exp

## test and execute script if necessary
if [ -z "$SSH_AUTH_SOCK" ] ; then
	eval `ssh-agent -s`
	./set_passphrase.exp
fi

## remove script
rm set_passphrase.exp

## fetch git repo
git fetch --all
