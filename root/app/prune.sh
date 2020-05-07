#!/usr/bin/with-contenv bash

my_dir="$(dirname "${BASH_SOURCE[0]}")"
source "$my_dir/common.sh"

log_dir=""
log_file=/dev/null
mail_file=/dev/null

if [[ ! -z ${EMAIL_SMTP_SERVER} ]] && [[ ! -z ${EMAIL_TO} ]]; then
    log_dir=`mktemp -d`
    log_file=$log_dir/backup.log
    mail_file=$log_dir/mailbody.log
fi

echo ========== Run prune job at `date` ========== | tee $log_file

"$my_dir/delay.sh"

start=$(date +%s.%N)
config_dir=/config

cd $config_dir

IFS=';'
read -ra policies <<< $PRUNE_KEEP_POLICIES
command="$PRUNE_OPTIONS"
for policy in ${policies[@]}; do
    command="$command -keep $policy"
done

echo "*** Prune ***" | tee -a $log_file
sh -c "duplicacy $GLOBAL_OPTIONS prune $command" | tee -a $log_file
exitcode=$?

duration=$(echo "$(date +%s.%N) - $start" | bc)
subject=""

if [ $exitcode -eq 0 ]; then
    echo Prune COMPLETED, duration $(converts $duration) | tee -a $log_file
    subject="duplicacy prune job id \"$hostname:$SNAPSHOT_ID\" COMPLETED"
else
    echo Prune FAILED, code $exitcode, duration $(converts $duration) | tee -a $log_file
    subject="duplicacy prune job id \"$hostname:$SNAPSHOT_ID\" FAILED"
fi

"$my_dir/mailto.sh" $log_dir "$subject"

exit $exitcode