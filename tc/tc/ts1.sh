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
        
        echo "start <interface> <port> <speed> <port type> <priority> <ip/ipv6> last two are optional"
        echo "show <interface>"
        echo "stop <interface> <type>"
        echo "interface : mandatory"
        echo -e " available interface : \033[1;4;31m[ "$(echo $all_inter | sed 's/ / | /g')" ]\033[0m"
        echo "port      : mandatory : port number 1:65535 or any for remaning ports"
        echo "speed     : mandatory : In Kbps"
        echo "porttype  : mandatory : sport/dport"
        echo "priority  : optional  : 1-10, default:1"
        echo "ip/ipv6   : optional  : ip/ipv6, default:ip"
        echo "type      : mandatory : dev | class | filter"

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
        echo "start <interface> <port> <speed> <port type> <priority> <ip/ipv6> last two are optional"
        echo "interface : mandatory"
        echo "port      : mandatory : port number 1:65535 or any for remaning ports"
        echo "speed     : mandatory : In Kbps"
        echo "porttype" : mandatory : sport/dport
        echo "priority  : optional  : 1-10, default:1"
        echo "ip/ipv6   : optional  : ip/ipv6, default:ip" 
        exit 1
    fi
# Checking port type shpuld be sport/dport
#   if [[ "$3" != "any" ]]
#   then
 #      if [[ "sport" == "$5" ]]
 #      then
  #         port=$(printf '%x\n' $3)"0000"
#           echo $port
#           exit 1
   #    elif [[ "dport" == "$5" ]]
   #    then
    #       port="0000"$(printf '%x\n' $3) 
 #          echo "$port"
 #          exit 1
     #  else
      #     echo "port-type : mandatory : sport/dport"
       #    exit 1
     #  fi
  # fi
# Checking ports they sholud be in range of 1 to 65535
    
    if [[ "$3" -gt "1" && "$3" -lt "65535" || "$3" == "any" ]]
    then
       if [[ "sport" == "$5" ]]
       then
         if [[ "$3" != "any" ]]
         then
           port=$(printf '%x\n' $3)"0000"
#           echo $port
#           exit 1
         fi
       elif [[ "dport" == "$5" ]]
       then
         if [[ "$3" != "any" ]]
         then
           port="0000"$(printf '%x\n' $3)
 #          echo "$port"
 #          exit 1
         fi
       else
           echo "port-type : mandatory : sport/dport"
           exit 1
       fi 
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
        echo "Class already exists"
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
            echo "filter already exists"
            exit 1
        else
            tc filter add dev $2 protocol $ip parent 1: prio $prio u32 match $ip $5 $3 0xffff flowid 1:$4
        fi
    else   
        if [ "$(tc -s filter show dev $2 | grep -c "00000000/00000000")" == "0" ]
        then
            tc filter add dev $2 protocol $ip parent 1: prio 3 u32 match u32 0 0 flowid 1:2
        else
            echo "filter already exists"
            exit 1
        fi
    fi
    echo "Successfully Done" 
    ;; 

#  stop)
 #   if [[ $# != 2 ]]
 #   then
 #      echo "stop [interface]"
 #      exit 1
 #   fi
 #   checkinter $1 $2
#    tc qdisc del dev $2 root
#    echo "done"
#    ;;
  stop)
     checkinter $1 $2
    
     case "$3" in  
     dev)
       
        tc qdisc del dev $2 root
#        echo "Successfully Done"
     ;;
    
     class)
        if [[ "$(tc -s class show dev $2 | grep "class htb $4" | awk '{print $3}')" == $4 && $4 != "" ]]
        then
             tc class del dev $2 classid $4
        else
             echo "stop <interface> class <classid>"
             echo "To check classId use tc.tc1 show command"
             echo "\"tc.tc1 show <interface>\""
             echo -e "  Ex: class htb \033[1;4;31m1:10\033[0m root prio 0 rate 10Kbit ceil 10Kbit burst 1600b cburst 1600b" 
             echo -e "  classid = \033[1;4;31m1:10\033[0m"
       fi
     ;; 

     filter)
        echo $4 $5 
        if [[ "$(tc -s filter show dev $2 | grep "pref $4" |tail -1| awk '{print $7}')" == $4 && $5 != "" ]]
        then
           echo "prio"
           if [[ "$(tc -s filter show dev $2 | grep "fh $5" |tail -1| awk '{print $10}')" == $5 ]]
            then
                echo "handler"
                 tc filter del dev $2 pref $4 handle $5 u32
                 exit 0
           fi
        fi
        echo "stop <interface> filter <priority> < handler>"
        echo "To check priority and handler use tc.tc1 show <interface>"
        echo "\"tc.tc1 show <interface>\""
        echo -e "  ex-filter parent 1: protocol ip pref \033[1;4;31m1\033[0m u32 fh \033[1;4;31m800::800\033[0m order 2048 key ht 800 bkt 0 flowid 1:10"
        echo -e "  priority = \033[1;4;31m1\033[0m"
        echo -e "  handler = \033[1;4;31m800::800\033[0m"
    #    echo "priority and handler(major : minor) :"
    #    echo "                      tc.tc1 show <interface>"
    #    echo -e "                      ex-filter parent 1: protocol ip pref \033[1;4;31m1\033[0m u32 fh \033[1;4;31m800\033[0m::\033[1;4;31m800\033[0m order 2048 key ht 800 bkt 0 flowid 1:10"
    #    echo -e " priority = \033[1;4;31m1\033[0m"
    #    echo " handler" 
    #    echo -e "       major = \033[1;4;31m800\033[0m"
    #    echo -e "       minor = \033[1;4;31m800\033[0m"

     ;;

     *)
        echo "stop <interface> <type>[ dev | class | filter ]"
        echo "Command Syntax : "
        echo "stop <interface> dev"
        echo "stop <interface> class <classid>"
        echo "stop <interface> filter <priority> < handler>"

        echo "type : mandatory : [dev | class | filter]"
        #echo "classid :"
        #echo "        \"tc.tc1 show <interface>\""
        #echo -e "         ex- class htb \033[1;4;31m1:10\033[0m root prio 0 rate 10Kbit ceil 10Kbit burst 1600b cburst 1600b" 
        #echo -e "classid = \033[1;4;31m1:10\033[0m"
             echo "To check classId use tc.tc1 show command"
             echo "\"tc.tc1 show <interface>\""
             echo -e "  Ex: class htb \033[1;4;31m1:10\033[0m root prio 0 rate 10Kbit ceil 10Kbit burst 1600b cburst 1600b" 
             echo -e "  classid = \033[1;4;31m1:10\033[0m"

#        echo "priority and handler :"
#        echo "         tc.tc1 show <interface>"
#        echo -e "         ex-filter parent 1: protocol ip pref \033[1;4;31m1\033[0m u32 fh \033[1;4;31m800::800\033[0m order 2048 key ht 800 bkt 0 flowid 1:10"
#        echo -e " priority = \033[1;4;31m1\033[0m"
#        echo -e " handler = \033[1;4;31m800::800\033[0m"
        echo "To check priority and handler use tc.tc1 show <interface>"
        echo "\"tc.tc1 show <interface>\""
        echo -e "  ex-filter parent 1: protocol ip pref \033[1;4;31m1\033[0m u32 fh \033[1;4;31m800::800\033[0m order 2048 key ht 800 bkt 0 flowid 1:10"
        echo -e "  priority = \033[1;4;31m1\033[0m"
        echo -e "  handler = \033[1;4;31m800::800\033[0m"

       # echo "priority and handler(<major> : <minor>) :"
       # echo "                      tc.tc1 show <interface>"
       # echo -e "                      ex-filter parent 1: protocol ip pref \033[1;4;31m1\033[0m u32 fh \033[1;4;31m800\033[0m::\033[1;4;31m800\033[0m order 2048 key ht 800 bkt 0 flowid 1:10"
       # echo -e " priority = \033[1;4;31m1\033[0m"
       # echo " handler" 
       # echo -e "       major = \033[1;4;31m800\033[0m"
       # echo -e "       minor = \033[1;4;31m800\033[0m"

     ;;
     esac;;
    

  show)
    if [[ "$#" != "2" ]]
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

    echo "Usage: { start | stop | show }"
    echo "start <interface> <port> <speed> <port type> <priority> <ip/ipv6> last two are optional"
    echo "stop <interface> <type>"
    echo "show <interface>"
    echo "interface : mandatory"
    echo "port      : mandatory : port number 1:65535 or any for remaning port"
    echo "speed     : mandatory : In Kbps"
    echo "port-type : mandatory : sport/dport"
    echo "priority  : optional  : 1-10, default:1"
    echo "ip/ipv6   : optional  : ip/ipv6, default:ip" 
    echo "type      : mandatory : dev | class | filter"
    ;;


esac

exit 0

