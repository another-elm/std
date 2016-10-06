module VirtualDom.Overlay exposing
  ( State, none, corruptImport, badMetadata
  , Msg, close, assessImport
  , isBlocking
  , Config
  , view
  , viewImportExport
  )

import Json.Decode as Decode
import Json.Encode as Encode
import String
import VirtualDom.Helpers exposing (..)
import VirtualDom.Metadata as Metadata exposing (Metadata)
import VirtualDom.Report as Report exposing (Report)



type State
  = None
  | BadMetadata Metadata.Error
  | BadImport Report
  | RiskyImport Report Encode.Value


none : State
none =
  None


corruptImport : State
corruptImport =
  BadImport Report.CorruptHistory


badMetadata : Metadata.Error -> State
badMetadata =
  BadMetadata


isBlocking : State -> Bool
isBlocking state =
  case state of
    None ->
      False

    _ ->
      True



--  UPDATE


type Msg = Cancel | Proceed


close : Msg -> State -> Maybe Encode.Value
close msg state =
  case state of
    None ->
      Nothing

    BadMetadata _ ->
      Nothing

    BadImport _ ->
      Nothing

    RiskyImport _ rawHistory ->
      case msg of
        Cancel ->
          Nothing

        Proceed ->
          Just rawHistory


assessImport : Metadata -> String -> Result State Encode.Value
assessImport metadata jsonString =
  case Decode.decodeString uploadDecoder jsonString of
    Err _ ->
      Err corruptImport

    Ok (foreignMetadata, rawHistory) ->
      let
        report =
          Metadata.check foreignMetadata metadata
      in
        case Report.evaluate report of
          Report.Impossible ->
            Err (BadImport report)

          Report.Risky ->
            Err (RiskyImport report rawHistory)

          Report.Fine ->
            Ok rawHistory


uploadDecoder : Decode.Decoder (Metadata, Encode.Value)
uploadDecoder =
  Decode.map2 (,)
    (Decode.field "metadata" Metadata.decoder)
    (Decode.field "history" Decode.value)



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

      BadMetadata badMetadata ->
        [ viewOverlay
            config
            "Cannot use Import or Export"
            (viewBadMetadata badMetadata)
            (Accept "Ok")
        , viewMiniControls config isOpen numMsgs
        ]

      BadImport report ->
        [ viewOverlay
            config
            "Cannot Import History"
            (viewReport report)
            (Accept "Ok")
        , viewMiniControls config isOpen numMsgs
        ]

      RiskyImport report _ ->
        [ viewOverlay
            config
            "Warning"
            (viewReport report)
            (Choose "Cancel Import" "Import Anyway")
        , viewMiniControls config isOpen numMsgs
        ]



-- VIEW MESSAGE


viewOverlay : Config msg -> String -> List (Node msg) -> Buttons -> Node msg
viewOverlay config title details buttons =
  div [ class "elm-overlay-message" ]
    [ div [ class "elm-overlay-message-title" ] [ text title ]
    , div [ class "elm-overlay-message-details" ] details
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
        [ tag, text (" was " ++ blanked ++ ".") ]

    [tag2, tag1] ->
      node "li" []
        [ tag1, text " and ", tag2, text (" were " ++ blanked ++ ".") ]

    lastTag :: otherTags ->
      node "li" [] <|
        List.intersperse (text ", ") (List.reverse otherTags)
        ++ [ text ", and ", lastTag, text (" were " ++ blanked ++ ".") ]


viewBadMetadata : Metadata.Error -> List (Node msg)
viewBadMetadata {message, problems} =
  [ node "p" []
      [ text "The "
      , viewCode message
      , text " type of your program cannot be reliably serialized for history files."
      ]
  , node "p" [] [ text "Functions cannot be serialized, nor can values that contain functions. This is a problem in these places:" ]
  , node "ul" [] (List.map viewProblemType problems)
  , node "p" []
      [ text goodNews1
      , a [ href "https://guide.elm-lang.org/types/union_types.html" ] [ text "union types" ]
      , text ", in your messages. From there, your "
      , viewCode "update"
      , text goodNews2
      ]
  ]


goodNews1 = """
The good news is that having values like this in your message type is not
so great in the long run. You are better off using simpler data, like
"""


goodNews2 = """
function can pattern match on that data and call whatever functions, JSON
decoders, etc. you need. This makes the code much more explicit and easy to
follow for other readers (or you in a few months!)
"""


viewProblemType : Metadata.ProblemType -> Node msg
viewProblemType { name, problems } =
  node "li" []
    [ viewCode name
    , text (" can contain " ++ addCommas (List.map problemToString problems) ++ ".")
    ]


problemToString : Metadata.Problem -> String
problemToString problem =
  case problem of
    Metadata.Function ->
      "functions"

    Metadata.Decoder ->
      "JSON decoders"

    Metadata.Task ->
      "tasks"

    Metadata.Process ->
      "processes"

    Metadata.Socket ->
      "web sockets"

    Metadata.Request ->
      "HTTP requests"

    Metadata.Program ->
      "programs"

    Metadata.VirtualDom ->
      "virtual DOM values"


addCommas : List String -> String
addCommas items =
  case items of
    [] ->
      ""

    [item] ->
      item

    [item1, item2] ->
      item1 ++ " and " ++ item2

    lastItem :: otherItems ->
      String.join ", " (otherItems ++ [ " and " ++ lastItem ])



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