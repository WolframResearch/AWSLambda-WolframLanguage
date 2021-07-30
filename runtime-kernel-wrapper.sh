#!/bin/sh

export MATHEMATICA_USERBASE="/tmp/home/.WolframEngine"
export MATHEMATICAPLAYER_USERBASE="/tmp/home/.WolframEngine"
export WOLFRAM_CACHEBASE="/tmp/home/.cache/Wolfram"
export WOLFRAM_LOG_DIRECTORY="/tmp/home/.Wolfram/Logs"

# change the home directory (and other things) to /tmp/home
WL_INIT_DIRECTORIES='Developer`ConfigureUser[None, "/tmp/home"];'\
'Unprotect[$HomeDirectory, $UserDocumentsDirectory, $WolframDocumentsDirectory];'\
'$UserDocumentsDirectory = $HomeDirectory = HomeDirectory[];'\
'$WolframDocumentsDirectory = FileNameJoin[{$HomeDirectory, "WolframDocuments"}];'\
'Protect[$HomeDirectory, $UserDocumentsDirectory, $WolframDocumentsDirectory];'

# launch the runtime
WL_RUNTIME_START='Get["AWSLambdaRuntime`"];'\
'AWSLambdaRuntime`StartRuntime[];'\
'Exit[0]'

exec /usr/local/bin/WolframKernel \
  -pwfile '!cloudlm.wolfram.com' \
  -entitlement $WOLFRAMSCRIPT_ENTITLEMENTID \
  -pacletreadonly \
  -noinit \
  -runfirst "$WL_INIT_DIRECTORIES" \
  -run "$WL_RUNTIME_START"