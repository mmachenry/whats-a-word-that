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
import Autocomplete
import Wikipedia

import Element exposing (Element)
import Element.Font as Font
import Element.Input as Input
import Element.Background as Background

port observe : String -> Cmd msg
port onVisible : ((String, Bool) -> msg) -> Sub msg

main = Browser.element {
    init = init,
    view = view,
    update = update,
    subscriptions = subscriptions }

type alias Model = {
    wikiHost : String,
    category : String,
    regex : String,
    caseSensitive: Bool,
    error : Maybe Http.Error,
    visible : Bool,
    continue : Maybe String,
    pages : Array WikiPage,
    subCategories : List WikiPage,
    autoState : Autocomplete.State
    }

type alias Flags = {
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

initModel : Flags -> Model
initModel flags = {
    wikiHost = "en.wikipedia.org",
    category = "",
    regex = "",
    caseSensitive = False,
    error = Nothing,
    visible = False,
    continue = Nothing,
    pages = Array.empty,
    subCategories = [],
    autoState = Autocomplete.init
    }

init : Flags -> (Model, Cmd Msg)
init flags = (initModel flags, observe "#loadBtn")

type Msg =
      UpdateRegex String
    | UpdateCaseSensitive Bool
    | Search
    | LoadMore
    | UpdateVisibility (String, Bool)
    | UpdateResults (Result Http.Error CategoryList)
    | UpdateAutoState Autocomplete.State

update : Msg -> Model -> (Model, Cmd Msg)
update msg model = case msg of
    UpdateRegex str -> ({ model | regex = str }, Cmd.none)
    UpdateCaseSensitive val -> ({ model | caseSensitive = val}, Cmd.none)
    Search ->
        let newCategory = "Category:" ++ Autocomplete.getValue model.autoState
        in ({model |
                category = newCategory,
                continue = Nothing,
                pages = Array.empty,
                subCategories = []},
            getCategoryMembers model.wikiHost newCategory Nothing)
    LoadMore -> loadMore model
    UpdateVisibility (elementId, shown) ->
        loadMoreIfVisible { model | visible = shown }
    UpdateResults (Err err) -> ({ model | error = Just err }, Cmd.none)
    UpdateResults (Ok result) ->
        let namespace i page = page.ns == i
            newPages =
                List.filter (\p->not (String.startsWith "Lists of " p.title
                                      || String.startsWith "List of " p.title))
                    (List.filter (namespace 0) result.pages)
            newSubCats = List.filter (namespace 14) result.pages
        in loadMoreIfVisible { model |
               error = Nothing,
               continue = result.cmcontinue,
               pages = Array.append model.pages (Array.fromList newPages),
               subCategories = List.append model.subCategories newSubCats }
    UpdateAutoState newState -> ({model | autoState = newState}, Cmd.none)

autoConfig : Autocomplete.Config Msg
autoConfig = {
    updateMessage = UpdateAutoState,
    match = getMatches,
    inputAttributes = [],
    placeholder = Just (Input.placeholder [] (Element.text "wiki category (e.g. National_Hockey_League_All-Stars)"))
    }

getMatches : String -> List String
getMatches query =
    List.filter (String.startsWith query) Wikipedia.categories
    |> List.take 10

view : Model -> Html Msg
view model =
    Element.layout [
            Font.family [ Font.typeface "Helvetica", Font.sansSerif]
        ] <|
        Element.column [
            Element.padding 30,
            Element.spacing 10,
            Element.width Element.fill
            ] [
            Element.el [
                Font.size 28,
                Font.bold
                ] (Element.text "What's a word that... ?"),
            Element.row [
                Element.spacing 10,
                Element.width Element.fill
                ] [
                Autocomplete.input autoConfig model.autoState,
                Input.button [
                    Element.padding 14,
                    Font.color (Element.rgb 1 1 1),
                    Background.color (Element.rgb 0.1176 0.5647 1)
                    ] {
                    onPress = if Autocomplete.getValue model.autoState == ""
                              then Nothing
                              else Just Search,
                    label = Element.text "Search"
                    } ],
            Element.row [
                Element.spacing 10,
                Element.width Element.fill
                ] [
                Input.text [
                    Element.width (Element.fillPortion 10)
                    ] {
                    onChange = UpdateRegex,
                    text = model.regex,
                    placeholder =
                        Just (Input.placeholder [] (Element.text "regex")),
                    label = Input.labelHidden "regex"
                    },
                Input.checkbox [
                    Element.width (Element.fillPortion 1)
                    ] {
                    onChange = UpdateCaseSensitive,
                    icon = Input.defaultCheckbox,
                    checked = model.caseSensitive,
                    label = Input.labelRight [
                        ] (Element.text "case sensitive?")
                    }
                ],
            Element.html (viewResults model)
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
            li [] [a [href (mkUrl model.wikiHost ("/wiki/" ++ page.title) []),
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
        onVisible UpdateVisibility,
        Autocomplete.subscriptions autoConfig model.autoState
        ]

getCategoryMembers : String -> String -> Maybe String -> Cmd Msg
getCategoryMembers host category continue =
    let args = [
          ("action","query"),
          ("list","categorymembers"),
          ("cmlimit","500"),
          ("origin","*"),
          ("format","json"),
          ("cmtitle",category)]
        url = mkUrl host "/w/api.php?" (case continue of
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

loadMoreIfVisible : Model -> (Model, Cmd Msg)
loadMoreIfVisible model =
    if model.visible
    then loadMore model
    else (model, Cmd.none)

loadMore : Model -> (Model, Cmd Msg)
loadMore model =
    case model.subCategories of
        (sc::scs) -> ({ model | subCategories = scs},
                      getCategoryMembers model.wikiHost sc.title Nothing)
        [] -> case model.continue of
                  Just str ->
                      (model, getCategoryMembers
                                  model.wikiHost
                                  model.category
                                  (Just str))
                  Nothing -> (model, Cmd.none)

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

