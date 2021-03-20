BeginPackage["MimeticLink`"]

ParseMIMEByteArray

Begin["`Private`"]

(* ::Section:: *)
(* Message part ignore bitmasks *)

$messageIgnoreMasks = <|
    "Header" -> 6,
    "Body" -> 7,
    "ChildParts" -> 8,
    "Preamble" -> 9,
    "Epilogue" -> 10
|> // Map[BitShiftLeft[1, #] &]

(* ::Section:: *)
(* Initialize LibraryLink functions *)

(* TODO: use a resource? *)
$pacletBaseDirectory = FileNameDrop[$InputFileName, -2]
Get[FileNameJoin[{$pacletBaseDirectory, "LibraryResources", "LibraryLinkUtilities.wl"}]]

`LLU`InitializePacletLibrary["MimeticLink"]

`LLU`PacletFunctionSet @@@ {
    {
        CPPParseMIMEByteArray,
        "ParseMIMEByteArray",
        {
            {ByteArray, "Constant"}, (* message contents *)
            Integer (* mask *)
        },
        "DataStore",
        "Throws" -> False
    }
}

(* ::Section:: *)
(* ParseMIMEByteArray *)

Options[ParseMIMEByteArray] = {
    "IgnoreParts" -> {"Preamble", "Epilogue"}
}

ParseMIMEByteArray[{}] := None
ParseMIMEByteArray[rawByteArray_ByteArray, OptionsPattern[]] := Module[{
    ignoreMask,
    rawParseResult
},
    ignoreMask = BitOr @@ KeyTake[
        $messageIgnoreMasks,
        OptionValue["IgnoreParts"] // Replace[None -> {}]
    ];
    rawParseResult = CPPParseMIMEByteArray[rawByteArray, ignoreMask];

    Return@postProcessParsedEntity[rawParseResult]
]

(* ::Section:: *)
(* Utility *)

(* ::Subsection:: *)
(* mapAtKeyIfNonMissing - apply a function to a key in an association if the key exists and is not missing *)

mapAtKeyIfNonMissing[key_, f_][assoc_] := If[
    !MissingQ[assoc[key]],
    MapAt[f, assoc, {Key[key]}],
    assoc
]

(* ::Subsection:: *)
(* postProcessParsedEntity - convert a parsed entity DataStore to a pretty association *)

postProcessParsedEntity[failure_Failure] := failure

postProcessParsedEntity[dataStore_Developer`DataStore] := Module[{
    entity = Association @@ dataStore
},
    entity = <|
        "ContentType" -> Missing["NotAvailable"],
        entity
    |> // RightComposition[
        mapAtKeyIfNonMissing[
            "ContentType",
            RightComposition[
                Apply[Association],
                mapAtKeyIfNonMissing["Parameters", Apply[Association]]
            ]
        ],

        mapAtKeyIfNonMissing[
            "ContentDisposition",
            RightComposition[
                Apply[Association],
                mapAtKeyIfNonMissing["Parameters", Apply[Association]]
            ]
        ],

        mapAtKeyIfNonMissing[
            "RawHeaders",
            Apply[List]
        ],

        mapAtKeyIfNonMissing[
            "BodyByteArray",
            Replace[na_NumericArray?NumericArrayQ :> ByteArray[na]]
        ],

        mapAtKeyIfNonMissing[
            "ChildParts",
            Apply[List] /* Map[postProcessParsedEntity]
        ]
    ];

    Return[entity]
]

End[]

EndPackage[]