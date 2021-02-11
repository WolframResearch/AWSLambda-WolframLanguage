#!/bin/sh

export MATHEMATICA_USERBASE="/tmp/home/.WolframEngine"
#export HOME="/tmp/home"

# change the home directory (and other things) to /tmp/home
WL_INIT_DIRECTORIES='Print["Start of -runfirst ", DateList[]];'\
'Developer`ConfigureUser[None, "/tmp/home"];'\
'Unprotect[$HomeDirectory, $UserDocumentsDirectory, $WolframDocumentsDirectory];'\
'$UserDocumentsDirectory = $HomeDirectory = HomeDirectory[];'\
'$WolframDocumentsDirectory = FileNameJoin[{$HomeDirectory, "WolframDocuments"}];'\
'Protect[$HomeDirectory, $UserDocumentsDirectory, $WolframDocumentsDirectory];'\
'Print["End of -runfirst ", DateList[]];'

# launch the runtime
WL_RUNTIME_START='Print["Start of -run (before Get) ", DateList[]];'\
'Get["AWSLambdaRuntime`"];'\
'AWSLambdaRuntime`StartRuntime[];'\
'Exit[0]'

echo "Before kernel start - $(date +%H:%M:%S.%N)"
exec /usr/local/bin/WolframKernel \
  -pwfile '!cloudlm.wolfram.com' \
  -entitlement $WOLFRAMSCRIPT_ENTITLEMENTID \
  -pacletreadonly \
  -noinit \
  -runfirst "$WL_INIT_DIRECTORIES" \
  -run "$WL_RUNTIME_START"


#export WOLFRAMSCRIPT_CONFIGURATIONPATH="/tmp/home/.config/Wolfram/WolframScript/WolframScript.conf"
#export WOLFRAMINIT="-nopaclet"
#exec /usr/bin/wolframscript \
#  -debug \
#  -code "$WL_RUNTIME_START"