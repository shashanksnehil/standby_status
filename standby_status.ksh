#!/bin/bash
##uncomment below if you want to cleanup /u02 with this script###
#find /u02 -name "*.trc" -mtime +2 -exec rm -f {} \;
###Add below in crontab to receive email every 1 hour####
#####job added to monitor MRP for <your DB_name>
####0 * * * * /home/oracle/standby_status.ksh "<your_sid>" "your_email" > /dev/null 2>&1
ORACLE_SID=$1
EMAIL_LIST=$2

if [[ $ORACLE_SID == "" ]]
then
echo "please provide SID "
exit
 else
 echo "ORACLE_SID is : $ORACLE_SID"
fi

if [[ $EMAIL_LIST == "" ]]
then
echo "please provide EMAIL_LIST"
exit
else
echo "EMAIL_LIST is $EMAIL_LIST"
fi

if [[ $ORACLE_HOME == "" ]]
then
  # try to extract from oratab
  ORACLE_HOME=`egrep "^$ORACLE_SID:" /etc/oratab | awk -F: '{print $2}'`
  if [[ $ORACLE_HOME == "" ]]
  then
    #no luck
    echo "Unable to retrieve Oracle Home for [$ORACLE_SID] from \$ENV or /etc/oratab"
    echo "Please export ORACLE_HOME or set for sid in /etc/oratab"
    exit
  else
   echo "ORACLE_HOME is: $ORACLE_HOME [Derived from /etc/oratab]"
  fi
else
  echo "ORACLE_HOME is: $ORACLE_HOME [Derived from \$ENV]"
fi
export ORACLE_HOME=$ORACLE_HOME
export ORACLE_SID=$ORACLE_SID
export EMAIL_LIST=$EMAIL_LIST
$ORACLE_HOME/bin/sqlplus -S "/ as sysdba" <<EOF > /home/oracle/"$ORACLE_SID"_stanbdy_status.txt 2>&1
set echo on;
select 'Standby thread '|| thread# || ' is '|| round((sysdate - max(first_time)) * 24,1) || ' hours behind Production.' from v\$log_history group by thread#;
select process, status,client_process, thread#, sequence#, block#, blocks from v\$managed_standby where process='MRP0';
select name, open_mode, log_mode, database_role from v\$database,v\$instance;
select name,value,time_computed from v\$dataguard_stats where name='apply lag';
set linesize 400
col Values for a65
col Recover_start for a21
select to_char(START_TIME,'dd.mm.yyyy hh24:mi:ss') "Recover_start"
  ,to_char(item)||' = '||to_char(sofar)||' '||to_char(units)||' '|| to_char(TIMESTAMP,'dd.mm.yyyy hh24:mi') "Values"
from v\$recovery_progress where start_time=(select max(start_time) from v\$recovery_progress);
!echo "file system above threshold"
!df -h | awk 'int(\$5) > 85'
!echo "space avialable in u02"
!df -h /u02
EOF
mailx -s ""$ORACLE_SID"_STANDBY_STATUS for `date`" "${EMAIL_LIST}" < /home/oracle/"$ORACLE_SID"_stanbdy_status.txt
exit
