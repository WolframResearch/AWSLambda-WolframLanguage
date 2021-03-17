BeginPackage["AWSLambdaRuntime`Modes`Raw`"]

AWSLambdaRuntime`Modes`ValidateHandler
AWSLambdaRuntime`Modes`EvaluateHandler

Begin["`Private`"]

Needs["AWSLambdaRuntime`API`"]

(* ::Section:: *)
(* Validate handler (called during initialization) *)

(* valid *)
AWSLambdaRuntime`Modes`ValidateHandler[
    "Raw",
    handler_APIFunction
] := Success["Valid", <||>]

(* invalid *)
AWSLambdaRuntime`Modes`ValidateHandler[
    "Raw",
    handler_ (* not APIFunction *)
] := Failure[
    "InvalidHandler",
    <|
        "MessageTemplate" -> StringJoin[{
            "The handler expression with head `1` is not an APIFunction ",
            "expression"
        }],
        "MessageParameters" -> {Head[handler]}
    |>
]

(* ::Section:: *)
(* Evaluate handler *)

AWSLambdaRuntime`Modes`EvaluateHandler[
    "Raw",
    originalHandler_APIFunction,
    requestBody_,
    requestContextData_
] := Module[{
    handler = originalHandler,
    handlerOutput,
    outputSpec
},
    (* move output form from the third argument of APIFunction to
        an ExportForm wrapper inside the function *)
    handler = Replace[
        handler,
        APIFunction[params_, fun_, fmt_String] :> APIFunction[
            params,
            fun /* (ExportForm[#, fmt] &)
        ]
    ];

    handlerOutput = AWSLambdaRuntime`Utility`WithCleanContext[
        handler[requestBody]
    ];

    Return[handlerOutput]
]

End[]

EndPackage[]