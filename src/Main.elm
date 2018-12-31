port module Main exposing (main)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Html.Events.Extra exposing (onEnter)
import Browser
import Http
import Json.Decode as Json
import Regex
import Array exposing (Array)
import Debug exposing (toString)

wikiHost = "en.wikipedia.org"
-- wikiHost = "transformersprime.wikia.com"

port observe : String -> Cmd msg
port onVisible : ((String, Bool) -> msg) -> Sub msg

main = Browser.element {
    init = init,
    view = view,
    update = update,
    subscriptions = subscriptions }

type alias Model = {
    categoryInput : String,
    category : String,
    regex : String,
    caseSensitive: Bool,
    error : Maybe Http.Error,
    visible : Bool,
    continue : Maybe String,
    pages : Array WikiPage,
    subCategories : List WikiPage
    }

type alias Flags = {}

type alias CategoryList = {
    cmcontinue : Maybe String,
    pages : List WikiPage
    }

type alias WikiPage = {
    pageid : Int,
    ns : Int, --namespace, I think. 0=page, 14=category?
    title : String
    }

initModel = {
    categoryInput = "",
    category = "",
    regex = "",
    caseSensitive = False,
    error = Nothing,
    visible = False,
    continue = Nothing,
    pages = Array.empty,
    subCategories = []
    }

init : Flags -> (Model, Cmd Msg)
init _ = (initModel, observe "#loadBtn")

type Msg =
      UpdateCategory String
    | UpdateRegex String
    | UpdateCaseSensitive
    | Search
    | LoadMore
    | UpdateVisibility (String, Bool)
    | UpdateResults (Result Http.Error CategoryList)

update : Msg -> Model -> (Model, Cmd Msg)
update msg model = case msg of
    UpdateCategory str -> ({ model | categoryInput = str }, Cmd.none)
    UpdateRegex str -> ({ model | regex = str }, Cmd.none)
    UpdateCaseSensitive ->
        ({ model | caseSensitive = not model.caseSensitive}, Cmd.none)
    Search ->
        let newCategory = "Category:" ++ model.categoryInput
        in ({model |
                category = newCategory,
                continue = Nothing,
                pages = Array.empty,
                subCategories = []},
            getCategoryMembers newCategory Nothing)
    LoadMore -> loadMore { model | visible = True }
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
    div [ style "margin" "5%" ] [
        h1 [ style "font-size" "28px" ]
           [ text "What's a word that... ?" ],
        div [ style "display" "flex",
              style "justify-content" "space-between",
              style "align-items" "stretch",
              style "height" "40px",
              style "margin-bottom" "13px"] [
            input [ placeholder "wiki category (e.g. National_Hockey_League_All-Stars)",
                    onInput UpdateCategory,
                    onEnter Search,
                    style "flex-grow" "3",
                    style "font-size" "16px",
                    style "padding" "5px",
                    style "margin-right" "10px"
                    ] [],
            button [ onClick Search,
                     disabled (model.categoryInput == "") ]
                   [ text "search" ]],
        div [ hidden (model.error == Nothing) ]
            [ text (toString model.error) ],
        div [ style "display" "flex",
              style "align-items" "stretch",
              style "height" "40px",
              style "margin2" "10px 0px" ] [
            input [
                placeholder "regex",
                style "width" "100%",
                style "font-size" "16px",
                onInput UpdateRegex
                ] [],
            label [ style "padding-left" "10px"] [
                input [
                  type_ "checkbox",
                  checked model.caseSensitive,
                  onClick UpdateCaseSensitive
                  ] [],
                text "case sensitive?"
              ]
            ],
        viewResults model
    ]

viewResults : Model -> Html Msg
viewResults model =
    let matches = case Regex.fromStringWith {
                           caseInsensitive = (not model.caseSensitive),
                           multiline = False
                           } model.regex of
            Nothing -> model.pages
            Just regex -> Array.filter (\p->Regex.contains regex p.title)
                                       model.pages
        mkListItem page =
            li [] [a [href (mkUrl wikiHost ("/wiki/" ++ page.title) []),
                      target "_blank",
                      style "color" "black"]
                     [text page.title]]
    in div [] [
        div [ style "margin-top" "4px",
              style "font-size" "13px",
              style "font-family" "Helvetica, Arial, sans-serif",
              style "color" "#999"
            ] [ text <|
                         (toString (Array.length matches)) ++ " matches / " ++
                         (toString (Array.length model.pages)) ++
                         " loaded" ],
        ol [ style "color" "#999",
             style "font-family" "'PT Mono', monospace",
             style "line-height" "1.6",
             style "font-size" "13px"
        ] (List.map mkListItem (Array.toList matches)),
        div [id "loadBtn",
             hidden (model.continue == Nothing &&
                     List.length model.subCategories == 0)]
            [button [onClick LoadMore] [text "Load more..."]]]

subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch [
        onVisible UpdateVisibility
        ]

getCategoryMembers : String -> Maybe String -> Cmd Msg
getCategoryMembers category continue =
    let args = [
          ("action","query"),
          ("list","categorymembers"),
          ("cmlimit","500"),
          ("origin","*"),
          ("format","json"),
          ("cmtitle",category)]
        url = mkUrl wikiHost "/w/api.php?" (case continue of
                Just str -> ("cmcontinue",str) :: args
                Nothing -> args)
    in Http.get {
           url = url,
           expect = Http.expectJson UpdateResults categoryList
       }

mkUrl : String -> String -> List (String, String) -> String
mkUrl host page args =
    let argStr = String.join "&" (List.map (\(n,v)-> n ++ "=" ++ v) args)
    in "https://" ++ host ++ page ++ argStr

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
