#!/bin/bash

set -o nounset
set -o errexit

# code from http://stackoverflow.com/a/1116890
function readlink()
{
    TARGET_FILE=$2
    cd `dirname $TARGET_FILE`
    TARGET_FILE=`basename $TARGET_FILE`

    # Iterate down a (possible) chain of symlinks
    while [ -L "$TARGET_FILE" ]
    do
        TARGET_FILE=`readlink $TARGET_FILE`
        cd `dirname $TARGET_FILE`
        TARGET_FILE=`basename $TARGET_FILE`
    done

    # Compute the canonicalized name by finding the physical path
    # for the directory we're in and appending the target file.
    PHYS_DIR=`pwd -P`
    RESULT=$PHYS_DIR/$TARGET_FILE
    echo $RESULT
}
export -f readlink

VERBOSE_MODE=0

function error_handler()
{
  local STATUS=${1:-1}
  [ ${VERBOSE_MODE} == 0 ] && exit ${STATUS}
  echo "Exits abnormally at line "`caller 0`
  exit ${STATUS}
}
trap "error_handler" ERR

PROGNAME=`basename ${BASH_SOURCE}`
DRY_RUN_MODE=0

function print_usage_and_exit()
{
  set +x
  local STATUS=$1
  echo "Usage: ${PROGNAME} [-v] [-v] [-h] [--help]"
  echo ""
  echo " Options -"
  echo "  -v                 enables verbose mode 1"
  echo "  -v -v              enables verbose mode 2"
  echo "  -h, --help         shows this help message"
  exit ${STATUS:-0}
}

function debug()
{
  if [ "$VERBOSE_MODE" != 0 ]; then
    echo $@
  fi
}

GETOPT=`getopt vh $*`
if [ $? != 0 ] ; then print_usage_and_exit 1; fi

eval set -- "${GETOPT}"

while true
do case "$1" in
     -v)            let VERBOSE_MODE+=1; shift;;
     -h|--help)     print_usage_and_exit 0;;
     --)            shift; break;;
     *) echo "Internal error!"; exit 1;;
   esac
done

if (( VERBOSE_MODE > 1 )); then
  set -x
fi


# template area is ended.
# -----------------------------------------------------------------------------
if [ ${#} != 0 ]; then print_usage_and_exit 1; fi

# current dir of this script
CDIR=$(readlink -f $(dirname $(readlink -f ${BASH_SOURCE[0]})))
PDIR=$(readlink -f $(dirname $(readlink -f ${BASH_SOURCE[0]}))/..)

# -----------------------------------------------------------------------------
# functions

function make_calmness()
{
	exec 3>&2 # save 2 to 3
	exec 2> /dev/null
}

function revert_calmness()
{
	exec 2>&3 # restore 2 from previous saved 3(originally 2)
}

function close_fd()
{
	exec 3>&-
}

function jumpto
{
	label=$1
	cmd=$(sed -n "/$label:/{:a;n;p;ba};" $0 | grep -v ':$')
	eval "$cmd"
	exit
}


# end functions
# -----------------------------------------------------------------------------



# -----------------------------------------------------------------------------
# main 

make_calmness
if (( VERBOSE_MODE > 1 )); then
	revert_calmness
fi

IP=localhost
PORT_1=9221
PORT_2=9222
PORT_3=9223
PORT_4=9224

model_path=${CDIR}/train_logs
rm -rf ${model_path}

function run_ps {
	nohup python ${CDIR}/mlp_mnist_dist.py --ps_hosts=${IP}:${PORT_1},${IP}:${PORT_2} \
			   --worker_hosts=${IP}:${PORT_3},${IP}:${PORT_4} \
			   --job_name=ps --task_index=0 &
	nohup python ${CDIR}/mlp_mnist_dist.py --ps_hosts=${IP}:${PORT_1},${IP}:${PORT_2} \
			   --worker_hosts=${IP}:${PORT_3},${IP}:${PORT_4} \
			   --job_name=ps --task_index=1 &
}
run_ps

function run_worker {
	time python ${CDIR}/mlp_mnist_dist.py --ps_hosts=${IP}:${PORT_1},${IP}:${PORT_2} \
			   --worker_hosts=${IP}:${PORT_3},${IP}:${PORT_4} \
			   --job_name=worker --task_index=0 \
			   --model_path=${model_path} &
	time python ${CDIR}/mlp_mnist_dist.py --ps_hosts=${IP}:${PORT_1},${IP}:${PORT_2} \
			   --worker_hosts=${IP}:${PORT_3},${IP}:${PORT_4} \
			   --job_name=worker --task_index=1 \
			   --model_path=${model_path} &
}
run_worker

close_fd

# end main
# -----------------------------------------------------------------------------
