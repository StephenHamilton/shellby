#!/bin/bash

#########
# Regex #
#########

# This is a perl style regex. Sorry
declare -r urlRegex='\b((?:https?:(?:/{1,3}|[a-z0-9%]))(?:[^\s()<>{}[]]+|([^\s()]?([^\s()]+)[^\s()]?)|([^\s]+?))+(?:([^\s()]?([^\s()]+)[^\s()]?)|([^\s]+?)|[^\s`!()[]\{\};:'"'"'".,<>?«»“”‘’]))'

###########
# general #
###########

# kill the specified process and all of its children
#
# The leaf processes are killed first, then it works up to the input
#
# @. a list of pid numbers. quoting does not matter
killtree() {
  local -a safePids=()
  for arg in "$@"; do
    if (( $arg > 0 )); then
      safePids+=( "$arg" )
    fi
  done
  if (( ${#safePids[@]} > 0 )); then
    local joinedPids=$(sed -E 's/\s+/,/g' <<< "${safePids[@]}")

    local -ra children=( $(pgrep -P "$joinedPids") )
    if [[ ${#children[@]} != 0 ]]; then
      killtree ${children[@]}
    fi
    kill -TERM ${safePids[@]}
  fi
}

# If stdin is empty print an error message
#
# 1.message the message to print
ifEmpty() {
  local -r message="$1"

  if read -r line; then
    cat <( echo "$line" ) -
  else
    echo "$message"
  fi
}

# get the message after the initial mention
#
# 1.inputString the whole irc command as one string
# 2.nick optional nick to parse
#
# stdout. the string message text
getMessageNoNick() {
  local -r inputString="$1"
  local -r nick="$2"

  local nickPattern
  if [[ -n "$nick" ]]; then
    nickPattern="$nick\W?\s*"
  fi

  sed -E "s/^(\S+\s+){3}:(.*)/\2/I;s/^$nickPattern//" <<< "$inputString"
}

# Checks if the type of a variable matches the specified type
checkType() {
  local -r variable="$1"
  local -r type="$2"

  declare -p "$variable" 2>/dev/null | grep -qE "^declare -$type"
  return $?
}

# resplit the passed parameters taking into account quoting
#
# @. parameters to split
resplitAndParse() {
  local -a splitArgs=()
  while IFS= read -r -d $'\0' arg; do
    splitArgs[i++]="$arg"
  done < <(printf "%s " "$@" | sed 's/ $//' | resplit.awk)
  parseArgs "${splitArgs[@]}"
}

declare -A argMap=()
declare -a vargs=()

# Parses the input arguments into a hashmap
#
# Any found parameters are placed into the argMap associative array
# The remaining arguments are placed into the vargs array
#
# @. the arguments to parse
parseArgs() {
  local arg
  local getNext=false
  local previous
  local i
  local -A parameterSet=()
  shopt -s extglob

  if checkType assignableParameters a; then
    for parameter in "${assignableParameters[@]}"; do
      parameterSet["$parameter"]=
    done
  fi

  local -r shortOption="-+([a-zA-Z])"
  local -r longOption="--+([a-zA-Z])"

  if checkType argMap A && checkType vargs a; then

    argMap=()
    vargs=()

    while (( $# > 0 )); do
      arg="$1"
      shift
      
      case "$arg" in
        $shortOption )
          if "$getNext"; then
            argMap["$previous"]=
          fi

          if (( ${#arg} == 2 )); then
            local char="${arg:1:1}"
            if [[ -n "${!parameterSet[@]}" ]] && [[ "${parameterSet[$char]+_}" ]]; then
              previous="$char"
              getNext=true
            else
              argMap["$char"]=
              previous=
              getNext=false
            fi
          else
            previous=
            getNext=false
            # the following code is safe due to the invariant that i is [a-zA-Z]{1}
            for i in $(grep -o . <<< "${arg#-}"); do
              if [[ -n "$previous" ]]; then
                argMap["$previous"]=
              fi
              if [[ -n "${!parameterSet[@]}" ]] && [[ "${parameterSet[$i]+_}" ]]; then
                previous="$i"
                getNext=true
              else
                argMap["$i"]=
                previous=
                getNext=false
              fi
            done
          fi
          ;;
        -- ) 
          if "$getNext"; then
            argMap["$previous"]=
            previous=
            getNext=false
          fi
          vargs+=( "$@" )
          break
          ;;
        $longOption )
          if "$getNext"; then
            argMap["$previous"]=
          fi
          local parameterName="${arg#--}"
          if [[ -n "${parameterSet[@]}" ]] && [[ "${parameterSet[$char]+_}" ]]; then
            previous="$parameterName"
            getNext=true 
          else
            previous=
            getNext=false 
            argMap["$parameterName"]=
          fi
          ;;
        * )
          if "$getNext"; then
            argMap["$previous"]="$arg"
            previous=
            getNext=false
          else
            vargs+=( "$arg" )
          fi
          ;;
      esac
           
    done
    if "$getNext"; then
      argMap["$previous"]=
    fi
  fi

  shopt -u extglob
}

# parse out the metadata from a privmsg
#
# supports a number of other similar messages as well
#
# 1.inputString the whole irc command as one string
#
# stdout. FROMNICK FROMNICK/CHANNEL CMD USERNAME HOSTNAME
# returns. 1 if the input was not parsed and 0 otherwise
getIRCInfo() {
  local -r inputString="$1"

  local -a infoArray=( $( sed -E 's/^:?([^![:space:]]+)(!([^@[:space:]]+)@(\S+))?\s+(\S+)\s+(\S+)(\s+.*)?/\1 \6 \5 \3 \4/' <<< "$inputString" ) )

  if (( ${#infoArray[@]} < 2 )); then
    return 1
  fi

  local -r channelRegex="^#"

  if [[ ! ${infoArray[1]} =~ $channelRegex ]] ; then
    infoArray[1]="${infoArray[0]}"
  fi

  echo "${infoArray[@]}"
  return 0
}

# get fields from space separated data
#
# 1.line the line to split
# @:1. the list of fields to print on separate lines 
getFields() {
  local -r line="$1"
  shift 
  local -ra fields=( $line )
  for i in "$@"; do
    echo "${fields[$i]}" 
  done
}

declare watchedFunctionName
declare watchedFunctionPid

# Helper to manage the saved function.
#
# Only call this from startAndWatch.
startFunction() {
  if [[ -n "$watchedFunctionPid" ]]; then
    local tempPid="$watchedFunctionPid"
    watchedFunctionPid=

    killtree "$tempPid"
    wait "$tempPid"
  fi

  "$watchedFunctionName" <&0 &
  local -r newPid="$!"
  watchedFunctionPid="$newPid"
}

# Runs the specified function restarting it when SIGHUP is recieved
#
# Only run this once per subshell as multiple instances will clobber each other.
# This function will also wait forever when started.
#
# 1. the name of the function to run. Assigned to global variable.
startAndWatch() {
  watchedFunctionName="$1"

  startFunction

  trap startFunction SIGHUP 

  while true; do
    if [[ -n "$watchedFunctionPid" ]]; then
      wait $watchedFunctionPid
      if (( $? != 0 )); then
        return
      fi
    fi
    sleep 5
  done
}
