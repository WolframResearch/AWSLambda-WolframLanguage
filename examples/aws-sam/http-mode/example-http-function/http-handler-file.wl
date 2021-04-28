(*
    This is a function handler file containing a single HTTP-mode handler.

    As this file is named `http-handler-file.wl`, a function can be configured
    to use the handler in this file by giving the handler specification
    "http-handler-file" as the command line (CMD) in the Dockerfile or in
    the function's ImageConfig in `template.yaml`.

    If instead of a single handler this file contained an association of
    multiple handlers, like:
    <|
        "myhandler" -> APIFunction[...],
        "anotherhandler" -> FormFunction[...]
    |>

    ...then these handlers could be accessed with handler specifications like:
    - "http-handler-file.myhandler"
    - "http-handler-file.anotherhandler"
*)


(*
    Setting $AWSLambdaHandlerMode as done here makes explicit that the handler in
    this file is to be used in HTTP-mode, but doing so is redundant if
    the environment variable WOLFRAM_LAMBDA_HANDLER_MODE is also set (as it is
    in `template.yaml`)
*)
$AWSLambdaHandlerMode = "HTTP"


(*
    This handler is a URLDispatcher, which allows URL routing rules to be defined with Wolfram Language code.
*)

URLDispatcher[{
    (* This is an APIFunction that returns the population of a given country in a given year. *)
    "/api" -> APIFunction[
        {
            "country" -> "Country",
            "year" -> "Integer" :> DateValue["Year"] (* default to the current year *)
        },
        <|
            "population" -> QuantityMagnitude@EntityValue[
                #country,
                Dated["Population", #year]
            ]
        |> &,
        "JSON"
    ],

    (* This is a FormFunction that applies an effect to an uploaded image. *)
    "/form" -> FormFunction[
        {"image" -> "Image", "filter" -> ImageEffect[]}, 
        ImageEffect[#image, #filter] &,
        "PNG"
    ],

    (* This is a computed ("delayed") response containing a PNG file. *)
    "/image" -> Delayed[RandomEntity["Pokemon"]["Image"], "PNG"],

    (* This is a path-based routing pattern that returns a result based on parameters in the URL. *)
    StringExpression[
        "/power/",
        base : Repeated[DigitCharacter, 3],
        "^",
        power : Repeated[DigitCharacter, 3]
    ] :> (
        FromDigits[base] ^ FromDigits[power]
    ),

    (* This is a computed HTML string. *)
    "/" -> Delayed@ExportForm[
        Echo["Received request for root route"];
        TemplateApply@StringJoin@{
            "Hello! I am a URLDispatcher running in version ",
            "<* $VersionNumber *> of the Wolfram Engine. ",
            "Try one of these links: ",
            "<a href=\"api?country=zimbabwe&year=2008\">/api</a>, ",
            "<a href=\"form\">/form</a>, ",
            "<a href=\"image\">/image</a>, ",
            "<a href=\"power/42^42\">/power/42^42</a>",
            "<br/><br/>",
            "Here is the current HTTPRequestData[]:<br/>",
            "<code><* ToString[HTTPRequestData[], InputForm] *></code><br/>",
            "And the $HTTPRequest:<br/>",
            "<code><* ToString[$HTTPRequest, InputForm] *></code>"
        },
        "HTML"
    ]
}]