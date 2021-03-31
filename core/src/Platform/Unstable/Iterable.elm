module Platform.Unstable.Iterable exposing (..)

import Array exposing (Array)
import Basics exposing (..)
import Dict exposing (Dict)
import Elm.Kernel.List
import List exposing ((::))
import Result exposing (Result(..))
import Set exposing (Set)


{-| Js function converts collection into a js iterator.
-}
type Iterable a
    = Stub_Iterable


map : (a -> b) -> Iterable a -> Iterable b
map func it =
    Elm.Kernel.List.fromArray it
        |> List.map func
        |> list


tryMap : (a -> Result e b) -> Iterable a -> Result e (Iterable b)
tryMap func it =
    Elm.Kernel.List.fromArray it
        |> tryMapList func []
        |> Result.map list


list : List a -> Iterable a
list =
    Elm.Kernel.List.iterate


array : Array a -> Iterable a
array =
    Array.toList >> list


set : Set a -> Iterable a
set =
    Set.toList >> list


dict : Dict k v -> Iterable ( k, v )
dict =
    Dict.toList >> list


toList : Iterable a -> List a
toList =
    Elm.Kernel.List.fromArray


toArray : Iterable a -> Array a
toArray =
    toList >> Array.fromList


toSet : Iterable comparable -> Set comparable
toSet =
    toList >> Set.fromList


toDict : Iterable ( comparable, v ) -> Dict comparable v
toDict =
    toList >> Dict.fromList



-- helpers


tryMapList : (a -> Result e b) -> List b -> List a -> Result e (List b)
tryMapList func output input =
    case input of
        [] ->
            Ok (List.reverse output)

        first :: rest ->
            case func first of
                Ok ok ->
                    tryMapList func (ok :: output) rest

                Err e ->
                    Err e
