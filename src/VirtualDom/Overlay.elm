module VirtualDom.Overlay exposing
  ( State, none, corruptImport
  , Msg, update, assessImport
  , isBlocking
  , Config
  , view
  , viewImportExport
  )

import Json.Decode as Decode exposing ((:=))
import Json.Encode as Encode
import VirtualDom.Helpers exposing (..)
import VirtualDom.Metadata as Metadata exposing (Metadata)
import VirtualDom.Report as Report exposing (Report)



type State
  = None
  | BadImport Report
  | RiskyImport Report Encode.Value


none : State
none =
  None


corruptImport : State
corruptImport =
  BadImport Report.CorruptHistory


isBlocking : State -> Bool
isBlocking state =
  case state of
    None ->
      False

    _ ->
      True



--  UPDATE


type Msg = Cancel | Proceed


update : Msg -> State -> ( State, Maybe Encode.Value )
update msg state =
  (,) None <|
    case state of
      None ->
        Nothing

      BadImport _ ->
        Nothing

      RiskyImport _ rawHistory ->
        case msg of
          Cancel ->
            Nothing

          Proceed ->
            Just rawHistory


assessImport : Metadata -> String -> ( State, Maybe Encode.Value )
assessImport metadata jsonString =
  case Decode.decodeString uploadDecoder jsonString of
    Err _ ->
      ( corruptImport, Nothing )

    Ok (foreignMetadata, rawHistory) ->
      let
        report =
          Metadata.check foreignMetadata metadata
      in
        case Report.evaluate report of
          Report.Impossible ->
            ( BadImport report, Nothing )

          Report.Risky ->
            ( RiskyImport report rawHistory, Nothing )

          Report.Fine ->
            ( None, Just rawHistory )


uploadDecoder : Decode.Decoder (Metadata, Encode.Value)
uploadDecoder =
  Decode.object2 (,)
    ("metadata" := Metadata.decoder)
    ("history" := Decode.value)



-- VIEW


type alias Config msg =
  { blocked : msg
  , open : msg
  , importHistory : msg
  , exportHistory : msg
  , wrap : Msg -> msg
  }


view : Config msg -> Bool -> Bool -> Int -> State -> Node msg
view config isPaused isOpen numMsgs state =
  div [ class "elm-overlay" ] <| (::) styles <|
    case state of
      None ->
        if not isPaused then
          [ viewMiniControls config isOpen numMsgs
          ]

        else
          [ viewBlocker config.blocked
          , viewMiniControls config isOpen numMsgs
          ]

      BadImport report ->
        [ viewOverlay config "Cannot Import History" report (Accept "Ok")
        , viewMiniControls config isOpen numMsgs
        ]

      RiskyImport report _ ->
        [ viewOverlay config "Warning" report (Choose "Cancel Import" "Import Anyway")
        , viewMiniControls config isOpen numMsgs
        ]



-- VIEW MESSAGE


viewOverlay : Config msg -> String -> Report -> Buttons -> Node msg
viewOverlay config title report buttons =
  div [ class "elm-overlay-message" ]
    [ div [ class "elm-overlay-message-title" ] [ text title ]
    , div [ class "elm-overlay-message-details" ] (viewReport report)
    , map config.wrap <| viewButtons buttons
    ]


viewReport : Report -> List (Node msg)
viewReport report =
  case report of
    Report.CorruptHistory ->
      [ text "Looks like this history file is corrupt. I cannot understand it."
      ]

    Report.VersionChanged old new ->
      [ text <|
          "This history was created with Elm "
          ++ old ++ ", but you are using Elm "
          ++ new ++ " right now."
      ]

    Report.MessageChanged old new ->
      [ text <|
          "To import some other history, the overall message type must"
          ++ " be the same. The old history has "
      , viewCode old
      , text " messages, but the new program works with "
      , viewCode new
      , text " messages."
      ]

    Report.SomethingChanged changes ->
      [ node "ul" [] (List.map viewChange changes)
      ]


viewCode : String -> Node msg
viewCode name =
  node "code" [] [ text name ]


viewChange : Report.Change -> Node msg
viewChange change =
  node "li" [] <|
    case change of
      Report.AliasChange name ->
        [ node "h1" []
            [ text "Type alias "
            , viewCode name
            , text " changed."
            ]
        ]

      Report.UnionChange name { removed, changed, added, argsMatch } ->
        [ node "h1" []
            [ text "Type "
            , viewCode name
            , text " has changed."
            ]
        , node "ul" []
            [ viewMention removed "removed"
            , viewMention changed "changed"
            , viewMention added "added"
            ]
        , if argsMatch then
            text ""
          else
            text "This may be due to the fact that the type variable names changed."
        ]


viewMention : List String -> String -> Node msg
viewMention tags blanked =
  case List.map viewCode (List.reverse tags) of
    [] ->
      text ""

    [tag] ->
      node "li" []
        [ tag
        , text (" was " ++ blanked ++ ".")
        ]

    [tag2, tag1] ->
      node "li" []
        [ tag1
        , text " and "
        , tag2
        , text (" were " ++ blanked ++ ".")
        ]

    lastTag :: otherTags ->
      node "li" [] <|
        List.intersperse (text ", ") (List.reverse otherTags)
        ++ [ text ", and ", lastTag, text (" were " ++ blanked ++ ".") ]



-- VIEW MESSAGE BUTTONS


type Buttons
  = Accept String
  | Choose String String


viewButtons : Buttons -> Node Msg
viewButtons buttons =
  div [ class "elm-overlay-message-buttons" ] <|
    case buttons of
      Accept proceed ->
        [ node "button" [ onClick Proceed ] [ text proceed ]
        ]

      Choose cancel proceed ->
        [ node "button" [ onClick Cancel ] [ text cancel ]
        , node "button" [ onClick Proceed ] [ text proceed ]
        ]



-- VIEW MINI CONTROLS


viewMiniControls : Config msg -> Bool -> Int -> Node msg
viewMiniControls config isOpen numMsgs =
  if isOpen then
    text ""

  else
    div
      [ class "elm-mini-controls"
      ]
      [ div
          [ onClick config.open
          , class "elm-mini-controls-button"
          ]
          [ text ("Explore History (" ++ toString numMsgs ++ ")")
          ]
      , viewImportExport
          [class "elm-mini-controls-import-export"]
          config.importHistory
          config.exportHistory
      ]


viewImportExport : List (Property msg) -> msg -> msg -> Node msg
viewImportExport props importMsg exportMsg =
  div
    props
    [ button importMsg "Import"
    , text " / "
    , button exportMsg "Export"
    ]


button : msg -> String -> Node msg
button msg label =
  span [ onClick msg, style [("cursor","pointer")] ] [ text label ]



-- BLOCKER


viewBlocker : msg -> Node msg
viewBlocker blockedMsg =
  let
    block name =
      on name (Decode.succeed blockedMsg)
  in
    div (class "elm-blocker" :: List.map block tonsOfEvents) []


tonsOfEvents : List String
tonsOfEvents =
  [ "click", "dblclick", "mousemove"
  , "mouseup", "mousedown", "mouseenter", "mouseleave"
  , "touchstart", "touchend", "touchcancel", "touchmove"
  , "pointerdown", "pointerup", "pointerover", "pointerout"
  , "pointerenter", "pointerleave", "pointermove", "pointercancel"
  , "scroll"
  ]



-- STYLE


styles : Node msg
styles =
  node "style" [] [ text """

.elm-overlay {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  pointer-events: none;
}

.elm-blocker {
  position: absolute;
  width: 100%;
  height: 100%;
  pointer-events: auto;
}

.elm-mini-controls {
  position: fixed;
  bottom: 0;
  right: 6px;
  border-radius: 4px;
  color: white;
  background-color: rgb(61, 61, 61);
  font-family: monospace;
  pointer-events: auto;
}

.elm-mini-controls-button {
  padding: 6px;
  cursor: pointer;
  text-align: center;
  min-width: 22ch;
}

.elm-mini-controls-import-export {
  padding: 4px 0;
  font-size: 0.8em;
  text-align: center;
  background-color: rgb(50, 50, 50);
}

.elm-overlay-message {
  display: flex;
  flex-direction: column;
  max-height: 70%;
  width: 600px;
  margin: 0 auto;
  font-family: 'Trebuchet MS', 'Lucida Grande', 'Bitstream Vera Sans', 'Helvetica Neue', sans-serif;
  color: white;
  background-color: rgb(61, 61, 61);
  pointer-events: auto;
}

.elm-overlay-message-title {
  font-size: 2em;
  padding: 20px;
  background-color: rgb(50, 50, 50);
}

.elm-overlay-message-details {
  margin: 20px;
}

.elm-overlay-message-details h1 {
  font-weight: normal;
  font-size: 1.2em;
}

.elm-overlay-message-buttons {
  padding: 20px;
  background-color: rgb(50, 50, 50);
}

""" ]