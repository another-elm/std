module VirtualDom.Overlay exposing
  ( State, none, badImport
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
import VirtualDom.Report as Report



type State
  = None
  | BadImport (List String) (List String)
  | RiskyImport (List String) Encode.Value
--  | BadSwap (List String) (List String)
--  | RiskySwap (List String)


none : State
none =
  None


badImport : String -> State
badImport problem =
  BadImport [problem] []


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

      BadImport _ _ ->
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
      ( badImport "Looks like the history file has been corrupted."
      , Nothing
      )

    Ok (foreignMetadata, rawHistory) ->
      let
        { problems, warnings } =
          Metadata.check foreignMetadata metadata
      in
        if not (List.isEmpty problems) then
          ( BadImport problems warnings, Nothing )

        else if not (List.isEmpty warnings) then
          ( RiskyImport warnings rawHistory, Nothing )

        else
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

      BadImport problems warnings ->
        let
          details =
            List.concatMap viewMessages
              [ ("Problems", problems)
              , ("Warnings", warnings)
              ]
        in
          [ viewOverlay config "Cannot Import History" details (Accept "Ok")
          , viewMiniControls config isOpen numMsgs
          ]

      RiskyImport warnings _ ->
        [ viewOverlay
            config
            "Warning"
            [ ul [] (List.map viewMessage warnings) ]
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


viewMessages : ( String, List String ) -> List (Node msg)
viewMessages ( title, messages ) =
  if List.isEmpty messages then
    [ text "" ]

  else
    [ h1 [] [ text title ]
    , ul [] (List.map viewMessage messages)
    ]


viewMessage : String -> Node msg
viewMessage message =
  li [] [ text message ]


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