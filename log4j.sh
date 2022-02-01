#!/bin/bash

prog=$(basename "$0")
cwd=$(cd $(dirname "$0") && pwd)

datetime=$(date +"%Y-%m-%d_%H.%M.%S")

patch_required_message="needs patching"
patched_message="patched"


banner()
{
cat <<EOF
------------------------------------------------------------------------------
                       ArcGIS Enterprise Log4jShell fix
(For usage help: ${prog} -h)
------------------------------------------------------------------------------
EOF
}

print_usage()
{
  banner
cat <<EOF
 $prog - ArcGIS Enterprise Log4jShell fix
 Usage: $prog [-l] [-y] [-h]
       -l             = Show list of files to be modified (dry run)
       -y             = Don't prompt for [y/n] responses
       -h             = Usage help
 Examples:
       Check the list of files to be updated:
           % $prog -l
       Run the fix to update the files
           % $prog
       Run $prog without prompting for yes or no:
           % $prog -y
------------------------------------------------------------------------------
EOF
  exit_clean
}

exit_clean()
{
  exit 0
}

exit_fail()
{
  echo "Error: $1"
  exit 1
}

trap exit_clean SIGINT SIGTERM SIGHUP

checkDir()
{
  isSetupPresent=$(find . -maxdepth 2 -name .Setup | head -1)
  if [ "x$isSetupPresent" = "x" ]; then
    exit_fail "Script must be run at the root of the product installation"
  fi
}

checkUser()
{
  setup_folder=$(find . -maxdepth 2 -name .Setup | head -1)
  ags_user=$(stat -c '%U' ${setup_folder})
  running_user=$(id -u -n)
  if [ "$ags_user" != "$running_user" ]; then
    exit_fail "Script needs to be run as the owner ($ags_user) of the ArcGIS Enterprise product/s."  
  fi
}

print_patch_summary_message()
{
  isneeded=$1
  echo ""
  if [ "$isneeded" = "true" ]; then
    echo "Summary:System needs patching. Please run this tool without any option or with \"-y\"."
  else
    echo "Summary:System is already  patched. No further action needed."
  fi
  echo ""
}

get_list()
{
  echo "Searching for affected files..."
  needs_patching=false
  for i in $(find . -type f \( -name \*log4j*core\*.jar \)  -print)
  do
   array_entry="$i:true"
   needs_patching=true
    #implementationVersion=$(grep -i "Implementation-Version:" META-INF/MANIFEST.MF | awk '{print $2}')
    #implementationVersion="${implementationVersion//[$'\t\r\n ']}"
    #if (( $(echo "$implementationVersion < 2.17" |bc -l) ));then
    #  array_entry="$i:true"
    #  needs_patching=true
    #else
    #  array_entry="$i:false"
    #fi
    file_array+=($array_entry)
  done
}

runFix() 
{
  which zip > /dev/null 2>&1
  if [ $? != 0 ]; then
    exit_fail "Zip is not installed on the local machine..."
  fi

  get_list
  echo "Checking files for patch status"
   if [ "$needs_patching" != "true" ]; then
     print_list true
     exit_clean
   else
     print_list false
   fi
  if [ "$QUIET_MODE" != "true" ]; then
    read -r -p "Proceed with patching files (y/n)? [n]" answer
    answer=$(echo $answer | tr '[A-Z]' '[a-z]')
    if [ "$answer" != "y" ]; then
      echo "Exiting..."
      exit 1
    fi
  fi

  for file_entry in "${file_array[@]}"
  do
      file_name=$(echo $file_entry | cut -f 1 -d ':')
      file_status=$(echo $file_entry | cut -f 2 -d ':')

      if [ "$file_status" = "true" ]; then
        echo "Deleting class from $file_name..."
        if [ ! -f ${file_name}.backup ]; then
          cp $file_name ${file_name}.backup
        fi
        result=$?
        if [ $result != 0 ] && [ $result != 12 ]; then
	  echo "Error occured while updating jar $file_name"
        fi
      else
       echo "Patch already applied to $file_name, skipping..."
      fi
  done
}

print_list()
{
  print_summary=$1
  req_patch="false"
  echo "Found files: ${#file_array[@]}"
  for file_entry in "${file_array[@]}"
  do
      file_name=$(echo $file_entry | cut -f 1 -d ':')
      file_status=$(echo $file_entry | cut -f 2 -d ':')
      if [ "$file_status" = "true" ]; then
 	echo $file_name -- $patch_required_message
        req_patch="true"
      else  
       echo $file_name -- $patched_message
      fi
  done
  if [ "$print_summary" = "true" ]; then
    print_patch_summary_message $req_patch
  fi
}

show_list()
{
  get_list
  print_list true
  exit_clean
}

main()
{
  while getopts "lyh" opt
  do
    case $opt in
      h)
        print_usage
        break
        ;;
      y)
        QUIET_MODE=true
	break
        ;;
      l)
        show_list
 	break
        ;;
      *)
        print_usage
        break
        ;;
    esac
  done
  checkDir
  checkUser
  runFix
}

file_array=()
main $*
