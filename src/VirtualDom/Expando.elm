module VirtualDom.Expando exposing
  ( Value
  , init
  , Msg, update
  , view
  )


import Dict exposing (Dict)
import Json.Decode as Json
import Native.Debug
import VirtualDom exposing (Node, text)



-- MODEL


type Value
  = Primitive String
  | Sequence SeqType Bool (List Value)
  | Record Bool (Dict String Value)
  | Constructor (Maybe String) Bool (List Value)


type SeqType = ListSeq | SetSeq | ArraySeq


seqTypeToString : Int -> SeqType -> String
seqTypeToString n seqType =
  case seqType of
    ListSeq ->
      "List (" ++ toString n ++ ")"

    SetSeq ->
      "Set (" ++ toString n ++ ")"

    ArraySeq ->
      "Array (" ++ toString n ++ ")"


init : a -> Value
init =
  Native.Debug.init



-- UPDATE


type Msg
  = Toggle
  | Index Int Msg
  | Key String Msg


update : Msg -> Value -> Value
update msg value =
  case value of
    Primitive stringRep ->
      Debug.crash "No messages for primitives"

    Sequence seqType isClosed valueList ->
      case msg of
        Toggle ->
          Sequence seqType (not isClosed) valueList

        Index index subMsg ->
          Sequence seqType isClosed (updateIndex index subMsg valueList)

        Key _ _ ->
          Debug.crash "No key on sequences"

    Record isClosed valueDict ->
      case msg of
        Toggle ->
          Record (not isClosed) valueDict

        Index _ _ ->
          Debug.crash "No index for records"

        Key key subMsg ->
          Record isClosed (Dict.update key (updateKey subMsg) valueDict)

    Constructor maybeName isClosed valueList ->
      case msg of
        Toggle ->
          Constructor maybeName (not isClosed) valueList

        Index index subMsg ->
          Constructor maybeName isClosed (updateIndex index subMsg valueList)

        Key _ _ ->
          Debug.crash "No key for constructors"


updateIndex : Int -> Msg -> List Value -> List Value
updateIndex n msg list =
  case list of
    [] ->
      []

    x :: xs ->
      if n <= 0 then
        update msg x :: xs
      else
        x :: updateIndex (n-1) msg xs


updateKey : Msg -> Maybe Value -> Maybe Value
updateKey msg maybeValue =
  case maybeValue of
    Nothing ->
      Debug.crash "key does not exist"

    Just value ->
      Just (update msg value)



-- VIEW


view : Maybe String -> Value -> Node Msg
view maybeKey value =
  case value of
    Primitive stringRep ->
      div [ leftPad maybeKey ] (expando maybeKey Nothing stringRep)

    Sequence seqType isClosed valueList ->
      viewSequence maybeKey seqType isClosed valueList

    Record isClosed valueDict ->
      viewRecord maybeKey isClosed valueDict

    Constructor maybeName isClosed valueList ->
      let
        name =
          Maybe.withDefault "TUPLE" maybeName
      in
        div [ leftPad maybeKey ] (expando maybeKey Nothing name)


expando : Maybe String -> Maybe Bool -> String -> List (Node msg)
expando maybeKey maybeIsClosed description =
  let
    arrow =
      case maybeIsClosed of
        Nothing ->
          makeArrow ""

        Just True ->
          makeArrow "▸"

        Just False ->
          makeArrow "▾"

    info =
      case maybeKey of
        Nothing ->
          description

        Just key ->
          key ++ " = " ++ description
  in
    [ arrow, text (" " ++ info) ]


makeArrow arrow =
  span [ VirtualDom.style [("color", "#333"), ("width", "1em"), ("display", "inline-block")] ] [ text arrow ]


leftPad : Maybe a -> VirtualDom.Property msg
leftPad maybeKey =
  case maybeKey of
    Nothing ->
      VirtualDom.style []

    Just _ ->
      VirtualDom.style [("padding-left", "20px")]


div =
  VirtualDom.node "div"


span =
  VirtualDom.node "span"


onClick msg =
  VirtualDom.on "click" (Json.succeed msg)



-- VIEW SEQUENCE


viewSequence : Maybe String -> SeqType -> Bool -> List Value -> Node Msg
viewSequence maybeKey seqType isClosed valueList =
  let
    starter =
      seqTypeToString (List.length valueList) seqType
  in
    div [ leftPad maybeKey ]
      [ div [ onClick Toggle ] (expando maybeKey (Just isClosed) starter)
      , if isClosed then
          text ""

        else
          text "OPEN"
      ]



-- VIEW RECORD


viewRecord : Maybe String -> Bool -> Dict String Value -> Node Msg
viewRecord maybeKey isClosed record =
  div [ leftPad maybeKey ]
    [ div [ onClick Toggle ] (expando maybeKey (Just isClosed) ("Record " ++ viewTinyRecord record))
    , if isClosed then
        text ""

      else
        div [] (List.map viewRecordEntry (Dict.toList record))
    ]


viewRecordEntry : (String, Value) -> Node Msg
viewRecordEntry (key, value) =
  VirtualDom.map (Key key) (view (Just key) value)



-- TINY VIEW


viewTiny : Value -> String
viewTiny value =
  case value of
    Primitive stringRep ->
      stringRep

    Sequence seqType _ valueList ->
      seqTypeToString (List.length valueList) seqType

    Record _ record ->
      viewTinyRecord record

    Constructor maybeName _ valueList ->
      case maybeName of
        Nothing ->
          "Tuple (" ++ toString (List.length valueList) ++ ")"

        Just name ->
          if List.isEmpty valueList then name else name ++ " …"


viewTinyRecord : Dict String Value -> String
viewTinyRecord record =
  if Dict.isEmpty record then
    "{}"

  else
    viewTinyRecordHelp 4 "{ " (Dict.toList record) ++ " }"


viewTinyRecordHelp : Int -> String -> List (String, Value) -> String
viewTinyRecordHelp n starter entries =
  case entries of
    [] ->
      ""

    (key, value) :: rest ->
      if n == 0 then
        starter ++ "…"

      else
        starter ++ key ++ " = " ++ viewTiny value ++ viewTinyRecordHelp (n - 1) ", " rest