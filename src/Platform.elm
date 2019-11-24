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

* Each app has a dict of effect mangers, it also has a dict of "mangers".
  I have called these `OtherMangers` but what do they do and how shouuld they be named?

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

import Elm.Kernel.Platform
import Platform.Bag as Bag
import Json.Decode exposing (Decoder)
import Json.Encode as Encode
import Dict exposing (Dict)
import Platform.RawScheduler as RawScheduler

-- PROGRAMS


{-| A `Program` describes an Elm program! How does it react to input? Does it
show anything on screen? Etc.
-}
type Program flags model msg =
  Program ((Decoder flags) -> DebugMetadata -> flags -> { ports: Encode.Value })


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
  Program
    (\flagsDecoder _ flags ->
      initialize
        flagsDecoder
        flags
        impl
        (StepperBuilder (\ _ _ -> SendToApp (\ _ _ -> ())))
    )



-- TASKS and PROCESSES


{-| Head over to the documentation for the [`Task`](Task) module for more
information on this. It is only defined here because it is a platform
primitive.
-}
type Task err ok
    = Task (RawScheduler.Task (Result err ok))

{-| Head over to the documentation for the [`Process`](Process) module for
information on this. It is only defined here because it is a platform
primitive.
-}
type ProcessId =
  ProcessId (RawScheduler.ProcessId Never)



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
    (RawScheduler.binding
      (\doneCallback ->
        let
          _ =
            router.sendToApp msg
        in
          let
              _ =
                doneCallback (RawScheduler.Value (Ok ()))
          in
            (\() -> ())
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



-- HELPERS --

initialize : Decoder flags -> flags -> { init : flags -> ( model, Cmd msg )
    , update : msg -> model -> ( model, Cmd msg )
    , subscriptions : model -> Sub msg
    } -> StepperBuilder model msg -> { ports : Encode.Value }
initialize flagDecoder flags { init, update, subscriptions } stepperBuilder =
  Debug.todo "initialise app"
-- {
-- 	var managers = {};
-- 	result = init(result.a);
-- 	var model = result.a;
-- 	var stepper = stepperBuilder(sendToApp, model);
-- 	var ports = _Platform_setupEffects(managers, sendToApp);

-- 	function sendToApp(msg, viewMetadata)
-- 	{
-- 		result = A2(update, msg, model);
-- 		stepper(model = result.a, viewMetadata);
-- 		_Platform_dispatchEffects(managers, result.b, subscriptions(model));
-- 	}

-- 	_Platform_dispatchEffects(managers, result.b, subscriptions(model));

-- 	return ports ? { ports: ports } : {};
-- }

-- effectManagerFold : List (String, EffectManager err state appMsg selfMsg)
effectManagerFold : (String -> EffectManager cmdLeafData subLeafData state appMsg selfMsg -> a -> a) -> a -> a
effectManagerFold =
  Elm.Kernel.Platform.effectManagerFold


setupEffects : SendToApp appMsg -> (Dict String OutgoingPort, OtherManagers)
setupEffects sendToAppP =
  effectManagerFold
    (\key (EffectManager { portSetup } as effectManager) (ports, otherMangers) ->
      ( case portSetup of
          Just portSetupFunc ->
            Dict.insert
              key
              (portSetupFunc key sendToAppP)
              ports

          Nothing ->
            ports
      , Dict.insert
          key
          (instantiateEffectManger effectManager sendToAppP)
          otherMangers
      )
    )
    (Dict.empty, Dict.empty)
  |> Tuple.mapSecond OtherManagers

instantiateEffectManger : EffectManager cmdLeafData subLeafData state appMsg selfMsg -> SendToApp appMsg -> ProcessId
instantiateEffectManger (EffectManager effectManager) (SendToApp func) =
  Debug.todo "instantiateEffectManger"
  -- let
  --   loop state =
  --     RawScheduler.andThen
  --       loop
  --       (RawScheduler.Receive (\receivedData ->
  --         case receivedData of
  --           RawScheduler.Self value ->
  --             effectManager.onSelfMsg router value state

  --           RawScheduler.Bag cmds subs ->
  --             Debug.todo "send bags to effect manager"
  --             -- case effectManger.effects of
  --             --   CmdOnlyEffectModule { onEffects } ->


  --       ))


  --   (RawScheduler.Process selfProcess) =
  --     RawScheduler.rawSpawn
  --       (RawScheduler.andThen
  --         (Debug.todo "mutal recursion needed")
  --         effectManager.init
  --       )
  --   router =
  --     Router
  --       { sendToApp = (\appMsg -> func appMsg AsyncUpdate)
  --       , selfProcess = selfProcess.id
  --       }
  -- in
  --   RawScheduler.Id2 (Elm.Kernel.Basics.fudgeType selfProcess.id)

type SendToApp msg
  = SendToApp (msg -> UpdateMetadate -> ())

type StepperBuilder model msg
  = StepperBuilder (SendToApp msg -> model -> (SendToApp msg))

type alias DebugMetadata = Encode.Value

type UpdateMetadate
  = SyncUpdate
  | AsyncUpdate

type OtherManagers =
  OtherManagers (Dict String ProcessId)

type alias EffectMangerName = String

{-|

I try to avoid naff comments when writing code. Saying that, I do feel
compeled to remark on quite how nasty the following type definition is.
-}
type Effects cmdLeafData subLeafData state appMsg selfMsg
  = CmdOnlyEffectModule
    { onEffects: (Router appMsg selfMsg -> List cmdLeafData -> state -> Task Never state)
    , cmdMap: (HiddenTypeA -> HiddenTypeA) -> LeafDataOfTypeA cmdLeafData -> LeafDataOfTypeB cmdLeafData
    }
  | SubOnlyEffectModule
    { onEffects: (Router appMsg selfMsg -> List subLeafData -> state -> Task Never state)
    , subMap: (HiddenTypeA -> HiddenTypeA) -> LeafDataOfTypeA subLeafData -> LeafDataOfTypeB subLeafData
    }
  | CmdAndSubEffectModule
    { onEffects: (Router appMsg selfMsg -> List cmdLeafData -> List subLeafData -> state -> Task Never state)
    , cmdMap: (HiddenTypeA -> HiddenTypeA) -> LeafDataOfTypeA cmdLeafData -> LeafDataOfTypeB cmdLeafData
    , subMap: (HiddenTypeA -> HiddenTypeA) -> LeafDataOfTypeA subLeafData -> LeafDataOfTypeB subLeafData
    }

type EffectManager cmdLeafData subLeafData state appMsg selfMsg =
  EffectManager
    { portSetup : Maybe (EffectMangerName -> SendToApp selfMsg -> OutgoingPort)
    , onSelfMsg : Router appMsg selfMsg -> selfMsg -> state -> Task Never state
    , init : Task Never state
    , effects : Effects cmdLeafData subLeafData state appMsg selfMsg
    , onEffects: (Router appMsg selfMsg -> List cmdLeafData -> List subLeafData -> state -> Task Never state)
    , cmdMap: (HiddenTypeA -> HiddenTypeA) -> LeafDataOfTypeA cmdLeafData -> LeafDataOfTypeB cmdLeafData
    , subMap: (HiddenTypeA -> HiddenTypeA) -> LeafDataOfTypeA subLeafData -> LeafDataOfTypeB subLeafData
    }


type OutgoingPort =
  OutgoingPort
    { subscribe: (Encode.Value -> ())
    , unsubscribe: (Encode.Value -> ())
    }

type HiddenTypeA
  = HiddenTypeA Never

type HiddenTypeB
  = HiddenTypeB Never

type LeafDataOfTypeA leafData
  = LeafDataOfTypeA Never

type LeafDataOfTypeB leafData
  = LeafDataOfTypeB Never

type UniqueId = UniqueId Never

type HiddenErr = HiddenErr Never


type HiddenOk = HiddenOk Never


