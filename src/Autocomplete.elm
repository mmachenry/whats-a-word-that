module Autocomplete exposing (
    State,
    Config,
    init,
    input,
    subscriptions,
    getValue)

import Browser.Events
import Json.Decode as Decode
import List.Extra exposing (getAt)
import Html.Events exposing (keyCode)

import Element exposing (Element)
import Element.Input as Input
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font

type alias Config msg = {
    updateMessage : State -> msg,
    match : (String -> List String),
    inputAttributes : List (Element.Attribute msg),
    placeholder : Maybe (Input.Placeholder msg)
    }

type alias State = {
    query : String,
    showOptions : Bool,
    activeOption : Maybe Int,
    options : List String
    }

init = {
    query = "",
    showOptions = False,
    activeOption = Nothing,
    options = []
    }

subscriptions : Config msg -> State -> Sub msg
subscriptions config state =
    Browser.Events.onKeyDown
        (Decode.map (key config state >> config.updateMessage) keyCode)

key : Config msg -> State -> Int -> State
key config state code = case code of
    40 -> -- Down
        let numOptions = List.length state.options
        in case state.activeOption of
              Just i ->
                  let nextOption = if i+1 >= numOptions then 0 else i+1
                  in { state | activeOption = Just nextOption}
              Nothing -> { state | activeOption = Just 0}
    38 -> -- Up
        let numOptions = List.length state.options
        in case state.activeOption of
              Just i ->
                  let nextOption = if i-1 < 0 then numOptions-1 else i-1
                  in { state | activeOption = Just nextOption}
              Nothing ->
                  { state | activeOption = Just (numOptions-1)}
    13 -> -- Enter
      case state.activeOption of
        Nothing -> state
        Just i ->
          case getAt i state.options of
            Nothing -> state
            Just str -> {state | showOptions = False, query = str}
    _ -> state

getValue : State -> String
getValue state = state.query

input : Config msg -> State -> Element msg
input config state =
    let dropDown =
            if state.showOptions
            then [Element.below <| items config state]
            else []
    in Input.text (config.inputAttributes ++ dropDown) {
        onChange = onQueryInput state config >> config.updateMessage,
        text = state.query,
        label = Input.labelHidden "query", -- TODO: param
        placeholder = config.placeholder
        }

onQueryInput : State -> Config msg -> String -> State
onQueryInput state config newQuery = { state |
    query = newQuery,
    showOptions = String.length newQuery > 0,
    activeOption = Nothing,
    options = config.match newQuery
    }

items : Config msg -> State -> Element msg
items config state =
    Element.column [
            Element.width Element.fill,
            Border.color (Element.rgb 0.83 0.83 0.83),
            Border.widthXY 1 0
        ]
        (List.indexedMap (item config state) state.options)

item : Config msg -> State -> Int -> String -> Element msg
item config state thisIndex name =
    let isActive = case state.activeOption of
                       Just i -> thisIndex == i
                       Nothing -> False
    in Element.el [
           Element.padding 10,
           Font.size 16,
           Element.width Element.fill,
           Background.color (
               if isActive
               then Element.rgb 0.1176 0.5647 1
               else Element.rgb 1 1 1),
           Border.widthEach { bottom = 1, left = 0, right = 0, top = 0 },
           Border.color (Element.rgb 0.83 0.83 0.83)
           ]
           (Element.text name)

-- Turn cursor to a point when hovering.
-- Change color of menu item to grey when hovering.
-- Allow clicking of menu to select and item.
