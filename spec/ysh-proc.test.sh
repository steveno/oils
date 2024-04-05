
#### Open proc (any number of args)
shopt --set parse_proc

proc f {
  var x = 42
  return $x
}
# this gets called with 3 args then?
f a b c
echo status=$?
## STDOUT:
status=42
## END

#### Closed proc with no args, passed too many
shopt --set parse_proc

proc f() {
  return 42
}
f
echo status=$?

f a b  # status 2

## status: 3
## STDOUT:
status=42
## END

#### Open proc has "$@"
shopt -s oil:all
proc foo { 
  write ARGV "$@"
}
builtin set -- a b c
foo x y z
## STDOUT:
ARGV
x
y
z
## END

#### Closed proc doesn't have "$@"
shopt -s oil:all
proc foo(d, e, f) { 
  write params $d $e $f
  write ARGV "$@"
}
builtin set -- a b c
foo x y z
## STDOUT:
params
x
y
z
ARGV
## END


#### Proc with default args
shopt --set parse_proc

proc f(x='foo') {
  echo x=$x
}
f
## STDOUT:
x=foo
## END

#### Proc with word params
shopt --set parse_proc

# doesn't require oil:all
proc f(x, y, z) {
  echo $x $y $z
  var ret = 42
  return $ret
}
# this gets called with 3 args then?
f a b c
echo status=$?
## STDOUT:
a b c
status=42
## END

#### Proc with ... "rest" word params 

# TODO: opts goes with this
# var opt = grep_opts.parse(ARGV)
#
# func(**opt)  # Assumes keyword args match?
# parse :grep_opts :opt @ARGV

shopt -s oil:all

proc f(...names) {
  write names: @names
}
# this gets called with 3 args then?
f a b c
echo status=$?
## STDOUT:
names:
a
b
c
status=0
## END

#### word rest params 2
shopt --set ysh:all

proc f(first, ...rest) {  # @ means "the rest of the arguments"
  write --sep ' ' -- $first
  write --sep ' ' -- @rest        # @ means "splice this array"
}
f a b c
## STDOUT:
a
b c
## END

#### proc with typed args
shopt --set ysh:upgrade

# TODO: duplicate param names aren't allowed
proc p (a; mylist, mydict; opt Int = 42) {
  json write --pretty=F (a)
  json write --pretty=F (mylist)
  json write --pretty=F (mydict)
  #json write --pretty=F (opt)
}

p WORD ([1,2,3], {name: 'bob'})

echo ---

p x (:| a b |, {bob: 42}, a = 5)

## STDOUT:
"WORD"
[1,2,3]
{"name":"bob"}
---
"x"
["a","b"]
{"bob":42}
## END

#### Proc name-with-hyphen
shopt --set parse_proc

proc name-with-hyphen {
  echo "$@"
}
name-with-hyphen x y z
## STDOUT:
x y z
## END

#### Proc with block arg
shopt --set ysh:upgrade

# TODO: Test more of this
proc f(x, y ; ; ; block) {
  echo f word $x $y

  if (block) {
    eval (block)
  }
}
f a b { echo FFF }

# With varargs and block
shopt --set parse_proc

proc g(x, y, ...rest ; ; ; block) {
  echo g word $x $y
  echo g rest @rest

  if (block) {
    eval (block)
  }
}
g a b c d {
  echo GGG
}

## STDOUT:
f word a b
FFF
g word a b
g rest c d
GGG
## END

#### proc returning wrong type
shopt --set parse_proc

# this should print an error message
proc f {
  var a = %(one two)
  return $a
}
f
## status: 3
## STDOUT:
## END

#### proc returning invalid string
shopt --set parse_proc

# this should print an error message
proc f {
  var s = 'not an integer status'
  return $s
}
f
## status: 1
## STDOUT:
## END

#### 'return' doesn't accept expressions
proc p {
  return 1 + 2
}
p
## status: 2
## STDOUT:
## END

#### procs are in same namespace as shell functions
shopt --set parse_proc

myfunc() {
  echo hi
}

proc myproc {
  echo hi
}

declare -F
## STDOUT:
declare -f myfunc
declare -f myproc
## END


#### Nested proc is disallowed at parse time
shopt --set parse_proc

# NOTE: we can disallow this in Oil statically ...
proc f {
  proc g {
    echo 'G'
  }
  g
}
f
g
## status: 2
## stdout-json: ""

#### Procs defined inside compound statements (with redefine_proc)

shopt --set oil:upgrade
shopt --set redefine_proc_func

for x in 1 2 {
  proc p {
    echo 'loop'
  }
}
p

{
  proc p {
    echo 'brace'
  }
}
p

## STDOUT:
loop
brace
## END

#### Test varargs and blocks
shopt --set ysh:upgrade

proc DUMP(...a;...b;...c; d) {
  echo @a
  echo @b
  for i, k, v in (c) {
    echo "$i - $k - $v"
  }
  # TODO : figure out how to inspect blocks
}
DUMP a b c ('d', 'e', 'f', h = "i", j = "k") {
  echo 0
}
## STDOUT:
a b c
d e f
0 - h - i
1 - j - k
## END

#### mixing typed positional varargs and blocks
shopt --set ysh:upgrade

proc doIt(;...args) {
  if (len(args) === 1) {
    eval (args[0])
  } else {
    var a = args[0]
    echo $a
    var argsRest = args[1:]
    # call argsRest->append(blk)
    doIt (...argsRest)
  }
}

# all of below work. 
doIt (1, 2, 3) {
  echo 4
}

doIt (1, 2, 3, ^(echo 4))

doIt {
  echo 1
}
## STDOUT:
1
2
3
4
1
2
3
4
1
## END
