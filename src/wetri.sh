#!/bin/bash

# Copyright (C) 2011 Phillip Smith
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# note that we can't use bomb() here because it is defined in common.shlib
common_script="${0%/*}/common.shlib"
[[ ! -f "$common_script" ]] && { echo "$common_script not found"; exit 1; }
[[ ! -r "$common_script" ]] && { echo "$common_script read error"; exit 1; }
source "$common_script"

# constants
DEBUG=0
LOCKDIR='/var/lock'

###############################################################################
### FUNCTIONS
###############################################################################

function usage() {
	local _exit_with="$1"
	[[ -z "$_exit_with" ]] && _exit_with=0

	cat <<EOT
Usage: $0 -j job_name [-t loop_count] [-i interval] [-e integer] -v -h (cmdline)

	cmdline is the command you wish to wetri ('retry')

	-j	job_name is a unique identifier for this job. It's primary purpose is
		for use in preventing multiple instances of wetri attempting to do the
		same thing, as well as for logging.
	-t	loop_count is the number of time to attempt the job before giving up.
		wetri will always exit the first time the task completes successfully.
		Default: 3
	-i	interval; how long to pause between attempts. This can be any valid
		argument to sleep. Refer to 'man 1 sleep' for details.
		Default: 30s
	-e	Expected exit code; what exit code to consider success when executing
		user command.
		Default: 0
	-v	Verbose
	-h	This help message

EOT
	exit $_exit_with
}

take_lock() {
	local _job="$1"
	[[ -z "$_job" ]] && return 1

	local _pidfile="${LOCKDIR}/wetri.$job_name"

	# lock file already in place for this job?
	if [[ -e "$_pidfile" ]] ; then
		# is the pid still alive?
		local _other_pid=$(cat $_pidfile)
		ps -p $_other_pid & >/dev/null
		if [[ $? = 0 ]] ; then
			bomb "Lock file for job '$_job' already exists!"
		fi
			# It died without cleaning up
			feedback "PID file for job '$_job' still exists but the process is dead"
			rm -f $_pidfile || bomb "Unable to remove dead lockfile: $_pidfile"
			take_lock && return 0
		fi
	else
		# Not already there; Try to make it.
		touch $_pidfile
		if [[ $? -eq 0 ]] ; then
			# success!
			echo "$$" > $_pidfile
			return 0
		else
			bomb "Unable to obtain lock file: $_pidfile"
		fi
	fi

	# assume we couldn't get the lock, but we shuld never get here anyway
	return 1
}

###############################################################################
### MAIN
###############################################################################

# test for required binaries
require_bins cat touch seq ps rm

# get our cmdline args
dbg 'Starting getopts'
job_name=
loop_cnt=3
sleep_interval=30s
expected_ec=0
verbose=
silent=
while getopts "j:t:i:vsh" OPTION ; do
	case $OPTION in
		h)
			usage 0
			;;
		j)
			job_name="$OPTARG"
			;;
		t)
			loop_cnt="$OPTARG"
			;;
		i)
			sleep_interval="$OPTARG"
			;;
		e)
			expected_ex="$OPTARG"
			;;
		v)
			verbose='yes'
			;;
		?)
			usage 1
			;;
	esac
done

dbg 'Finished getopts'

# make sure we've got everything we need to know
if [[ -z "$job_name" ]] || [[ -z "$loop_cnt" ]] ; then
	feedback 'Missing job and/or loop_cnt'
	usage 1
fi

# attempt to take a lock for this job name
take_lock $job_name || bomb "Unable to obtain a lock for job '$job_name'"

# remove the arguments that we parsed above with getopts
shift $(expr $OPTIND - 1)
# whatever is left is the users desired command
users_cmd="$*"
if [[ -z "$users_cmd" ]] ; then
     usage 1
fi

feedback "Attempting '$loop_cnt' times, with '$sleep_interval' between attempts, to execute:"
feedback "   $users_cmd"

ec=1
for c in $(seq 1 $loop_cnt) ; do
	feedback "==> Attempt $c"
	$users_cmd
	if [[ $? -eq $expected_ec ]] ; then
		ec=$expected_ec
		break
	fi
	# Wait X before trying again
	[[ $c -ne $loop_cnt ]] && sleep $sleep_interval
done

# How did we do?
if [[ $ec -eq $expected_ec ]] ; then
	# success!
	feedback "Your command succeeded after $c attempts"
else
	# we failed
	feedback "Even after $c attempts, your command still failed. Sorry"
fi

exit $ec
