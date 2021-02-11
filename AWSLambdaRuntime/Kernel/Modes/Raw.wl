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
    handler_APIFunction,
    requestBody_,
    requestContextData_
] := Module[{
    handlerOutput,
    outputSpec
},
    handlerOutput = AWSLambdaRuntime`Utility`WithCleanContext[
        handler[requestBody]
    ];

    If[
        (* if the APIFunction indicates an output form *)
        Length[handler] >= 3,
        (* then wrap the output appropriately *)
        outputSpec = handler[[3]];
        handlerOutput = Switch[outputSpec,
            _String,
                handlerOutput = ExportForm[
                    handlerOutput,
                    outputSpec
                ],
            
            _, (* unknown/unsuported third-argument format *)
                handlerOutput
        ]
    ];

    Return[handlerOutput]
]

End[]

EndPackage[]