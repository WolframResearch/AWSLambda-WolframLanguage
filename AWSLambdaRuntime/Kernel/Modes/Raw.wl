BeginPackage["AWSLambdaRuntime`Modes`Raw`"]

AWSLambdaRuntime`Modes`ValidateHandler
AWSLambdaRuntime`Modes`EvaluateHandler

Begin["`Private`"]

Needs["AWSLambdaRuntime`API`"]

(* ::Section:: *)
(* Initialize mode implementation (load dependencies) *)

AWSLambdaRuntime`Modes`InitializeMode["Raw"] := Null (* nothing currently needed here *)

(* ::Section:: *)
(* Validate handler (called during initialization) *)

(* any expression is considered valid (it will be called as a function) *)
AWSLambdaRuntime`Modes`ValidateHandler[
    "Raw",
    handler_
] := Success["Valid", <||>]

(* ::Section:: *)
(* Evaluate handler *)

AWSLambdaRuntime`Modes`EvaluateHandler[
    "Raw",
    handler_,
    requestBody_,
    requestContextData_
] := Module[{
    handlerOutput
},
    handlerOutput = AWSLambdaRuntime`Utility`WithCleanContext[
        handler[requestBody]
    ];

    Return[handlerOutput]
]

End[]

EndPackage[]