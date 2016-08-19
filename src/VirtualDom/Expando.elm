module VirtualDom.Expando exposing
  ( Expando
  , init
  , merge
  , Msg, update
  , view
  )


import Dict exposing (Dict)
import Json.Decode as Json
import Native.Debug
import String
import VirtualDom.Helpers as VDom exposing (Node, text, div, span, class, onClick)



-- MODEL


type Expando
  = S String
  | Primitive String
  | Sequence SeqType Bool (List Expando)
  | Dictionary Bool (List (Expando, Expando))
  | Record Bool (Dict String Expando)
  | Constructor (Maybe String) Bool (List Expando)


type SeqType = ListSeq | SetSeq | ArraySeq


seqTypeToString : Int -> SeqType -> String
seqTypeToString n seqType =
  case seqType of
    ListSeq ->
      "List(" ++ toString n ++ ")"

    SetSeq ->
      "Set(" ++ toString n ++ ")"

    ArraySeq ->
      "Array(" ++ toString n ++ ")"


init : a -> Expando
init =
  Native.Debug.init


merge : a -> Expando -> Expando
merge value expando =
  mergeHelp expando (init value)


mergeHelp : Expando -> Expando -> Expando
mergeHelp old new =
  case ( old, new ) of
    ( _, S _ ) ->
      new

    ( _, Primitive _ ) ->
      new

    ( Sequence _ isClosed oldValues, Sequence seqType _ newValues ) ->
      Sequence seqType isClosed (mergeListHelp oldValues newValues)

    ( Dictionary isClosed _, Dictionary _ keyValuePairs ) ->
      Dictionary isClosed keyValuePairs

    ( Record isClosed oldDict, Record _ newDict ) ->
      Record isClosed <| Dict.map (mergeDictHelp oldDict) newDict

    ( Constructor _ isClosed oldValues, Constructor maybeName _ newValues ) ->
      Constructor maybeName isClosed (mergeListHelp oldValues newValues)

    _ ->
      new


mergeListHelp : List Expando -> List Expando -> List Expando
mergeListHelp olds news =
  case (olds, news) of
    ( [], _ ) ->
      news

    ( _, [] ) ->
      news

    ( x :: xs, y :: ys ) ->
      mergeHelp x y :: mergeListHelp xs ys


mergeDictHelp : Dict String Expando -> String -> Expando -> Expando
mergeDictHelp oldDict key value =
  case Dict.get key oldDict of
    Nothing ->
      value

    Just oldValue ->
      mergeHelp oldValue value



-- UPDATE


type Msg
  = Toggle
  | Index Redirect Int Msg
  | Field String Msg


type Redirect = None | Key | Value


update : Msg -> Expando -> Expando
update msg value =
  case value of
    S _ ->
      Debug.crash "No messages for primitives"

    Primitive _ ->
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


updateField : Msg -> Maybe Expando -> Maybe Expando
updateField msg maybeExpando =
  case maybeExpando of
    Nothing ->
      Debug.crash "key does not exist"

    Just expando ->
      Just (update msg expando)



-- VIEW


view : Maybe String -> Expando -> Node Msg
view maybeKey expando =
  case expando of
    S stringRep ->
      div [ leftPad maybeKey ] (lineStarter maybeKey Nothing [span [red] [text stringRep]])

    Primitive stringRep ->
      div [ leftPad maybeKey ] (lineStarter maybeKey Nothing [span [blue] [text stringRep]])

    Sequence seqType isClosed valueList ->
      viewSequence maybeKey seqType isClosed valueList

    Dictionary isClosed keyValuePairs ->
      viewDictionary maybeKey isClosed keyValuePairs

    Record isClosed valueDict ->
      viewRecord maybeKey isClosed valueDict

    Constructor maybeName isClosed valueList ->
      viewConstructor maybeKey maybeName isClosed valueList


lineStarter : Maybe String -> Maybe Bool -> List (Node msg) -> List (Node msg)
lineStarter maybeKey maybeIsClosed description =
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
  span [ VDom.style [("color", "#777"), ("width", "2ch"), ("display", "inline-block")] ] [ text arrow ]


leftPad : Maybe a -> VDom.Property msg
leftPad maybeKey =
  case maybeKey of
    Nothing ->
      VDom.style []

    Just _ ->
      VDom.style [("padding-left", "2ch")]


red : VDom.Property msg
red =
  VDom.style [("color", "rgb(196, 26, 22)")]


blue : VDom.Property msg
blue =
  VDom.style [("color", "rgb(28, 0, 207)")]


purple : VDom.Property msg
purple =
  VDom.style [("color", "rgb(136, 19, 145)")]



-- VIEW SEQUENCE


viewSequence : Maybe String -> SeqType -> Bool -> List Expando -> Node Msg
viewSequence maybeKey seqType isClosed valueList =
  let
    starter =
      seqTypeToString (List.length valueList) seqType
  in
    div [ leftPad maybeKey ]
      [ div [ onClick Toggle ] (lineStarter maybeKey (Just isClosed) [text starter])
      , if isClosed then text "" else viewSequenceOpen valueList
      ]


viewSequenceOpen : List Expando -> Node Msg
viewSequenceOpen values =
  div [] (List.indexedMap viewConstructorEntry values)



-- VIEW DICTIONARY


viewDictionary : Maybe String -> Bool -> List (Expando, Expando) -> Node Msg
viewDictionary maybeKey isClosed keyValuePairs =
  let
    starter =
      "Dict(" ++ toString (List.length keyValuePairs) ++ ")"
  in
    div [ leftPad maybeKey ]
      [ div [ onClick Toggle ] (lineStarter maybeKey (Just isClosed) [text starter])
      , if isClosed then text "" else viewDictionaryOpen keyValuePairs
      ]


viewDictionaryOpen : List (Expando, Expando) -> Node Msg
viewDictionaryOpen keyValuePairs =
  div [] (List.indexedMap viewDictionaryEntry keyValuePairs)


viewDictionaryEntry : Int -> (Expando, Expando) -> Node Msg
viewDictionaryEntry index (key, value) =
  case key of
    S stringRep ->
      VDom.map (Index Value index) (view (Just stringRep) value)

    Primitive stringRep ->
      VDom.map (Index Value index) (view (Just stringRep) value)

    _ ->
        div []
          [ VDom.map (Index Key index) (view (Just "key") key)
          , VDom.map (Index Value index) (view (Just "value") value)
          ]



-- VIEW RECORD


viewRecord : Maybe String -> Bool -> Dict String Expando -> Node Msg
viewRecord maybeKey isClosed record =
  div [ leftPad maybeKey ]
    [ div [ onClick Toggle ] (lineStarter maybeKey (Just isClosed) (viewTinyRecord record))
    , if isClosed then text "" else viewRecordOpen record
    ]


viewRecordOpen : Dict String Expando -> Node Msg
viewRecordOpen record =
  div [] (List.map viewRecordEntry (Dict.toList record))


viewRecordEntry : (String, Expando) -> Node Msg
viewRecordEntry (field, value) =
  VDom.map (Field field) (view (Just field) value)



-- VIEW CONSTRUCTOR


viewConstructor : Maybe String -> Maybe String -> Bool -> List Expando -> Node Msg
viewConstructor maybeKey maybeName isClosed valueList =
  let
    tinyArgs =
      List.map viewExtraTiny valueList

    description =
      case (maybeName, tinyArgs) of
        (Nothing, []) ->
          [ text "()" ]

        (Nothing, x :: xs) ->
          text "( "
            :: span [] x
            :: List.foldr (\args rest -> text ", " :: span [] args :: rest) [text " )"] xs

        (Just name, []) ->
          [ text name ]

        (Just name, x :: xs) ->
          text (name ++ " ")
            :: span [] x
            :: List.foldr (\args rest -> text " " :: span [] args :: rest) [] xs

    (maybeIsClosed, openHtml) =
      case valueList of
        [] ->
          ( Nothing, div [] [] )

        [entry] ->
          case entry of
            S _ ->
              ( Nothing, div [] [] )

            Primitive _ ->
              ( Nothing, div [] [] )

            Sequence _ _ subValueList ->
              ( Just isClosed
              , if isClosed then div [] [] else VDom.map (Index None 0) (viewSequenceOpen subValueList)
              )

            Dictionary _ keyValuePairs ->
              ( Just isClosed
              , if isClosed then div [] [] else VDom.map (Index None 0) (viewDictionaryOpen keyValuePairs)
              )

            Record _ record ->
              ( Just isClosed
              , if isClosed then div [] [] else VDom.map (Index None 0) (viewRecordOpen record)
              )

            Constructor _ _ subValueList ->
              ( Just isClosed
              , if isClosed then div [] [] else VDom.map (Index None 0) (viewConstructorOpen subValueList)
              )

        _ ->
          ( Just isClosed
          , if isClosed then div [] [] else viewConstructorOpen valueList
          )
  in
    div [ leftPad maybeKey ]
      [ div [ onClick Toggle ] (lineStarter maybeKey maybeIsClosed description)
      , openHtml
      ]


viewConstructorOpen : List Expando -> Node Msg
viewConstructorOpen valueList =
  div [] (List.indexedMap viewConstructorEntry valueList)


viewConstructorEntry : Int -> Expando -> Node Msg
viewConstructorEntry index value =
  VDom.map (Index None index) (view (Just (toString index)) value)



-- TINY VIEW


viewTiny : Expando -> List (Node msg)
viewTiny value =
  case value of
    S stringRep ->
      [ span [red] [text stringRep] ]

    Primitive stringRep ->
      [ span [blue] [text stringRep] ]

    Sequence seqType _ valueList ->
      [ text (seqTypeToString (List.length valueList) seqType) ]

    Dictionary _ keyValuePairs ->
      [ text ("Dict(" ++ toString (List.length keyValuePairs) ++ ")") ]

    Record _ record ->
      viewTinyRecord record

    Constructor maybeName _ [] ->
      [ text (Maybe.withDefault "Unit" maybeName) ]

    Constructor maybeName _ valueList ->
      case maybeName of
        Nothing ->
          [ text ("Tuple(" ++ toString (List.length valueList) ++ ")") ]

        Just name ->
          [ text (name ++ " …") ]


viewTinyRecord : Dict String Expando -> List (Node msg)
viewTinyRecord record =
  if Dict.isEmpty record then
    [ text "{}" ]

  else
    viewTinyRecordHelp 4 "{ " (Dict.toList record)


viewTinyRecordHelp : Int -> String -> List (String, Expando) -> List (Node msg)
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


viewExtraTiny : Expando -> List (Node msg)
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


