module VirtualDom.Expando exposing
  ( Value
  , init
  , Msg, update
  , view
  )


import Dict exposing (Dict)
import Json.Decode as Json
import Native.Debug
import String
import VirtualDom exposing (Node, text)



-- MODEL


type Value
  = Primitive String
  | Sequence SeqType Bool (List Value)
  | Dictionary Bool (List (Value, Value))
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
  | Index Redirect Int Msg
  | Field String Msg


type Redirect = None | Key | Value


update : Msg -> Value -> Value
update msg value =
  case value of
    Primitive stringRep ->
      Debug.crash "No messages for primitives"

    Sequence seqType isClosed valueList ->
      case msg of
        Toggle ->
          Sequence seqType (not isClosed) valueList

        Index None index subMsg ->
          Sequence seqType isClosed <|
            updateIndex index (update subMsg) valueList

        Index _ _ _ ->
          Debug.crash "No redirected indexes on sequences"

        Field _ _ ->
          Debug.crash "No field on sequences"

    Dictionary isClosed keyValuePairs ->
      case msg of
        Toggle ->
          Dictionary (not isClosed) keyValuePairs

        Index redirect index subMsg ->
          case redirect of
            None ->
              Debug.crash "must have redirect for dictionaries"

            Key ->
              Dictionary isClosed <|
                updateIndex index (\(k,v) -> (update subMsg k, v)) keyValuePairs

            Value ->
              Dictionary isClosed <|
                updateIndex index (\(k,v) -> (k, update subMsg v)) keyValuePairs

        Field _ _ ->
          Debug.crash "no field for dictionaries"

    Record isClosed valueDict ->
      case msg of
        Toggle ->
          Record (not isClosed) valueDict

        Index _ _ _ ->
          Debug.crash "No index for records"

        Field field subMsg ->
          Record isClosed (Dict.update field (updateField subMsg) valueDict)

    Constructor maybeName isClosed valueList ->
      case msg of
        Toggle ->
          Constructor maybeName (not isClosed) valueList

        Index None index subMsg ->
          Constructor maybeName isClosed <|
            updateIndex index (update subMsg) valueList

        Index _ _ _ ->
          Debug.crash "No redirected indexes on sequences"

        Field _ _ ->
          Debug.crash "No field for constructors"


updateIndex : Int -> (a -> a) -> List a -> List a
updateIndex n func list =
  case list of
    [] ->
      []

    x :: xs ->
      if n <= 0 then
        func x :: xs
      else
        x :: updateIndex (n-1) func xs


updateField : Msg -> Maybe Value -> Maybe Value
updateField msg maybeValue =
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
      div [ leftPad maybeKey ] (expando maybeKey Nothing [span [red] [text stringRep]])

    Sequence seqType isClosed valueList ->
      viewSequence maybeKey seqType isClosed valueList

    Dictionary isClosed keyValuePairs ->
      viewDictionary maybeKey isClosed keyValuePairs

    Record isClosed valueDict ->
      viewRecord maybeKey isClosed valueDict

    Constructor maybeName isClosed valueList ->
      viewConstructor maybeKey maybeName isClosed valueList


expando : Maybe String -> Maybe Bool -> List (Node msg) -> List (Node msg)
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
  in
    case maybeKey of
      Nothing ->
        arrow :: description

      Just key ->
        arrow :: span [purple] [text key] :: text " = " :: description


makeArrow arrow =
  span [ VirtualDom.style [("color", "#777"), ("width", "2ch"), ("display", "inline-block")] ] [ text arrow ]


leftPad : Maybe a -> VirtualDom.Property msg
leftPad maybeKey =
  case maybeKey of
    Nothing ->
      VirtualDom.style []

    Just _ ->
      VirtualDom.style [("padding-left", "2ch")]


div =
  VirtualDom.node "div"


span =
  VirtualDom.node "span"


onClick msg =
  VirtualDom.on "click" (Json.succeed msg)


red : VirtualDom.Property msg
red =
  VirtualDom.style [("color", "rgb(196, 26, 22)")]


purple : VirtualDom.Property msg
purple =
  VirtualDom.style [("color", "rgb(136, 19, 145)")]



-- VIEW SEQUENCE


viewSequence : Maybe String -> SeqType -> Bool -> List Value -> Node Msg
viewSequence maybeKey seqType isClosed valueList =
  let
    starter =
      seqTypeToString (List.length valueList) seqType
  in
    div [ leftPad maybeKey ]
      [ div [ onClick Toggle ] (expando maybeKey (Just isClosed) [text starter])
      , if isClosed then text "" else viewSequenceOpen valueList
      ]


viewSequenceOpen : List Value -> Node Msg
viewSequenceOpen values =
  div [] (List.indexedMap viewConstructorEntry values)



-- VIEW DICTIONARY


viewDictionary : Maybe String -> Bool -> List (Value, Value) -> Node Msg
viewDictionary maybeKey isClosed keyValuePairs =
  let
    starter =
      "Dict (" ++ toString (List.length keyValuePairs) ++ ")"
  in
    div [ leftPad maybeKey ]
      [ div [ onClick Toggle ] (expando maybeKey (Just isClosed) [text starter])
      , if isClosed then text "" else viewDictionaryOpen keyValuePairs
      ]


viewDictionaryOpen : List (Value, Value) -> Node Msg
viewDictionaryOpen keyValuePairs =
  div [] (List.indexedMap viewDictionaryEntry keyValuePairs)


viewDictionaryEntry : Int -> (Value, Value) -> Node Msg
viewDictionaryEntry index (key, value) =
  case key of
    Primitive stringRep ->
      VirtualDom.map (Index Value index) (view (Just stringRep) value)

    _ ->
        div []
          [ VirtualDom.map (Index Key index) (view (Just "key") key)
          , VirtualDom.map (Index Value index) (view (Just "value") value)
          ]



-- VIEW RECORD


viewRecord : Maybe String -> Bool -> Dict String Value -> Node Msg
viewRecord maybeKey isClosed record =
  div [ leftPad maybeKey ]
    [ div [ onClick Toggle ] (expando maybeKey (Just isClosed) (viewTinyRecord record))
    , if isClosed then text "" else viewRecordOpen record
    ]


viewRecordOpen : Dict String Value -> Node Msg
viewRecordOpen record =
  div [] (List.map viewRecordEntry (Dict.toList record))


viewRecordEntry : (String, Value) -> Node Msg
viewRecordEntry (field, value) =
  VirtualDom.map (Field field) (view (Just field) value)



-- VIEW CONSTRUCTOR


viewConstructor : Maybe String -> Maybe String -> Bool -> List Value -> Node Msg
viewConstructor maybeKey maybeName isClosed valueList =
  let
    tinyArgs =
      List.map viewExtraTiny valueList

    description =
      case maybeName of
        Nothing ->
          text "( " ::
            List.foldr (\args rest -> span [] args :: text ", " :: rest) [text " )"] tinyArgs

        Just name ->
          text (name ++ " ") ::
            List.foldr (\args rest -> span [] args :: text " " :: rest) [] tinyArgs

    (maybeIsClosed, openHtml) =
      case valueList of
        [] ->
          ( Nothing, div [] [] )

        [entry] ->
          case entry of
            Primitive _ ->
              ( Nothing, div [] [] )

            Sequence _ _ subValueList ->
              ( Just isClosed
              , if isClosed then div [] [] else VirtualDom.map (Index None 0) (viewSequenceOpen subValueList)
              )

            Dictionary _ keyValuePairs ->
              ( Just isClosed
              , if isClosed then div [] [] else VirtualDom.map (Index None 0) (viewDictionaryOpen keyValuePairs)
              )

            Record _ record ->
              ( Just isClosed
              , if isClosed then div [] [] else VirtualDom.map (Index None 0) (viewRecordOpen record)
              )

            Constructor _ _ subValueList ->
              ( Just isClosed
              , if isClosed then div [] [] else VirtualDom.map (Index None 0) (viewConstructorOpen subValueList)
              )

        _ ->
          ( Just isClosed
          , if isClosed then div [] [] else viewConstructorOpen valueList
          )
  in
    div [ leftPad maybeKey ]
      [ div [ onClick Toggle ] (expando maybeKey maybeIsClosed description)
      , openHtml
      ]


viewConstructorOpen : List Value -> Node Msg
viewConstructorOpen valueList =
  div [] (List.indexedMap viewConstructorEntry valueList)


viewConstructorEntry : Int -> Value -> Node Msg
viewConstructorEntry index value =
  VirtualDom.map (Index None index) (view (Just (toString index)) value)



-- TINY VIEW


viewTiny : Value -> List (Node msg)
viewTiny value =
  case value of
    Primitive stringRep ->
      [ span [red] [text stringRep] ]

    Sequence seqType _ valueList ->
      [ text (seqTypeToString (List.length valueList) seqType) ]

    Dictionary _ keyValuePairs ->
      [ text ("Dict (" ++ toString (List.length keyValuePairs) ++ ")") ]

    Record _ record ->
      viewTinyRecord record

    Constructor maybeName _ [] ->
      [ text (Maybe.withDefault "Unit" maybeName) ]

    Constructor maybeName _ valueList ->
      case maybeName of
        Nothing ->
          [ text ("Tuple (" ++ toString (List.length valueList) ++ ")") ]

        Just name ->
          [ text (name ++ " …") ]


viewTinyRecord : Dict String Value -> List (Node msg)
viewTinyRecord record =
  if Dict.isEmpty record then
    [ text "{}" ]

  else
    viewTinyRecordHelp 4 "{ " (Dict.toList record)


viewTinyRecordHelp : Int -> String -> List (String, Value) -> List (Node msg)
viewTinyRecordHelp n starter entries =
  case entries of
    [] ->
      [ text " }" ]

    (field, value) :: rest ->
      if n == 0 then
        [ text ", … }" ]

      else
        text starter
        :: span [purple] [text field]
        :: text " = "
        :: span [] (viewExtraTiny value)
        :: viewTinyRecordHelp (n - 1) ", " rest


viewExtraTiny : Value -> List (Node msg)
viewExtraTiny value =
  case value of
    Record _ record ->
      viewExtraTinyRecord 4 "{" (Dict.keys record)

    _ ->
      viewTiny value


viewExtraTinyRecord : Int -> String -> List String -> List (Node msg)
viewExtraTinyRecord n starter entries =
  case entries of
    [] ->
      [ text "}" ]

    field :: rest ->
      if n == 0 then
        [ text "…}" ]

      else
        text starter
        :: span [purple] [text field]
        :: viewExtraTinyRecord (n - 1) "," rest


