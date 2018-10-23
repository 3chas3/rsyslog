#!/bin/bash
# This is part of the rsyslog testbench, licensed under GPLv3
. ${srcdir:=.}/diag.sh init
export IMFILEINPUTFILES="1"
export IMFILEINPUTFILESSTEPS="5"
#export IMFILEINPUTFILESALL=$(($IMFILEINPUTFILES * $IMFILEINPUTFILESSTEPS))
export IMFILECHECKTIMEOUT="20"

generate_conf
add_conf '
$WorkDirectory '$RSYSLOG_DYNNAME'.spool

/* Filter out busy debug output, comment out if needed */
global(
	debug.whitelist="off"
	debug.files=["rainerscript.c", "ratelimit.c", "ruleset.c", "main Q", "msg.c", "../action.c"]
)

module(	load="../plugins/imfile/.libs/imfile" 
	mode="inotify" 
	PollingInterval="1")

input(type="imfile"
	File="./'$RSYSLOG_DYNNAME'.input.dir1/*/*/*/*/*/file.logfile"
	Tag="file:"
	Severity="error"
	Facility="local7"
	addMetadata="on"
)

template(name="outfmt" type="list") {
  constant(value="HEADER ")
  property(name="msg" format="json")
  constant(value=", ")
  property(name="$!metadata!filename")
  constant(value="\n")
}

if $msg contains "msgnum:" then
 action(
   type="omfile"
   file=`echo $RSYSLOG_OUT_LOG`
   template="outfmt"
 )
'
. $srcdir/diag.sh check-inotify
# generate input files first. Note that rsyslog processes it as
# soon as it start up (so the file should exist at that point).

# Start rsyslog now before adding more files
startup

for i in `seq 1 $IMFILEINPUTFILES`;
do
	echo "Make $RSYSLOG_DYNNAME.input.dir$i"
	mkdir $RSYSLOG_DYNNAME.input.dir$i
done

for j in `seq 1 $IMFILEINPUTFILESSTEPS`;
do
	echo "Loop Num $j"
	for i in `seq 1 $IMFILEINPUTFILES`;
	do
		echo "Make $RSYSLOG_DYNNAME.input.dir$i/dir$j/testdir"
		mkdir $RSYSLOG_DYNNAME.input.dir$i/dir$j
		mkdir $RSYSLOG_DYNNAME.input.dir$i/dir$j/testdir
		mkdir $RSYSLOG_DYNNAME.input.dir$i/dir$j/testdir/su$j
		mkdir $RSYSLOG_DYNNAME.input.dir$i/dir$j/testdir/su$j/bd$j
		mkdir $RSYSLOG_DYNNAME.input.dir$i/dir$j/testdir/su$j/bd$j/ir$j
		touch $RSYSLOG_DYNNAME.input.dir$i/dir$j/testdir/su$j/bd$j/ir$j/file.logfile
		./inputfilegen -m 1 > $RSYSLOG_DYNNAME.input.dir$i/dir$j/testdir/su$j/bd$j/ir$j/file.logfile
	done
	ls -d $RSYSLOG_DYNNAME.input.*

	# Check correct amount of input files each time
	let IMFILEINPUTFILESALL=$(($IMFILEINPUTFILES * $j))
	content_check_with_count "HEADER msgnum:00000000:" $IMFILEINPUTFILESALL $IMFILECHECKTIMEOUT

	# Delete all but first!
	for i in `seq 1 $IMFILEINPUTFILES`;
	do
		rm -rf $RSYSLOG_DYNNAME.input.dir$i/dir$j/testdir/su$j/bd$j/ir$j/file.logfile
		rm -rf $RSYSLOG_DYNNAME.input.dir$i/dir$j
	done

	# Helps in testbench parallel mode. 
	#	Otherwise sometimes directories are not marked deleted in imfile before they get created again.
	#	This is properly a real issue in imfile when FILE IO is high. 
	./msleep 1000
done

shutdown_when_empty # shut down rsyslogd when done processing messages
wait_shutdown	# we need to wait until rsyslogd is finished!
exit_test
