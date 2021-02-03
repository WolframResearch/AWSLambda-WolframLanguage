Echo["Loading app.wl"]

ExternalBundle[{

    "pi" -> APIFunction[{
        "digits" -> "Integer" -> 50,
        "base" -> "Integer" -> 10
    }, <|
        "digits" -> RealDigits[Pi, #base, #digits][[1]]
    |> &],

    "divide" -> APIFunction[{
        "dividend" -> "Number",
        "divisor" -> "Number",
        "integer" -> "Boolean" -> False
    }, If[
        TrueQ[#integer],
        AssociationThread[
            {"quotient", "remainder"},
            QuotientRemainder[#dividend, #divisor]
        ],
        <|"quotient" -> #dividend / #divisor|>
    ] &],

    "factor" -> APIFunction[{"x" -> "Integer"}, FactorInteger[#x] &],

    "randomImage" -> APIFunction[
        {"max" -> "Real" -> 1},
        RandomImage[#max] &,
        "PNG"
    ],

    "numberImage" -> APIFunction[{
        "number" -> "Real"
    }, ExportForm[Rasterize[#number, RasterSize -> 100], "PNG"] &],

    "countryPopulation" -> APIFunction[{
        "country" -> "Country",
        "year" -> "Integer" :> DateValue["Year"]
    }, <|
        "population" -> QuantityMagnitude@EntityValue[
            #country,
            Dated["Population", #year]
        ]
    |> & ],

    "countryMap" -> APIFunction[
        "country" -> "Country",
        GeoGraphics[Polygon[#country]] &,
        "PNG"
    ],

    "stockPrice" -> APIFunction[
        "ticker" -> "Financial",
        Replace[
            #ticker["Last"],
            {
                q_Quantity :> <|
                    "magnitude" -> QuantityMagnitude[q],
                    "unit" -> QuantityUnit[q]
                |>,
                n_?NumberQ :> <|"magnitude" -> n|>,
                _ :> Failure["NoData", <|
                    "MessageTemplate" -> "No data found for financial entity \"`1`\"",
                    "MessageParameters" -> {TextString[#ticker]}
                |>]
            }
        ] &
    ],

    "outputJSON" -> APIFunction[<|
        "string" -> "hello world",
        "integer" -> 42,
        "real" -> 123.456,
        "boolean" -> True,
        "null" -> Null,
        "array" -> {1, 2, 3.3, "four"},
        "object" -> <|
            "key1" -> 123,
            "key2" -> "value",
            "key3" -> {3, 1, 4, 1, 5}
        |>
    |> &],

    "outputString" -> APIFunction["this is a string" &],

    "outputWXF" -> APIFunction[{},
        Plot[Sin[x], {x, -5, 5}] &,
        "WXF"
    ],

    "outputMathML" -> APIFunction[{},
        (1 + a) / b &,
        "MathML"
    ],

    "debugData" -> APIFunction[
        ToString[<|
            "Hello" -> "World",
            "Event" -> #,
            "Context" -> $AWSLambdaContextData,
            "Directories" -> <|
                "HomeDirectory" -> $HomeDirectory,
                "HomeDirectory[]" -> HomeDirectory[],
                "UserBaseDirectory" -> $UserBaseDirectory,
                "UserAddOnsDirectory" -> $UserAddOnsDirectory,
                "UserBasePacletsDirectory" -> $UserBasePacletsDirectory,
                "DefaultLocalBase" -> $DefaultLocalBase,
                "LocalBase" -> $LocalBase,
                "UserDocumentsDirectory" -> $UserDocumentsDirectory,
                "WolframDocumentsDirectory" -> $WolframDocumentsDirectory,
                "InitialDirectory" -> $InitialDirectory,
                "PreferencesDirectory" -> $PreferencesDirectory,
                "CacheBaseDirectory" -> $CacheBaseDirectory
            |>
        |>, InputForm] &
    ]

}]