port module Main exposing (main)

import Css
import Html
import Html.Styled exposing (..)
import Html.Styled.Attributes exposing (..)
import Html.Styled.Events exposing (onClick, onInput)
import Http
import Json.Decode as Json
import Regex
import Array.Hamt exposing (Array)
import Array.Hamt as Array

baseUrl = "https://en.wikipedia.org/wiki/"
-- baseUrl = "http://transformersprime.wikia.com/wiki/"

port observe : String -> Cmd msg
port onVisible : ((String, Bool) -> msg) -> Sub msg

main = Html.program {
    init = init,
    view = (view >> toUnstyled),
    update = update,
    subscriptions = subscriptions }

type alias Model = {
    categoryInput : String,
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
        categoryInput = "",
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
    UpdateCategory str -> ({ model | categoryInput = str }, Cmd.none)
    UpdateRegex str -> ({ model | regex = str }, Cmd.none)
    Search ->
        let newCategory = "Category:" ++ model.categoryInput
        in ({model |
                category = newCategory,
                continue = Nothing,
                pages = Array.empty,
                subCategories = []},
            getCategoryMembers newCategory Nothing)
    LoadMore -> loadMore model
    UpdateVisibility (elementId, shown) -> loadMore { model | visible = shown }
    UpdateResults (Err err) -> ({ model | error = Just err }, Cmd.none)
    UpdateResults (Ok result) ->
        let namespace i page = page.ns == i
            newPages =
                List.filter (\p->not (String.startsWith "Lists of " p.title
                                      || String.startsWith "List of " p.title))
                    (List.filter (namespace 0) result.pages)
            newSubCats = List.filter (namespace 14) result.pages
        in loadMore { model |
               error = Nothing,
               continue = result.cmcontinue,
               pages = Array.append model.pages (Array.fromList newPages),
               subCategories = List.append model.subCategories newSubCats }

view : Model -> Html Msg
view model =
  div [
      css [
          Css.margin (Css.pct 5)
          ]
      ] [
    h1 [ css [ Css.fontSize (Css.px 28) ]] [ text "What's a word that... ?" ],
    div [
        css [
            Css.displayFlex,
            Css.justifyContent Css.spaceBetween,
            Css.alignItems Css.stretch,
            Css.height (Css.px 40)
            ]
        ] [
        input [ placeholder "category",
                onInput UpdateCategory,
                css [
                    Css.flexGrow (Css.num 3),
                    Css.fontSize (Css.px 16),
                    Css.padding (Css.px 5),
                    Css.marginRight (Css.px 10)
                    ]
                ] [],
        button [ onClick Search,
                 disabled (model.categoryInput == ""),
                 css [
                     --Css.height (Css.rem 35)
                     ]
                 ]
               [ text "search" ]],
    div [ hidden (model.error == Nothing) ] [ text (toString model.error) ],
    div [
        css [
            Css.displayFlex,
            Css.alignItems Css.stretch,
            Css.height (Css.px 40),
            Css.margin2 (Css.px 10) (Css.px 0)
            ]
        ] [
        input [
            css [
                Css.width (Css.pct 100),
                Css.fontSize (Css.px 16)
                ],
            placeholder "regex", onInput UpdateRegex
            ] []],
    viewResults model
    ]

viewResults : Model -> Html Msg
viewResults model =
    let regex = Regex.regex model.regex
        matches = Array.filter (\p->Regex.contains regex p.title)
                                model.pages
        mkListItem page =
            li [] [a [href (baseUrl ++ page.title)]
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
        baseUrl ++
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
