module VirtualDom.Metadata exposing
  ( Metadata
  , check
  , Comparison
  , decode, decoder, encode
  )


import Array exposing (Array)
import Dict exposing (Dict)
import Json.Decode as Decode exposing ((:=))
import Json.Encode as Encode



-- METADATA


type alias Metadata =
  { versions : Versions
  , types : Types
  }



-- VERSIONS


type alias Versions =
  { elm : String
  }



-- TYPES


type alias Types =
  { message : String
  , aliases : Dict String Alias
  , unions : Dict String Union
  }


type alias Alias =
  { args : List String
  , tipe : String
  }


type alias Union =
  { args : List String
  , tags : Dict String (List String)
  }



-- COMPARISONS


type alias Comparison =
  { problems : List String
  , warnings : List String
  }


empty : Comparison
empty =
  Comparison [] []


addProblem : Comparison -> String -> Comparison
addProblem { problems, warnings } newProblem =
  { problems = newProblem :: problems
  , warnings = warnings
  }


addWarning : Comparison -> String -> Comparison
addWarning { problems, warnings } newWarning =
  { problems = problems
  , warnings = newWarning :: warnings
  }



-- CHECK


check : Metadata -> Metadata -> Comparison
check old new =
  if old.versions.elm /= new.versions.elm then
    addProblem empty <|
      "The history created with Elm " ++ old.versions.elm
      ++ ", but you are using Elm " ++ new.versions.elm ++ "."

  else
    checkTypes old.types new.types empty



-- CHECK TYPES


checkTypes : Types -> Types -> Comparison -> Comparison
checkTypes old new comparison =
  comparison
    |> checkMessage old.message new.message
    |> checkUnions old.unions new.unions
    |> checkAliases old.aliases new.aliases


checkMessage : String -> String -> Comparison -> Comparison
checkMessage old new comparison =
  if old == new then
    comparison
  else
    addProblem comparison <|
      "The message type changed from `" ++ old ++ "` to `" ++ new ++ "`."



-- CHECK UNIONS


checkUnions : Dict String Union -> Dict String Union -> Comparison -> Comparison
checkUnions old new comparison =
  let
    oldMissing key _ cmp =
      addWarning cmp <|
        "Union type `" ++ key ++ "` is no longer used."

    newMissing key _ cmp =
      addWarning cmp <|
        "Union type `" ++ key ++ "` is now in use."
  in
    Dict.merge oldMissing checkUnion newMissing old new comparison


checkUnion : String -> Union -> Union -> Comparison -> Comparison
checkUnion name old new comparison =
  let
    oldMissing key _ cmp =
      addProblem cmp <|
        "Constructor `" ++ key ++ "` was removed from union type `" ++ name
        ++ "` so the old history may have messages this program cannot handle."

    newMissing key _ cmp =
      addWarning cmp <|
        "Constructor `" ++ key ++ "` was added to union type `" ++ name
        ++ "`."
  in
    Dict.merge oldMissing (checkTag name) newMissing old.tags new.tags <|
      if old.args == new.args then
        comparison

      else
        addProblem comparison <|
          "Union type `" ++ name ++ "` now has different type variables."


checkTag : String -> String -> List String -> List String -> Comparison -> Comparison
checkTag name tag oldArgs newArgs comparison =
  if oldArgs /= newArgs then
    addProblem comparison <|
      "In union type `" ++ name ++ "` the data held in `" ++ tag ++ "` has changed."

  else
    comparison



-- CHECK ALIASES


checkAliases : Dict String Alias -> Dict String Alias -> Comparison -> Comparison
checkAliases old new comparison =
  let
    oldMissing key _ cmp =
      addWarning cmp <|
        "Type alias `" ++ key ++ "` is no longer used."

    newMissing key _ cmp =
      addWarning cmp <|
        "Type alias `" ++ key ++ "` is now in use."
  in
    Dict.merge oldMissing checkAlias newMissing old new comparison


checkAlias : String -> Alias -> Alias -> Comparison -> Comparison
checkAlias name old new comparison =
  if old.tipe /= new.tipe then
    addProblem comparison <|
      "Type alias `" ++ name ++ "` has changed."

  else if old.args /= new.args then
    addProblem comparison <|
      "The type arguments for type alias `" ++ name ++ "` have changed."

  else
    comparison



-- JSON DECODE


decode : Encode.Value -> Metadata
decode value =
  case Decode.decodeValue decoder value of
    Ok metadata ->
      metadata

    Err msg ->
      Debug.crash msg


decoder : Decode.Decoder Metadata
decoder =
  Decode.object2 Metadata
    ("versions" := decodeVersions)
    ("types" := decodeTypes)


decodeVersions : Decode.Decoder Versions
decodeVersions =
  Decode.object1 Versions ("elm" := Decode.string)


decodeTypes : Decode.Decoder Types
decodeTypes =
  Decode.object3 Types
    ("message" := Decode.string)
    ("aliases" := Decode.dict decodeAlias)
    ("unions" := Decode.dict decodeUnion)


decodeUnion : Decode.Decoder Union
decodeUnion =
  Decode.object2 Union
    ("args" := Decode.list Decode.string)
    ("tags" := Decode.dict (Decode.list Decode.string))


decodeAlias : Decode.Decoder Alias
decodeAlias =
  Decode.object2 Alias
    ("args" := Decode.list Decode.string)
    ("type" := Decode.string)



-- JSON ENCODE


encode : Metadata -> Encode.Value
encode { versions, types } =
  Encode.object
    [ ("versions", encodeVersions versions)
    , ("types", encodeTypes types)
    ]


encodeVersions : Versions -> Encode.Value
encodeVersions { elm } =
  Encode.object [("elm", Encode.string elm)]


encodeTypes : Types -> Encode.Value
encodeTypes { message, unions, aliases } =
  Encode.object
    [ ("message", Encode.string message)
    , ("aliases", encodeDict encodeAlias aliases)
    , ("unions", encodeDict encodeUnion unions)
    ]


encodeAlias : Alias -> Encode.Value
encodeAlias { args, tipe } =
  Encode.object
    [ ("args", Encode.list (List.map Encode.string args))
    , ("type", Encode.string tipe)
    ]


encodeUnion : Union -> Encode.Value
encodeUnion { args, tags } =
  Encode.object
    [ ("args", Encode.list (List.map Encode.string args))
    , ("tags", encodeDict (Encode.list << List.map Encode.string) tags)
    ]


encodeDict : (a -> Encode.Value) -> Dict String a -> Encode.Value
encodeDict f dict =
  dict
    |> Dict.map (\key value -> f value)
    |> Dict.toList
    |> Encode.object


