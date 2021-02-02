Print["Loading handler"]

ExternalBundle[{

    "func1" -> APIFunction[{
        "number" -> "Integer"
    }, (
        Echo["Running handler function"];
        Echo[#, "Handler function input"];
        Echo[$AWSLambdaContextData, "Handler function context"];
        <|
            "hello" -> "world",
            "squared" -> #number^2
        |>
    ) &],

    "func2" -> APIFunction["this is a string" &],

    "func3" -> APIFunction[{
        "number" -> "Integer"
    }, <|"anExpression" -> Sin[x]|> &],

    "func4" -> APIFunction[{
        "number" -> "Integer"
    }, BinarySerialize[123] &],

    "func5" -> APIFunction[{
        "number" -> "Integer"
    }, ResponseForm[2+2, "JSON"] &],

    "func6" -> APIFunction[{
        "number" -> "Integer"
    }, ExportForm[<|"n" -> #number + 3|>, "Base64"] &]

}]