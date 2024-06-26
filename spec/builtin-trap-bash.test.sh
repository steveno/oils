## oils_failures_allowed: 1
## compare_shells: bash

# Notes on bash semantics:

# https://www.gnu.org/software/bash/manual/bash.html
#
# Commands specified with a DEBUG trap are executed before every simple
# command, for command, case command, select command, every arithmetic for
# command, and before the first command executes in a shell function. The DEBUG
# trap is not inherited by shell functions unless the function has been given
# the trace attribute or the functrace option has been enabled using the shopt
# builtin. The extdebug shell option has additional effects on the DEBUG trap.

# The trap builtin (see Bourne Shell Builtins) allows an ERR pseudo-signal
# specification, similar to EXIT and DEBUG. Commands specified with an ERR trap
# are executed after a simple command fails, with a few exceptions. The ERR
# trap is not inherited by shell functions unless the -o errtrace option to the
# set builtin is enabled. 


#### trap -l
trap -l | grep INT >/dev/null
## status: 0


#### trap -p

trap 'echo exit' EXIT

trap -p > parent.txt

grep EXIT parent.txt >/dev/null
if test $? -eq 0; then
  echo shown
else
  echo not shown
fi

## STDOUT:
shown
exit
## END

#### trap -p in child is BUGGY in bash

# It shows the trap even though it doesn't execute it!

trap 'echo exit' EXIT

trap -p | cat > child.txt

grep EXIT child.txt >/dev/null
if test $? -eq 0; then
  echo shown
else
  echo not shown
fi

## STDOUT:
not shown
exit
## END
## BUG bash STDOUT:
shown
exit
## END

#### trap DEBUG ignores $?
debuglog() {
  echo "  [$@]"
  return 42     # IGNORED FAILURE
}

trap 'debuglog $LINENO' DEBUG

echo status=$?
echo A
echo status=$?
echo B
echo status=$?

## STDOUT:
  [8]
status=0
  [9]
A
  [10]
status=0
  [11]
B
  [12]
status=0
## END

#### but trap DEBUG respects errexit
set -o errexit

debuglog() {
  echo "  [$@]"
  return 42
}

trap 'debuglog $LINENO' DEBUG

echo status=$?
echo A
echo status=$?
echo B
echo status=$?

## status: 42
## STDOUT:
  [10]
## END

#### trap DEBUG with 'return'

debuglog() {
  echo "  [$@]"
}

trap 'debuglog $LINENO; return 42' DEBUG

echo status=$?
echo A
echo status=$?
echo B
echo status=$?

## status: 0

## STDOUT:
  [7]
status=0
  [8]
A
  [9]
status=0
  [10]
B
  [11]
status=0
## END

# OSH doesn't ignore this

## OK osh status: 42
## OK osh STDOUT:
  [7]
## END

#### trap DEBUG with 'exit'
debuglog() {
  echo "  [$@]"
}

trap 'debuglog $LINENO; exit 42' DEBUG

echo status=$?
echo A
echo status=$?
echo B
echo status=$?

## status: 42
## STDOUT:
  [7]
## END



#### trap DEBUG with non-compound commands
case $SH in (dash|mksh) exit ;; esac

debuglog() {
  echo "  [$@]"
}
trap 'debuglog $LINENO' DEBUG

echo a
echo b; echo c

echo d && echo e
echo f || echo g

(( h = 42 ))
[[ j == j ]]

var=value

readonly r=value

## STDOUT:
  [8]
a
  [9]
b
  [9]
c
  [11]
d
  [11]
e
  [12]
f
  [14]
  [15]
  [17]
  [19]
## END

#### trap DEBUG and control flow

debuglog() {
  echo "  [$@]"
}
trap 'debuglog $LINENO' DEBUG

while true; do
  echo hello
  break
done

## STDOUT:
  [6]
  [7]
hello
  [8]
## END
## STDOUT:
  [6]
  [7]
hello
  [8]
## END

#### trap DEBUG and command sub / subshell
case $SH in (dash|mksh) exit ;; esac

debuglog() {
  echo "  [$@]"
}
trap 'debuglog $LINENO' DEBUG

echo "result = $(echo command sub; echo two)"
( echo subshell
  echo two
)
echo done

## STDOUT:
  [8]
result = command sub
two
subshell
two
  [12]
done
## END

#### trap DEBUG not run in forked interpreter for first pipeline part

debuglog() {
  #echo "  PID=$$ BASHPID=$BASHPID LINENO=$1"
  echo "  LINENO=$1"
}
trap 'debuglog $LINENO' DEBUG

{ echo pipe1;
  echo pipe2; } \
  | cat
echo ok

## STDOUT:
  LINENO=8
pipe1
pipe2
  LINENO=9
ok
## END

#### One 'echo' in first pipeline part - why does bash behave differently from case above?

# TODO: bash runs the trap 3 times, and osh only twice.  I don't see why.  Is
# it because Process::Run() does trap_state.ClearForSubProgram()?  Probably
#echo top PID=$$ BASHPID=$BASHPID
#shopt -s lastpipe

debuglog() {
  #echo "  PID=$$ BASHPID=$BASHPID LINENO=$1"
  #echo "  LINENO=$1 $BASH_COMMAND"
  # LINENO=6 echo pipeline
  # LINENO=7 cat
  echo "  LINENO=$1"
}
trap 'debuglog $LINENO' DEBUG

echo pipeline \
  | cat
echo ok

## STDOUT:
  LINENO=6
  LINENO=7
pipeline
  LINENO=8
ok
## END
## OK osh STDOUT:
  LINENO=7
pipeline
  LINENO=8
ok
## END

#### trap DEBUG and pipeline (lastpipe difference)
debuglog() {
  echo "  [$@]"
}
trap 'debuglog $LINENO' DEBUG

# gets run for each one of these
{ echo a; echo b; }

# only run for the last one, maybe I guess because traps aren't inherited?
{ echo x; echo y; } | wc -l

# bash runs for all of these, but OSH doesn't because we have SubProgramThunk
# Hm.
date | cat | wc -l

date |
  cat |
  wc -l

## STDOUT:
  [6]
a
  [6]
b
  [8]
2
  [10]
  [10]
  [10]
1
  [12]
  [13]
  [14]
1
## END

# Marking OK due to lastpipe execution difference

## OK osh STDOUT:
  [6]
a
  [6]
b
  [8]
2
  [10]
1
  [14]
1
## END

#### trap DEBUG function call
debuglog() {
  echo "  [$@]"
}
trap 'debuglog $LINENO' DEBUG

f() {
  local mylocal=1
  for i in "$@"; do
    echo i=$i
  done
}

f A B  # executes ONCE here, but does NOT go into the function call

echo next

f X Y

echo ok

## STDOUT:
  [13]
i=A
i=B
  [15]
next
  [17]
i=X
i=Y
  [19]
ok
## END

#### trap DEBUG case
debuglog() {
  echo "  [$@]"
}
trap 'debuglog $LINENO' DEBUG

name=foo.py

case $name in 
  *.py)
    echo python
    ;;
  *.sh)
    echo shell
    ;;
esac
echo ok

## STDOUT:
  [6]
  [8]
  [10]
python
  [16]
ok
## END

#### trap DEBUG for each

debuglog() {
  echo "  [$@]"
}
trap 'debuglog $LINENO' DEBUG

for x in 1 2; do
  echo x=$x
done

echo ok

## STDOUT:
  [6]
  [7]
x=1
  [6]
  [7]
x=2
  [10]
ok
## END

# NOT matching bash right now because 'while' loops don't have it
# And we have MORE LOOPS
#
# What we really need is a trap that runs in the main loop and TELLS you what
# kind of node it is?

## N-I osh STDOUT:
  [7]
x=1
  [7]
x=2
  [10]
ok
## END

#### trap DEBUG for expr
debuglog() {
  echo "  [$@]"
}
trap 'debuglog $LINENO' DEBUG

for (( i =3 ; i < 5; ++i )); do
  echo i=$i
done

echo ok

## STDOUT:
  [6]
  [6]
  [7]
i=3
  [6]
  [6]
  [7]
i=4
  [6]
  [6]
  [10]
ok
## END
## N-I osh STDOUT:
  [7]
i=3
  [7]
i=4
  [10]
ok
## END

#### trap DEBUG if while
debuglog() {
  echo "  [$@]"
}
trap 'debuglog $LINENO' DEBUG

if test x = x; then
  echo if
fi 

while test x != x; do
  echo while
done

## STDOUT:
  [6]
  [7]
if
  [10]
## END


#### trap RETURN
profile() {
  echo "profile [$@]"
}
g() {
  echo --
  echo g
  echo --
  return
}
f() {
  echo --
  echo f
  echo --
  g
}
# RETURN trap doesn't fire when a function returns, only when a script returns?
# That's not what the manual says.
trap 'profile x y' RETURN
f
. $REPO_ROOT/spec/testdata/return-helper.sh
## status: 42
## STDOUT:
--
f
--
--
g
--
return-helper.sh
profile [x y]
## END


#### trap ERR with errtrace (-E)
# ERR trap is not inherited by shell functions, sub processes, sub commands, ... unless the -o errtrace option is set
set -E
trap "echo ERR" ERR
echo 0
false
echo 1
cat <( date X ; echo 2 )
echo $( date X ; echo 3 )
{ date X ; echo 4 ; }
{ date X ; echo 5 ; } & wait
( date X ; echo 6 ; )
f() { date X ; echo 7 ; } ; f
true
## status: 0
## STDOUT:
0
ERR
1
ERR
2
ERR 3
ERR
4
ERR
5
ERR
6
ERR
7
## END

#### trap ERR without errtrace (+E)
# ERR trap is not inherited by shell functions, sub processes, sub commands, ... unless the -o errtrace option is set
set +E
trap "echo ERR" ERR
echo 0
false
echo 1
cat <( date X ; echo 2 )
echo $( date X ; echo 3 )
{ date X ; echo 4 ; }
{ date X ; echo 5 ; } & wait
( date X ; echo 6 ; )
f() { date X ; echo 7 ; } ; f
true
## status: 0
## STDOUT:
0
ERR
1
2
3
ERR
4
5
6
7
## END

#### trap ERR LINENO
# ERR trap is not inherited by shell functions, sub processes, sub commands, ... unless the -o errtrace option is set
# TODO LINENO is not working, as it is was set to the trap method LINENO
set +E
trap "echo ERR=\$LINENO" ERR
echo 0
false
true
## status: 0
## STDOUT:
0
ERR=4
## END
## OK osh STDOUT:
0
ERR=1
## END

#### trap ERR shadowing with errtrace (-E)
# ERR trap is not inherited by shell functions, sub processes, sub commands, ... unless the -o errtrace option is set
set -E
trap "echo ERR" ERR
false ; trap "echo ERRx" ERR ; false ; trap "echo ERR" ERR
cat <( trap "echo ERR2" ERR ; date X )
false ; trap "echo ERRx" ERR ; false ; trap "echo ERR" ERR
echo $( trap "echo ERR3" ERR ; date X )
false ; trap "echo ERRx" ERR ; false ; trap "echo ERR" ERR
{ trap "echo ERR4" ERR ; date X ; }
false ; trap "echo ERRx" ERR ; false ; trap "echo ERR" ERR
{ trap "echo ERR5" ERR ; date X ; } & wait
false ; trap "echo ERRx" ERR ; false ; trap "echo ERR" ERR
( trap "echo ERR6" ERR ; date X )
false ; trap "echo ERRx" ERR ; false ; trap "echo ERR" ERR
f() { trap "echo ERR7" ERR ; date X ; } ; f
true
## status: 0
## STDOUT:
ERR
ERRx
ERR2
ERR
ERRx
ERR3
ERR
ERRx
ERR4
ERR4
ERRx
ERR5
ERR
ERRx
ERR6
ERR
ERR
ERRx
ERR7
ERR7
## END

#### trap ERR shadowing without errtrace (+E)
# ERR trap is not inherited by shell functions, sub processes, sub commands, ... unless the -o errtrace option is set
set +E
trap "echo ERR" ERR
false ; trap "echo ERRx" ERR ; false ; trap "echo ERR" ERR
cat <( trap "echo ERR2" ERR ; date X )
false ; trap "echo ERRx" ERR ; false ; trap "echo ERR" ERR
echo $( trap "echo ERR3" ERR ; date X )
false ; trap "echo ERRx" ERR ; false ; trap "echo ERR" ERR
{ trap "echo ERR4" ERR ; date X ; }
false ; trap "echo ERRx" ERR ; false ; trap "echo ERR" ERR
{ trap "echo ERR5" ERR ; date X ; } & wait
false ; trap "echo ERRx" ERR ; false ; trap "echo ERR" ERR
( trap "echo ERR6" ERR ; date X )
false ; trap "echo ERRx" ERR ; false ; trap "echo ERR" ERR
f() { trap "echo ERR7" ERR ; date X ; } ; f
true
## status: 0
## STDOUT:
ERR
ERRx
ERR2
ERR
ERRx
ERR3
ERR
ERRx
ERR4
ERR4
ERRx
ERR5
ERR
ERRx
ERR6
ERR
ERR
ERRx
ERR7
ERR7
## END
