#!/bin/bash

# Load $PATH and $LD_LIBRARY_PATH
source export.sh

# Change these variables to point to Uniprof and FlameGraph directories
path_to_uniprof='./'
path_to_flamegraph='../FlameGraph/'

# Global variables
script_name=$0
symbolize="symbolize"
uniprof='uniprof'
stackcollapse='stackcollapse.pl'
flamegraph='flamegraph.pl'

# Function for helping with usage
function usage
{
    echo "Usage: $script_name -f freq -t time -n domain -c path_to_conf -x path_to_exec"
    echo ""
    echo " -f | --frequency        : Frequency(Optional)"
    echo " -t | --time             : Time(Optional)"
    echo " -n | --domain           : Domain name(Mandatory)"
	echo " -c | --conf             : Path to configuration file(Mandatory)"
	echo " -x | --exec             : Path to executable(Mandatory)"
    echo " -h | --help             : Help argument"
}

# Function for running
function run
{
    parse_arguments "$@"
    echo "Frequency - $frequency"
    echo "Time - $time"
    echo "Domain - $domain"
	echo "Path to config - $path_conf"
	echo "Path to exec - $path_exec"
	echo "----------------------"
	echo ""

	echo "Starting VM..."  
	nohup xl create $path_conf > /dev/null 2>&1
	echo ""
#	sleep 1;                     

	echo "Finding domain id..."                            
	dom_id=$(xl list | grep "$domain" | awk '{print $2}')
	echo "Domain id = $dom_id"                             
	echo ""

	echo "Running uniprof..."
	nohup "$path_to_uniprof$uniprof" -F $frequency -T $time - $dom_id > "$domain-stacktrace" 2> /dev/null
	echo ""

	echo "Running nm to find symbols..."
	nohup nm -n $path_exec > "$domain.syms" 2> /dev/null
	echo ""

	echo "Running symbolize to map addresses..."
	nohup "$path_to_uniprof$symbolize" "$domain.syms" "$domain-stacktrace" > "$domain-stacktrace.syms" 2> /dev/null
	echo ""

	echo "Running stack collapse to format stack trace for Flame Graph..."
	nohup "$path_to_flamegraph$stackcollapse" "$domain-stacktrace.syms" > "$domain-stackcollapse" 2> /dev/null
	echo ""

	echo "Running Flame Graph..."
	nohup "$path_to_flamegraph$flamegraph" "$domain-stackcollapse" > "$domain-flamegraph.svg" 2> /dev/null
	echo ""
}
# Function to warn an invalid option
function invalid
{
    echo "$script_name: invalid option -- $1"
    echo "Try '$script_name --help' for more information"
}

# Function for parsing arguments
function parse_arguments
{

  # Parsing arguments
  while [ "$1" != "" ]; do
      case "$1" in
          -f | --frequency )         frequency="$2";          shift;;
          -t | --time )              time="$2";               shift;;
          -n | --domain )            domain="$2";             shift;;
          -c | --conf )              path_conf="$2";          shift;;
		  -x | --exec )              path_exec="$2";          shift;;
		  -h | --help )              usage;                   exit;;
          * )                        invalid $1;              exit;; # Invalid option
      esac
      shift
  done

  # Mandatory arguments
  if [[ -z "$domain" || -z "$path_conf" || -z "$path_exec" ]]; then
      echo "Invalid arguments. Some of them are mandatory."
      usage
      exit;
  fi

  # Set default value for optional arguments
  if [[ -z "$frequency" ]]; then
      frequency=1;
  fi

  if [[ -z "$time" ]]; then
      time=1;
  fi
}

run "$@"
