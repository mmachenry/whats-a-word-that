port module Main exposing (main)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Http
import Json.Decode as Json
import Regex
import Array.Hamt exposing (Array)
import Array.Hamt as Array

port observe : String -> Cmd msg
port onVisible : ((String, Bool) -> msg) -> Sub msg

main = Html.program {
    init = init,
    view = view,
    update = update,
    subscriptions = subscriptions }

type alias Model = {
    category : String,
    regex : String,
    error : Maybe Http.Error,
    visible : Bool,
    continue : Maybe String,
    pages : Array WikiPage,
    subCategories : List WikiPage
    }

type alias CategoryList = {
    cmcontinue : Maybe String,
    pages : List WikiPage
    }

type alias WikiPage = {
    pageid : Int,
    ns : Int, --namespace, I think. 0=page, 14=category?
    title : String
    }

init : (Model, Cmd Msg)
init =
    let model = {
        category = "",
        regex = "",
        error = Nothing,
        visible = False,
        continue = Nothing,
        pages = Array.empty,
        subCategories = [] }
    in (model, observe "#loadBtn")

type Msg =
      UpdateCategory String
    | UpdateRegex String
    | Search
    | LoadMore
    | UpdateVisibility (String, Bool)
    | UpdateResults (Result Http.Error CategoryList)

update : Msg -> Model -> (Model, Cmd Msg)
update msg model = case msg of
    UpdateCategory str -> ({ model | category = str }, Cmd.none)
    UpdateRegex str -> ({ model | regex = str }, Cmd.none)
    Search -> ({ model | continue = Nothing, pages = Array.empty },
               getCategoryMembers model.category Nothing)
    LoadMore -> loadMore model
    UpdateVisibility (elementId, shown) -> loadMore { model | visible = shown }
    UpdateResults (Err err) -> ({ model | error = Just err }, Cmd.none)
    UpdateResults (Ok result) ->
        let namespace i page = page.ns == i
            newPages = List.filter (namespace 0) result.pages
            newSubCats = List.filter (namespace 14) result.pages
        in loadMore { model |
               error = Nothing,
               continue = result.cmcontinue,
               pages = Array.append model.pages (Array.fromList newPages),
               subCategories = List.append model.subCategories newSubCats}

view : Model -> Html Msg
view model = div [] [
    input [ placeholder "category", onInput UpdateCategory ] [],
    input [ placeholder "regex", onInput UpdateRegex ] [],
    button [ onClick Search ] [ text "search" ],
    --div [] [text (toString model)],
    viewResults model
    ]

viewResults : Model -> Html Msg
viewResults model =
    let regex = Regex.regex model.regex
        matches = Array.filter (\p->Regex.contains regex p.title)
                                model.pages
        mkListItem page =
            li [] [a [href ("https://en.wikipedia.org/wiki/" ++ page.title)]
                     [text page.title]]
    in div [] [
        div [] [ text <| (toString (Array.length model.pages)) ++
                         " loaded / " ++
                         (toString (Array.length matches)) ++ " matches" ],
        ol [] (List.map mkListItem (Array.toList matches)),
        div [id "loadBtn",
             hidden (model.continue == Nothing &&
                     List.length model.subCategories == 0)]
            [button [onClick LoadMore] [text "Load more..."]]]

subscriptions : Model -> Sub Msg
subscriptions model = onVisible UpdateVisibility

getCategoryMembers : String -> Maybe String -> Cmd Msg
getCategoryMembers category continue =
    let url =
        "https://en.wikipedia.org/w/api.php?" ++
        "action=query&" ++
        "list=categorymembers&" ++
        "cmlimit=500&" ++
        "origin=*&" ++
        "format=json&" ++
        (case continue of
            Just str -> "cmcontinue=" ++ str ++ "&"
            Nothing -> "") ++
        "cmtitle=" ++ category
    in Http.send UpdateResults (Http.get url categoryList)

loadMore : Model -> (Model, Cmd Msg)
loadMore model =
    if model.visible
    then case model.subCategories of
             (sc::scs) -> ({ model | subCategories = scs},
                           getCategoryMembers sc.title Nothing)
             [] -> case model.continue of
                       Just str ->
                           (model, getCategoryMembers model.category (Just str))
                       Nothing -> (model, Cmd.none)
    else (model, Cmd.none)

categoryList : Json.Decoder CategoryList
categoryList =
    let continue = Json.field "cmcontinue" Json.string
        query = Json.field "categorymembers" (Json.list wikiPage)
        wikiPage = Json.map3 WikiPage
                               (Json.field "pageid" Json.int)
                               (Json.field "ns" Json.int)
                               (Json.field "title" Json.string)
    in Json.map2
        CategoryList
        (Json.maybe (Json.field "continue" continue))
        (Json.field "query" query)
