module Platform exposing
  ( Program, worker
  , Task(..), ProcessId(..)
  , Router, sendToApp, sendToSelf
  )

{-|

# Programs
@docs Program, worker

# Platform Internals

## Tasks and Processes
@docs Task, ProcessId

## Effect Manager Helpers

An extremely tiny portion of library authors should ever write effect managers.
Fundamentally, Elm needs maybe 10 of them total. I get that people are smart,
curious, etc. but that is not a substitute for a legitimate reason to make an
effect manager. Do you have an *organic need* this fills? Or are you just
curious? Public discussions of your explorations should be framed accordingly.

@docs Router, sendToApp, sendToSelf

## Unresolve questions

* Each app has a dict of effect managers, it also has a dict of "managers".
  I have called these `OtherManagers` but what do they do and how shouuld they be named?

-}

import Basics exposing (..)
import List exposing ((::))
import Maybe exposing (Maybe(..))
import Result exposing (Result(..))
import String exposing (String)
import Char exposing (Char)
import Tuple

import Debug

import Platform.Cmd as Cmd exposing ( Cmd )
import Platform.Sub as Sub exposing ( Sub )

import Elm.Kernel.Basics
import Elm.Kernel.Platform
import Platform.Bag as Bag
-- import Json.Decode exposing (Decoder)
-- import Json.Encode as Encode
import Dict exposing (Dict)
import Platform.RawScheduler as RawScheduler


type Decoder flags = Decoder (Decoder flags)
type EncodeValue = EncodeValue EncodeValue

-- PROGRAMS


{-| A `Program` describes an Elm program! How does it react to input? Does it
show anything on screen? Etc.
-}
type Program flags model msg =
  Program
    ((Decoder flags) ->
      DebugMetadata ->
      RawJsObject { args: Maybe (RawJsObject flags) } ->
      RawJsObject
        { ports : RawJsObject
          { outgoingPortName: OutgoingPort
          , incomingPortName: IncomingPort
          }
        }
    )

{-| Create a [headless][] program with no user interface.

This is great if you want to use Elm as the &ldquo;brain&rdquo; for something
else. For example, you could send messages out ports to modify the DOM, but do
all the complex logic in Elm.

[headless]: https://en.wikipedia.org/wiki/Headless_software

Initializing a headless program from JavaScript looks like this:

```javascript
var app = Elm.MyThing.init();
```

If you _do_ want to control the user interface in Elm, the [`Browser`][browser]
module has a few ways to create that kind of `Program` instead!

[headless]: https://en.wikipedia.org/wiki/Headless_software
[browser]: /packages/elm/browser/latest/Browser
-}
worker
  : { init : flags -> ( model, Cmd msg )
    , update : msg -> model -> ( model, Cmd msg )
    , subscriptions : model -> Sub msg
    }
  -> Program flags model msg
worker impl =
  makeProgramCallable
    (Program
      (\flagsDecoder _ args ->
        initialize
          flagsDecoder
          args
          impl
          { stepperBuilder = \ _ _ -> (\ _ _ -> ())
          , setupOutgoingPort =  setupOutgoingPort
          , setupIncomingPort = setupIncomingPort
          , setupEffects = hiddenSetupEffects
          , dispatchEffects = dispatchEffects
          }
      )
    )




-- TASKS and PROCESSES


{-| Head over to the documentation for the [`Task`](Task) module for more
information on this. It is only defined here because it is a platform
primitive.
-}
type Task err ok
    = Task
      (RawScheduler.Task (Result err ok))


{-| Head over to the documentation for the [`Process`](Process) module for
information on this. It is only defined here because it is a platform
primitive.
-}
type ProcessId =
  ProcessId
    (RawScheduler.ProcessId Never)



-- EFFECT MANAGER INTERNALS


{-| An effect manager has access to a “router” that routes messages between
the main app and your individual effect manager.
-}
type Router appMsg selfMsg =
  Router
  { sendToApp: appMsg -> ()
  , selfProcess: RawScheduler.ProcessId selfMsg
  }

{-| Send the router a message for the main loop of your app. This message will
be handled by the overall `update` function, just like events from `Html`.
-}
sendToApp : Router msg a -> msg -> Task x ()
sendToApp (Router router) msg =
  Task
    (RawScheduler.SyncAction
      (\() ->
        let
          _ =
            router.sendToApp msg
        in
        RawScheduler.Value (Ok ())
      )
    )


{-| Send the router a message for your effect manager. This message will
be routed to the `onSelfMsg` function, where you can update the state of your
effect manager as necessary.

As an example, the effect manager for web sockets
-}
sendToSelf : Router a msg -> msg -> Task x ()
sendToSelf (Router router) msg =
  Task
    (RawScheduler.andThen
      (\() -> RawScheduler.Value (Ok ()))
      (RawScheduler.send
        router.selfProcess
        msg
      )
    )


setupOutgoingPort : SendToApp msg -> (EncodeValue -> ()) -> RawScheduler.ProcessId (ReceivedData msg Never)
setupOutgoingPort sendToApp2 outgoingPortSend =
  let
    init =
      Task (RawScheduler.Value (Ok ()))

    onSelfMsg _ selfMsg () =
      never selfMsg

    execInOrder : List EncodeValue -> RawScheduler.Task (Result Never ())
    execInOrder cmdList =
      case cmdList of
        first :: rest ->
          RawScheduler.SyncAction (\() ->
            let
                _ = outgoingPortSend first
            in
              execInOrder rest
          )

        _ ->
          RawScheduler.Value (Ok ())

    onEffects : Router msg selfMsg
      -> List (HiddenMyCmd msg)
      -> List (HiddenMySub msg)
      -> ()
      -> Task Never ()
    onEffects _ cmdList _ () =
      let
        typedCmdList : List EncodeValue
        typedCmdList =
          Elm.Kernel.Basics.fudgeType cmdList
      in
      Task (execInOrder typedCmdList)

  in
  instantiateEffectManager sendToApp2 init onEffects onSelfMsg


setupIncomingPort : SendToApp msg -> (List (HiddenMySub msg) -> ()) -> (RawScheduler.ProcessId (ReceivedData msg Never), msg -> List (HiddenMySub msg) -> ())
setupIncomingPort sendToApp2 updateSubs =
  let
    init =
      Task (RawScheduler.Value (Ok ()))

    onSelfMsg _ selfMsg () =
      never selfMsg

    onEffects _ _ subList () =
      Task
        (RawScheduler.SyncAction
          (\() ->
            let
                _ = updateSubs subList
            in
              RawScheduler.Value (Ok ())
          )
        )

    onSend : msg -> List (HiddenMySub msg) -> ()
    onSend value subs =
      let
          typedSubs : List (msg -> msg)
          typedSubs =
            Elm.Kernel.Basics.fudgeType subs
      in

      List.foldr
        (\sub () -> sendToApp2 (sub value) AsyncUpdate)
        ()
        typedSubs

    typedSubMap : (msg1 -> msg2) -> (a -> msg1) -> (a -> msg2)
    typedSubMap tagger finalTagger =
      (\val -> tagger (finalTagger val))

    subMap : (HiddenTypeA -> HiddenTypeB) -> HiddenMySub HiddenTypeA -> HiddenMySub HiddenTypeB
    subMap tagger finalTagger =
      Elm.Kernel.Basics.fudgeType typedSubMap
  in
  ( instantiateEffectManager sendToApp2 init onEffects onSelfMsg
  , onSend
  )



-- -- HELPERS --

dispatchEffects : Cmd appMsg
  -> Sub appMsg
  -> Bag.EffectManagerName
  -> RawScheduler.ProcessId (ReceivedData appMsg HiddenSelfMsg)
  -> ()
dispatchEffects cmd sub =
  let
    effectsDict =
      Dict.empty
        |> gatherCmds cmd
        |> gatherSubs sub
  in
    \key selfProcess->
      let
          (cmdList, subList) =
            Maybe.withDefault
              ([], [])
              (Dict.get (effectManagerNameToString key) effectsDict)


          _ =
            RawScheduler.rawSend
              selfProcess
              (App (Elm.Kernel.Basics.fudgeType cmdList) (Elm.Kernel.Basics.fudgeType subList))
      in
        ()


gatherCmds : Cmd msg -> Dict String (List (Bag.LeafType msg), List (Bag.LeafType msg)) -> Dict String (List (Bag.LeafType msg), List (Bag.LeafType msg))
gatherCmds (Cmd.Data cmds) effectsDict =
  List.foldr
    (\{home, value} dict -> gatherHelper True home value dict)
    effectsDict
    cmds


gatherSubs : Sub msg -> Dict String (List (Bag.LeafType msg), List (Bag.LeafType msg)) -> Dict String (List (Bag.LeafType msg), List (Bag.LeafType msg))
gatherSubs (Sub.Data subs) effectsDict =
  List.foldr
    (\{home, value} dict -> gatherHelper False home value dict)
    effectsDict
    subs


gatherHelper : Bool -> Bag.EffectManagerName -> Bag.LeafType msg -> Dict String (List (Bag.LeafType msg), List (Bag.LeafType msg)) -> Dict String (List (Bag.LeafType msg), List (Bag.LeafType msg))
gatherHelper isCmd home value effectsDict =
  let
    effect =
      (Elm.Kernel.Basics.fudgeType value)
  in
    Dict.insert
      (effectManagerNameToString home)
      (createEffect isCmd effect (Dict.get (effectManagerNameToString home) effectsDict))
      effectsDict


createEffect : Bool -> Bag.LeafType msg -> Maybe (List (Bag.LeafType msg), List (Bag.LeafType msg)) -> (List (Bag.LeafType msg), List (Bag.LeafType msg))
createEffect isCmd newEffect maybeEffects =
  let
    (cmdList, subList) =
      case maybeEffects of
        Just effects -> effects
        Nothing -> ([], [])
  in
  if isCmd then
    (newEffect :: cmdList, subList)
  else
    (cmdList, newEffect :: subList)


setupEffects : SetupEffects state appMsg selfMsg
setupEffects sendToAppP init onEffects onSelfMsg =
  instantiateEffectManager sendToAppP init onEffects onSelfMsg


hiddenSetupEffects : SetupEffects HiddenState appMsg HiddenSelfMsg
hiddenSetupEffects =
  Elm.Kernel.Basics.fudgeType setupEffects


instantiateEffectManager : SendToApp appMsg
  -> Task Never state
  -> (Router appMsg selfMsg -> List (HiddenMyCmd appMsg) -> List (HiddenMySub appMsg) -> state -> Task Never state)
  -> (Router appMsg selfMsg -> selfMsg -> state -> Task Never state)
  -> RawScheduler.ProcessId (ReceivedData appMsg selfMsg)
instantiateEffectManager sendToAppFunc (Task init) onEffects onSelfMsg =
  let
    receiver msg state =
      let
        (Task task) =
          case msg of
            Self value ->
              onSelfMsg router value state

            App cmds subs ->
              onEffects router cmds subs state
      in
        RawScheduler.andThen
          (\res ->
            case res of
              Ok val ->
                RawScheduler.andThen
                  (\() -> RawScheduler.Value val)
                  (RawScheduler.sleep 0)
              Err e -> never e
          )
          task


    selfProcess =
      RawScheduler.rawSpawn (
        RawScheduler.andThen
          (\() -> init)
          (RawScheduler.sleep 0)
      )


    router =
      Router
        { sendToApp = (\appMsg -> sendToAppFunc appMsg AsyncUpdate)
        , selfProcess = selfProcess
        }
  in
  RawScheduler.rawSetReceiver selfProcess receiver


type alias SendToApp msg =
  msg -> UpdateMetadata -> ()


type alias StepperBuilder model msg =
  SendToApp msg -> model -> (SendToApp msg)


type alias DebugMetadata = EncodeValue


{-| AsyncUpdate is default I think

TODO(harry) understand this by reading source of VirtualDom
-}
type UpdateMetadata
  = SyncUpdate
  | AsyncUpdate


type OtherManagers appMsg =
  OtherManagers (Dict String (RawScheduler.ProcessId (ReceivedData appMsg HiddenSelfMsg)))


type ReceivedData appMsg selfMsg
  = Self selfMsg
  | App (List (HiddenMyCmd appMsg)) (List (HiddenMySub appMsg))


type EffectManager state appMsg selfMsg
  = EffectManager
    { onSelfMsg : Router appMsg selfMsg -> selfMsg -> state -> Task Never state
    , init : Task Never state
    , onEffects: Router appMsg selfMsg -> List (HiddenMyCmd appMsg) -> List (HiddenMySub appMsg) -> state -> Task Never state
    , cmdMap : (HiddenTypeA -> HiddenTypeB) -> HiddenMyCmd HiddenTypeA -> HiddenMyCmd HiddenTypeB
    , subMap : (HiddenTypeA -> HiddenTypeB) -> HiddenMySub HiddenTypeA -> HiddenMySub HiddenTypeB
    , selfProcess: RawScheduler.ProcessId (ReceivedData appMsg selfMsg)
    }


type OutgoingPort =
  OutgoingPort
    { subscribe: (EncodeValue -> ())
    , unsubscribe: (EncodeValue -> ())
    }


type IncomingPort =
  IncomingPort
    { send: (EncodeValue -> ())
    }

type HiddenTypeA
  = HiddenTypeA Never

type HiddenTypeB
  = HiddenTypeB Never


type HiddenMyCmd msg = HiddenMyCmd (Bag.LeafType msg)


type HiddenMySub msg = HiddenMySub (Bag.LeafType msg)


type HiddenSelfMsg = HiddenSelfMsg HiddenSelfMsg


type HiddenState = HiddenState HiddenState


type RawJsObject record
  = JsRecord (RawJsObject record)
  | JsAny


type alias Impl flags model msg =
  { init : flags -> ( model, Cmd msg )
  , update : msg -> model -> ( model, Cmd msg )
  , subscriptions : model -> Sub msg
  }


type alias SetupEffects state appMsg selfMsg =
  SendToApp appMsg
    -> Task Never state
    -> (Router appMsg selfMsg -> List (HiddenMyCmd appMsg) -> List (HiddenMySub appMsg) -> state -> Task Never state)
    -> (Router appMsg selfMsg -> selfMsg -> state -> Task Never state)
    -> RawScheduler.ProcessId (ReceivedData appMsg selfMsg)


type alias InitFunctions model appMsg =
  { stepperBuilder : SendToApp appMsg -> model -> (SendToApp appMsg)
  , setupOutgoingPort : SendToApp appMsg ->  (EncodeValue -> ()) -> RawScheduler.ProcessId (ReceivedData appMsg Never)
  , setupIncomingPort : SendToApp appMsg -> (List (HiddenMySub appMsg) -> ()) -> (RawScheduler.ProcessId (ReceivedData appMsg Never), appMsg -> List (HiddenMySub appMsg) -> ())
  , setupEffects : SetupEffects HiddenState appMsg HiddenSelfMsg
  , dispatchEffects : Cmd appMsg -> Sub appMsg -> Bag.EffectManagerName -> RawScheduler.ProcessId (ReceivedData appMsg HiddenSelfMsg) -> ()
  }

-- kernel --

initialize :
    Decoder flags ->
    RawJsObject { args: Maybe (RawJsObject flags) } ->
    Impl flags model msg ->
    InitFunctions model msg ->
    RawJsObject
      { ports : RawJsObject
        { outgoingPortName: OutgoingPort
        , incomingPortName: IncomingPort
        }
      }
initialize =
  Elm.Kernel.Platform.initialize


makeProgramCallable :  Program flags model msg -> Program flags model msg
makeProgramCallable (Program program) =
  Elm.Kernel.Basics.fudgeType program


effectManagerNameToString : Bag.EffectManagerName -> String
effectManagerNameToString =
  Elm.Kernel.Platform.effectManagerNameToString
