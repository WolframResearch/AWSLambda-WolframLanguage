(*
    This is a function handler file containing a single raw-mode handler.

    As this file is named `raw-handler-file.wl`, a function can be configured
    to use the handler in this file by giving the handler specification
    "raw-handler-file" as the command line (CMD) in the Dockerfile or in
    the function's ImageConfig in `template.yaml`.

    If instead of a single handler this file contained an association of
    multiple handlers, like:
    <|
        "myhandler" -> Function[...],
        "anotherhandler" -> APIFunction[...]
    |>

    ...then these handlers could be accessed with handler specifications like:
    - "raw-handler-file.myhandler"
    - "raw-handler-file.anotherhandler"

    The pure function below accepts an association (i.e. JSON object) with an
    "input" key containing a string, reverses the letters in the string, and
    returns another association (JSON object) with the reversed string in the
    "reversed" key.

    This function does not perform any validation its input, so invocations
    will fail of the "input" key is not present or is not a string.
*)

Function[
    <|
        "reversed" -> StringReverse[#input]
    |>
]