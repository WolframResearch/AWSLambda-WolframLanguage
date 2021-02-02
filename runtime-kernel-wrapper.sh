#!/bin/sh

export MATHEMATICA_USERBASE="/tmp/home/.WolframEngine"
#export HOME="/tmp/home"

env

# change the home directory (and other things) to /tmp/home
WL_INIT_DIRECTORIES='Developer`ConfigureUser[None, "/tmp/home"];'\
'Unprotect[$HomeDirectory, $UserDocumentsDirectory, $WolframDocumentsDirectory];'\
'$UserDocumentsDirectory = $HomeDirectory = HomeDirectory[];'\
'$WolframDocumentsDirectory = FileNameJoin[{$HomeDirectory, "WolframDocuments"}];'\
'Protect[$HomeDirectory, $UserDocumentsDirectory, $WolframDocumentsDirectory];'

# launch the runtime
WL_RUNTIME_START='Needs["AWSLambdaRuntime`"];'\
'AWSLambdaRuntime`StartRuntime[];'\
'Exit[0]'

exec /usr/local/bin/WolframKernel \
  -pwfile '!cloudlm.wolfram.com' \
  -entitlement $WOLFRAMSCRIPT_ENTITLEMENTID \
  -nopaclet \
  -runfirst "$WL_INIT_DIRECTORIES" \
  -run "$WL_RUNTIME_START"


#export WOLFRAMSCRIPT_CONFIGURATIONPATH="/tmp/home/.config/Wolfram/WolframScript/WolframScript.conf"
#export WOLFRAMINIT="-nopaclet"
#exec /usr/bin/wolframscript \
#  -debug \
#  -code "$WL_RUNTIME_START"