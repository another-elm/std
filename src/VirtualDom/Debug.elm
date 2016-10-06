module VirtualDom.Debug exposing (wrap, wrapWithFlags)

import Json.Decode as Decode
import Json.Encode as Encode
import Native.Debug
import Native.VirtualDom
import Task exposing (Task)
import VirtualDom.Expando as Expando exposing (Expando)
import VirtualDom.Helpers as VDom exposing (Node)
import VirtualDom.History as History exposing (History)
import VirtualDom.Metadata as Metadata exposing (Metadata)
import VirtualDom.Overlay as Overlay
import VirtualDom.Report as Report



-- WRAP PROGRAMS


wrap metadata { init, update, subscriptions, view } =
  { init = wrapInit metadata init
  , view = wrapView view
  , update = wrapUpdate update
  , viewIn = viewIn
  , viewOut = viewOut
  , subscriptions = wrapSubs subscriptions
  }


wrapWithFlags metadata { init, update, subscriptions, view } =
  { init = \flags -> wrapInit metadata (init flags)
  , view = wrapView view
  , update = wrapUpdate update
  , viewIn = viewIn
  , viewOut = viewOut
  , subscriptions = wrapSubs subscriptions
  }



-- MODEL


type alias Model model msg =
  { history : History model msg
  , state : State model
  , expando : Expando
  , metadata : Result Metadata.Error Metadata
  , overlay : Overlay.State
  , isDebuggerOpen : Bool
  }


type State model
  = Running model
  | Paused Int model model


wrapInit : Encode.Value -> ( model, Cmd msg ) -> ( Model model msg, Cmd (Msg msg) )
wrapInit metadata ( userModel, userCommands ) =
  { history = History.empty userModel
  , state = Running userModel
  , expando = Expando.init userModel
  , metadata = Metadata.decode metadata
  , overlay = Overlay.none
  , isDebuggerOpen = False
  }
    ! [ Cmd.map UserMsg userCommands ]



-- UPDATE


type Msg msg
  = NoOp
  | UserMsg msg
  | ExpandoMsg Expando.Msg
  | Resume
  | Jump Int
  | Open
  | Close
  | Up
  | Down
  | Import
  | Export
  | Upload String
  | OverlayMsg Overlay.Msg


type alias UserUpdate model msg =
  msg -> model -> ( model, Cmd msg )


wrapUpdate
  : UserUpdate model msg
  -> Task Never ()
  -> Msg msg
  -> Model model msg
  -> (Model model msg, Cmd (Msg msg))
wrapUpdate userUpdate scrollTask msg model =
  case msg of
    NoOp ->
      model ! []

    UserMsg userMsg ->
      updateUserMsg userUpdate scrollTask userMsg model

    ExpandoMsg eMsg ->
      { model
          | expando = Expando.update eMsg model.expando
      }
        ! []

    Resume ->
      case model.state of
        Running _ ->
          model ! []

        Paused _ _ userModel ->
          { model
              | state = Running userModel
              , expando = Expando.merge userModel model.expando
          }
            ! [ runIf model.isDebuggerOpen scrollTask ]

    Jump index ->
      let
        (indexModel, indexMsg) =
          History.get userUpdate index model.history
      in
        { model
            | state = Paused index indexModel (getLatestModel model.state)
            , expando = Expando.merge indexModel model.expando
        }
          ! []

    Open ->
      { model | isDebuggerOpen = True } ! []

    Close ->
      { model | isDebuggerOpen = False } ! []

    Up ->
      let
        index =
          case model.state of
            Paused index _ _ ->
              index

            Running _ ->
              History.size model.history
      in
        if index > 0 then
          wrapUpdate userUpdate scrollTask (Jump (index - 1)) model
        else
          model ! []

    Down ->
      case model.state of
        Running _ ->
          model ! []

        Paused index _ userModel ->
          if index == History.size model.history - 1 then
            wrapUpdate userUpdate scrollTask Resume model
          else
            wrapUpdate userUpdate scrollTask (Jump (index + 1)) model

    Import ->
      withGoodMetadata model <| \_ ->
        model ! [ upload ]

    Export ->
      withGoodMetadata model <| \metadata ->
        model ! [ download metadata model.history ]

    Upload jsonString ->
      withGoodMetadata model <| \metadata ->
        case Overlay.assessImport metadata jsonString of
          Err newOverlay ->
            { model | overlay = newOverlay } ! []

          Ok rawHistory ->
            loadNewHistory rawHistory userUpdate model

    OverlayMsg overlayMsg ->
      case Overlay.close overlayMsg model.overlay of
        Nothing ->
          { model | overlay = Overlay.none } ! []

        Just rawHistory ->
          loadNewHistory rawHistory userUpdate model



-- COMMANDS


upload : Cmd (Msg msg)
upload =
  Task.perform Upload Native.Debug.upload


download : Metadata -> History model msg -> Cmd (Msg msg)
download metadata history =
  let
    historyLength =
      History.size history

    json =
      Encode.object
        [ ("metadata", Metadata.encode metadata)
        , ("history", History.encode history)
        ]
  in
    Task.perform (\_ -> NoOp) (Native.Debug.download historyLength json)



-- UPDATE OVERLAY


withGoodMetadata
  : Model model msg
  -> (Metadata -> (Model model msg, Cmd (Msg msg)))
  -> (Model model msg, Cmd (Msg msg))
withGoodMetadata model func =
  case model.metadata of
    Ok metadata ->
      func metadata

    Err error ->
      { model | overlay = Overlay.badMetadata error } ! []


loadNewHistory
  : Encode.Value
  -> UserUpdate model msg
  -> Model model msg
  -> ( Model model msg, Cmd (Msg msg) )
loadNewHistory rawHistory userUpdate model =
  let
    initialUserModel =
      History.initialModel model.history

    pureUserUpdate msg userModel =
      fst (userUpdate msg userModel)

    decoder =
      History.decoder initialUserModel pureUserUpdate
  in
    case Decode.decodeValue decoder rawHistory of
      Err _ ->
        { model | overlay = Overlay.corruptImport } ! []

      Ok (latestUserModel, newHistory) ->
        { model
            | history = newHistory
            , state = Running latestUserModel
            , expando = Expando.init latestUserModel
            , overlay = Overlay.none
        }
          ! []



-- UPDATE - USER MESSAGES


updateUserMsg
  : UserUpdate model msg
  -> Task Never ()
  -> msg
  -> Model model msg
  -> (Model model msg, Cmd (Msg msg))
updateUserMsg userUpdate scrollTask userMsg ({ history, state, expando } as model) =
  let
    userModel =
      getLatestModel state

    newHistory =
      History.add userMsg userModel history

    (newUserModel, userCmds) =
      userUpdate userMsg userModel

    commands =
      Cmd.map UserMsg userCmds
  in
    case state of
      Running _ ->
        { model
            | history = newHistory
            , state = Running newUserModel
            , expando = Expando.merge newUserModel expando
        }
          ! [ commands, runIf model.isDebuggerOpen scrollTask ]

      Paused index indexModel _ ->
        { model
            | history = newHistory
            , state = Paused index indexModel newUserModel
        }
          ! [ commands ]


runIf : Bool -> Task Never () -> Cmd (Msg msg)
runIf bool task =
  if bool then
    Task.perform (always NoOp) task
  else
    Cmd.none


getLatestModel : State model -> model
getLatestModel state =
  case state of
    Running model ->
      model

    Paused _ _ model ->
      model



-- SUBSCRIPTIONS


wrapSubs : (model -> Sub msg) -> Model model msg -> Sub (Msg msg)
wrapSubs userSubscriptions {state} =
  getLatestModel state
    |> userSubscriptions
    |> Sub.map UserMsg



-- VIEW


wrapView : (model -> Node msg) -> Model model msg -> Node (Msg msg)
wrapView userView { state, overlay } =
  let
    currentModel =
      case state of
        Running model ->
          model

        Paused _ oldModel _ ->
          oldModel

    userNode =
      VDom.map UserMsg (userView currentModel)
  in
    if Overlay.isBlocking overlay then
      VDom.div [gaussianBlur] [userNode]
    else
      userNode


gaussianBlur =
  VDom.style
    [ ("webkitFilter", "blur(2px)")
    , ("mozFilter", "blur(2px)")
    , ("msFilter", "blur(2px)")
    , ("filter", "blur(2px)")
    ]



-- SMALL DEBUG VIEW


viewIn : Model model msg -> Node (Msg msg)
viewIn { history, state, overlay, isDebuggerOpen } =
  let
    isPaused =
      case state of
        Running _ ->
          False

        Paused _ _ _ ->
          True
  in
    Overlay.view overlayConfig isPaused isDebuggerOpen (History.size history) overlay


overlayConfig : Overlay.Config (Msg msg)
overlayConfig =
  { blocked = NoOp
  , open = Open
  , importHistory = Import
  , exportHistory = Export
  , wrap = OverlayMsg
  }



-- BIG DEBUG VIEW


viewOut : Model model msg -> Node (Msg msg)
viewOut { history, state, expando } =
  VDom.div
    [ VDom.id "debugger" ]
    [ styles
    , viewMessages state history
    , VDom.map ExpandoMsg <|
        VDom.div [ VDom.id "values" ] [ Expando.view Nothing expando ]
    ]


viewMessages state history =
  let
    maybeIndex =
      case state of
        Running _ ->
          Nothing

        Paused index _ _ ->
          Just index
  in
    VDom.div [ VDom.class "debugger-sidebar" ]
      [ VDom.map Jump (History.view maybeIndex history)
      , playButton maybeIndex
      ]


playButton maybeIndex =
  VDom.div
    [ VDom.class "debugger-sidebar-controls"
    ]
    [ viewResumeButton maybeIndex
    , VDom.div
        [ VDom.style [("padding", "4px 0"), ("font-size","0.8em")]
        ]
        [ button Import "Import"
        , VDom.text " / "
        , button Export "Export"
        ]
    ]

button msg label =
  VDom.span
    [ VDom.onClick msg
    , VDom.style [("cursor","pointer")]
    ]
    [ VDom.text label ]

viewResumeButton maybeIndex =
  case maybeIndex of
    Nothing ->
      VDom.text ""

    Just _ ->
      resumeButton


resumeButton =
  VDom.div
    [ VDom.onClick Resume
    , VDom.style [("padding", "8px 0"), ("cursor", "pointer")]
    ]
    [ VDom.text "Resume"
    ]



-- STYLE


styles : Node msg
styles =
  VDom.node "style" [] [ VDom.text """

html {
    overflow: hidden;
    height: 100%;
}

body {
    height: 100%;
    overflow: auto;
}

#debugger {
  display: flex;
  font-family: monospace;
  height: 100%;
}

#values {
  height: 100%;
  width: 100%;
  margin: 0;
  overflow: scroll;
  cursor: default;
}

.debugger-sidebar {
  background-color: rgb(61, 61, 61);
  height: 100%;
  width: 240px;
  display: flex;
  flex-direction: column;
}

.debugger-sidebar-controls {
  background-color: rgb(50, 50, 50);
  width: 100%;
  color: white;
  text-align: center;
}

.debugger-sidebar-messages {
  width: 100%;
  overflow-y: scroll;
  flex: 1;
}

.messages-entry {
  cursor: pointer;
  color: white;
  width: 100%;
  padding: 4px 8px;
  text-overflow: ellipsis;
  white-space: nowrap;
  overflow: hidden;
}

.messages-entry:hover {
  background-color: rgb(41, 41, 41);
}

.messages-entry-selected, .messages-entry-selected:hover {
  background-color: rgb(10, 10, 10);
}
""" ]