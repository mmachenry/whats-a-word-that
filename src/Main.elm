module Main exposing (main)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Http
import Json.Decode as Json
import Regex
import Array.Hamt exposing (Array)
import Array.Hamt as Array

main = Html.program {
    init = init,
    view = view,
    update = update,
    subscriptions = subscriptions }

type alias Model = {
    category : String,
    regex : String,
    error : Maybe Http.Error,
    result : CategoryList
    }

type alias CategoryList = {
    cmcontinue : Maybe String,
    pages : Array WikiPage
    }

type alias WikiPage = {
    pageid : Int,
    title : String
    }

init : (Model, Cmd Msg)
init =
    let model = {
        category = "",
        regex = "",
        error = Nothing,
        result = { cmcontinue = Nothing, pages = Array.empty } }
    in (model, Cmd.none)

type Msg =
      UpdateCategory String
    | UpdateRegex String
    | Search
    | LoadMore String
    | UpdateResults Bool (Result Http.Error CategoryList)

update : Msg -> Model -> (Model, Cmd Msg)
update msg model = case msg of
    UpdateCategory str -> ({ model | category = str }, Cmd.none)
    UpdateRegex str -> ({ model | regex = str }, Cmd.none)
    Search -> (model, getCategoryMembers Nothing model.category)
    LoadMore str -> (model, getCategoryMembers (Just str) model.category)
    UpdateResults _ (Err err) -> ({ model | error = Just err }, Cmd.none)
    UpdateResults append (Ok result) -> ({ model |
        error = Nothing,
        result = if append
                 then { cmcontinue = result.cmcontinue,
                        pages = Array.append model.result.pages result.pages }
                 else result
        }, Cmd.none)

view : Model -> Html Msg
view model = div [] [
    input [ placeholder "category", onInput UpdateCategory ] [],
    input [ placeholder "regex", onInput UpdateRegex ] [],
    button [ onClick Search ] [ text "search" ],
    viewResults model
    ]

viewResults : Model -> Html Msg
viewResults model =
    let regex = Regex.regex model.regex
        matches = Array.filter (\p->Regex.contains regex p.title)
                                model.result.pages
        mkListItem page =
            li [] [a [href ("https://en.wikipedia.org/wiki/" ++ page.title)]
                     [text page.title]]
    in div [] [
        div [] [ text <| (toString (Array.length model.result.pages)) ++
                         " loaded / " ++
                         (toString (Array.length matches)) ++ " matches" ],
        ol [] (List.map mkListItem (Array.toList matches)),
        case model.result.cmcontinue of
            Nothing -> div [] [ text "done" ]
            Just str -> button [ onClick (LoadMore str) ] [text "Load more..."]
        ]

subscriptions : Model -> Sub Msg
subscriptions mode = Sub.none

getCategoryMembers : Maybe String -> String -> Cmd Msg
getCategoryMembers cmcontinue category =
    let url =
        "https://en.wikipedia.org/w/api.php?" ++
        "action=query&" ++
        "list=categorymembers&" ++
        "cmlimit=500&" ++
        "origin=*&" ++
        "format=json&" ++
        "cmtype=page&" ++
        (case cmcontinue of
            Just str -> "cmcontinue=" ++ str ++ "&"
            Nothing -> "") ++
        "cmtitle=" ++ category
    in Http.send (UpdateResults (cmcontinue /= Nothing))
                 (Http.get url categoryList)

categoryList : Json.Decoder CategoryList
categoryList =
    let continue = Json.field "cmcontinue" Json.string
        query = Json.map Array.fromList
                    (Json.field "categorymembers" (Json.list wikiPage))
        wikiPage = Json.map2 WikiPage
                               (Json.field "pageid" Json.int)
                               (Json.field "title" Json.string)
    in Json.map2
        CategoryList
        (Json.maybe (Json.field "continue" continue))
        (Json.field "query" query)
