#!/bin/bash
echo \[imuxsock_logger.sh\]: test imuxsock

uname
if [ $(uname) = "FreeBSD" ] ; then
   echo "This test currently does not work on FreeBSD."
   exit 77
fi

if [ $(uname) = "SunOS" ] ; then
   echo "Solaris: FIX ME LOGGER"
   exit 77
fi

. ${srcdir:=.}/diag.sh init
generate_conf
add_conf '
module(load="../plugins/imuxsock/.libs/imuxsock" sysSock.use="off")
input(type="imuxsock" Socket="'$RSYSLOG_DYNNAME'-testbench_socket")

template(name="outfmt" type="string" string="%msg:%\n")
*.notice      action(type="omfile" file=`echo $RSYSLOG_OUT_LOG` template="outfmt")
'
startup
# send a message with trailing LF
logger -d -u $RSYSLOG_DYNNAME-testbench_socket test
# the sleep below is needed to prevent too-early termination of rsyslogd
./msleep 100
shutdown_when_empty # shut down rsyslogd when done processing messages
wait_shutdown	# we need to wait until rsyslogd is finished!
cmp $RSYSLOG_OUT_LOG $srcdir/resultdata/imuxsock_logger.log
if [ ! $? -eq 0 ]; then
  echo "imuxsock_logger.sh failed"
  echo "contents of $RSYSLOG_OUT_LOG:"
  echo \"`cat $RSYSLOG_OUT_LOG`\"
  exit 1
fi;
exit_test
