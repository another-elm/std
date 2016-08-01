module VirtualDom.Debug exposing (program)
{-|
@docs program
-}

import Json.Decode as Json
import Native.VirtualDom
import VirtualDom as VDom exposing (Node)
import VirtualDom.Expando as Expando
import VirtualDom.History as History exposing (History)



-- PROGRAMS


{-|-}
program
  : { init : (model, Cmd msg)
    , update : msg -> model -> (model, Cmd msg)
    , subscriptions : model -> Sub msg
    , view : model -> Node msg
    }
  -> Program Never (State model msg) (Msg msg)
program { init, update, subscriptions, view } =
  Native.VirtualDom.debug
    { init = wrapInit init
    , view = wrapView view
    , update = wrapUpdate update
    , viewIn = viewIn
    , viewOut = viewOut
    , subscriptions = wrapSubs subscriptions
    }



-- MODEL


type alias State model msg =
  { userModel : model
  , history : History model msg
  , debugState : DebugState
  }


type DebugState
  = Latest Expando.Value
  | At Int Expando.Value


wrapInit : ( model, Cmd msg ) -> ( State model msg, Cmd (Msg msg) )
wrapInit ( model, cmds ) =
  ( State model (History.empty model) (Latest (Expando.init model))
  , Cmd.map (UserMsg (Just 0)) cmds
  )



-- UPDATE


type Msg msg
  = UserMsg (Maybe Int) msg
  | DebugMsg Expando.Msg
  | Jump Int


wrapUpdate
  : (msg -> model -> (model, Cmd msg))
  -> Msg msg
  -> State model msg
  -> (State model msg, Cmd (Msg msg))
wrapUpdate userUpdate msg { userModel, history, debugState } =
  case msg of
    UserMsg _ userMsg ->
      let
        newHistory =
          History.add userMsg userModel history

        index =
          History.size newHistory

        (newUserModel, cmds) =
          userUpdate userMsg userModel

        newDebugState =
          case debugState of
            Latest _ ->
              Latest (Expando.init newUserModel)

            At _ _ ->
              debugState
      in
        ( State newUserModel newHistory newDebugState
        , Cmd.map (UserMsg (Just index)) cmds
        )

    DebugMsg debugMsg ->
      let
        newDebugState =
          case debugState of
            Latest value ->
              Latest (Expando.update debugMsg value)

            At index value ->
              At index (Expando.update debugMsg value)
      in
        ( State userModel history newDebugState
        , Cmd.none
        )

    Jump index ->
      let
        (model, msg) =
          History.get userUpdate index history
      in
        ( State userModel history (At index (Expando.init model))
        , Cmd.none
        )



-- SUBSCRIPTIONS


wrapSubs : (model -> Sub msg) -> State model msg -> Sub (Msg msg)
wrapSubs userSubscriptions { userModel } =
  Sub.map toMsg (userSubscriptions userModel)



-- VIEW


wrapView : (model -> Node msg) -> State model msg -> Node (Msg msg)
wrapView userView { userModel, history } =
  VDom.map toMsg (userView userModel)


toMsg : msg -> Msg msg
toMsg =
  UserMsg Nothing



-- DEBUG VIEW


viewIn : State model msg -> Node ()
viewIn { userModel, history, debugState } =
  div
    [ VDom.on "click" (Json.succeed ())
    , VDom.style
        [ ("width", "40px")
        , ("height", "40px")
        , ("borderRadius", "50%")
        , ("position", "absolute")
        , ("bottom", "0")
        , ("right", "0")
        , ("margin", "10px")
        , ("backgroundColor", "#60B5CC")
        , ("color", "white")
        , ("display", "flex")
        , ("justify-content", "center")
        , ("align-items", "center")
        ]
    ]
    [ VDom.text (toString (History.size history))
    ]


viewOut : State model msg -> Node (Msg msg)
viewOut { userModel, history, debugState } =
  let
    (currentIndex, currentValue) =
      case debugState of
        Latest value ->
          (-1, value)

        At index value ->
          (index, value)
  in
    div
      [ VDom.attribute "id" "debugger" ]
      [ styles
      , VDom.map Jump (History.view currentIndex history)
      , VDom.map DebugMsg <|
          div [ VDom.attribute "id" "values" ] [ Expando.view Nothing currentValue ]
      ]


div =
  VDom.node "div"


id =
  VDom.attribute "id"



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
}

#values {
  background-color: rgb(230, 230, 230);
  height: 100%;
  width: 100%;
  margin: 0;
  overflow: scroll;
}

#messages {
  background-color: rgb(61, 61, 61);
  height: 100%;
  width: 300px;
  margin: 0;
  overflow-y: scroll;
}

.messages-entry {
  cursor: pointer;
  color: white;
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