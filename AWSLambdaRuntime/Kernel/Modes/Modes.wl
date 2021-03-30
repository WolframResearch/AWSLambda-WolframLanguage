BeginPackage["AWSLambdaRuntime`Modes`"]

Begin["`Private`"]

Get["AWSLambdaRuntime`Modes`HTTP`"]
Get["AWSLambdaRuntime`Modes`Raw`"]

(* ::Section:: *)
(* Fallthrough for ValidateHandler and EvaluateHandler) *)

invalidModeFailure := Failure[
    "InvalidHandlerMode",
    <|
        "MessageTemplate" -> "The handler mode `1` is not valid",
        "MessageParameters" -> {AWSLambdaRuntime`Handler`$AWSLambdaHandlerMode}
    |>
]

AWSLambdaRuntime`Modes`ValidateHandler[_, ___] := invalidModeFailure
AWSLambdaRuntime`Modes`EvaluateHandler[_, ___] := invalidModeFailure

End[]

EndPackage[]