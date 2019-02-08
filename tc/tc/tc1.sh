#!/bin/bash

#tc traffic control for iotr


checkinter() {
    all_inter=$(ls /sys/class/net)
    f=0
    #f=$(echo $all_inter | grep -c "$2")
    for i in $all_inter
    do
        if [ "$i" == "$2" ]
        then
#           echo "$2"
            f=1
            break
        fi
    done
    if [ "$f" == "0" ]
    then
        
        echo "start [interface] [port] [speed] [port type] [priority] [ip/ipv6] last two are optional"
        echo "show [interface]"
        echo "stop [interface]"
        echo "interface : mandatory"
        echo "             [ "$(echo $all_inter | sed 's/ / | /g')" ]"
        echo "port      : mandatory : port number 1:65535 or any for remaning ports"
        echo "speed     : mandatory : In Kbps"
        echo "porttype  : mandatory : sport/dport"
        echo "priority  : optional  : 1-10, default:1"
        echo "ip/ipv6   : optional  : ip/ipv6, default:ip"

#echo "$all_inter"
        exit 1
    fi
}


#######################################
# main

case "$1" in

  start)
    checkinter $1 $2
    if [[ $5 == "" || $8 != "" ]]
    then
        echo "start [interface] [port] [speed] [port type] [priority] [ip/ipv6] last two are optional"
        echo "interface : mandatory"
        echo "port      : mandatory : port number 1:65535 or any for remaning ports"
        echo "speed     : mandatory : In Kbps"
        echo "porttype" : mandatory : sport/dport
        echo "priority  : optional  : 1-10, default:1"
        echo "ip/ipv6   : optional  : ip/ipv6, default:ip" 
        exit 1
    fi
# Checking port type shpuld be sport/dport
   if [[ "$3" != "any" ]]
   then
       if [[ "sport" == "$5" ]]
       then
           port=$(printf '%x\n' $3)"0000"
#           echo $port
#           exit 1
       elif [[ "dport" == "$5" ]]
       then
           port="0000"$(printf '%x\n' $3) 
 #          echo "$port"
 #          exit 1
       else
           echo "port-type : mandatory : sport/dport"
           exit 1
       fi
   fi
# Checking ports they sholud be in range of 1 to 65535
    
    if [[ "$3" -gt "1" && "$3" -lt "65535" || "$3" == "any" ]]
    then
        echo ""
    else
       echo "$3"
       echo "port   : mandatory : port number 1:65535 or any for remaning ports"
       exit 1 
    fi
    
# Checking priority   
    if [[ "$6" -ge "1" && "$6" -le "10" ]]
    then
       prio="$6"
    elif [[  "$6" == "" ]]
    then
       prio=1
    else
       echo "priority  : optional : 1-10, default:1"
       exit 1
    fi
#Checking while it ipv4 or ipv6
    if [[ "$7" != "" ]]
    then
       if [[ "$7" == "ip" || "$7" == "ipv6" ]]
       then
          ip=$7
       else
           echo "ip/ipv6  : optional : ip/ipv6,default:ip"
           exit 1
       fi
    else
       ip="ip"
    fi

# Checking for Device , class , filter are they exists or not
    if [[ "$(tc -s qdisc show | grep -c "htb 1: dev $2")" == "0" ]]
    then
        #1. Creating qdisc
        #Now to add the new root HTB qdisc:
        tc qdisc add dev $2 root handle 1: htb
    fi

    if [ "$(tc -s class show dev $2 | grep -c "1:$4")" == "1" ]
    then
        echo "Class is already exists"
    #    exit 1
    else 
        #2. Class creation.
        #Now that we have our qdisc ready to go we can create classes.
        tc class add dev $2 parent 1: classid 1:$4 htb rate $4kbit
      #  if [ "$(tc -s class show dev $2 | grep -c "1:2")" == "0" ]
      #  then
      #        tc class add dev $2 parent 1: classid 1:2 htb rate 2kbit
      #  fi
    fi
    if [ $3 != "any" ]
    then
        if [ "$(tc -s filter show dev $2 | grep -c "$port")" == "1" ] 
        then
            echo "filter is already exists"
            exit 1
        else
            tc filter add dev $2 protocol $ip parent 1: prio $prio u32 match $ip $5 $3 0xffff flowid 1:$4
        fi
    else   
        if [ "$(tc -s filter show dev $2 | grep -c "00000000/00000000")" == "0" ]
        then
            tc filter add dev $2 protocol $ip parent 1: prio 3 u32 match u32 0 0 flowid 1:2
        else
            echo "filter is already exists"
        fi
    fi
    echo "Done" 
    ;; 

  stop)
    if [[ $# != 2 ]]
    then
       echo "stop [interface]"
       exit 1
    fi
    checkinter $1 $2
    tc qdisc del dev $2 root
    echo "done"
    ;;

  show)
    if [[ $# != 2 ]]
    then 
        echo "show [interface]"
        exit 1
    fi
    checkinter $1 $2 
    # qdisc show
    tc -s qdisc show
    # class stats
    tc -s class show dev $2
    # filter
    tc -s filter show dev $2
    echo "done"
    ;;

  *)

    echo "Usage: {start|stop|show}"
    echo "start [interface] [port] [speed] [port-type] [priority] [ip/ipv6]" 
    echo "stop [interface]"
    echo "show [interface]"
    echo "interface : mandatory"
    echo "port      : mandatory : port number 1:65535 or any for remaning port"
    echo "speed     : mandatory : In Kbps"
    echo "port-type : mandatory : sport/dport"
    echo "priority  : optional  : 1-10, default:1"
    echo "ip/ipv6   : optional  : ip/ipv6, default:ip" 
    ;;

esac

exit 0

