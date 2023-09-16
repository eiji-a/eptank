# MariaDB 

## connect on terminal

$ mysql -h <host> -u <user> -P 3306 -p <dbname>

ex) mysql -h 192.168.11.211 -u redforest13 -P 3306 -p eptank

## user

1) root/!t...
2) redforest13/ak...

## socket file

/var/run/mysql/mysqld.sock

> $ sudo ln -s /var/run/mysqld/mysqld.sock /tmp/mysql.sock


## Ubuntu firewall

$ sudo ufw allow 3306

## config 

file: /etc/mysql/mariadb.conf.d/50-server.cnf

old)
> bind-address  = 127.0.0.1
>  :
> character-set-server = ??

new)
> #bind-address  = 127.0.0.1   <- comment out
>  :
> character-set-server = utf8mb4

file: /etc/mysql/mariadb.conf.d/50-client.cnf

old)
> [client]
>  :

new)
> [client]
> default-character-set=utf8mb4





