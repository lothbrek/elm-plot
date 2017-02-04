module Plot
    exposing
        ( Value
        , Point
        , Element
        , PlotConfig
        , toPlotConfig
        , toPlotConfigCustom
        , plot
        , AreaConfig
        , toAreaConfig
        , areaSerie
        , LineConfig
        , toLineConfig
        , lineSerie
        , DotsConfig
        , toDotsConfig
        , dotsSerie
        , TickConfig
        , toTickConfig
        , ticks
        , viewTick
        , LabelConfig
        , toLabelConfig
        , labels
        , label
        , viewLabel
        , AxisLineConfig
        , toAxisLineConfig
        , axisLine
        , xAxis
        , xAxisAt
        , yAxis
        , yAxisAt
        , onAxis
        , Interpolation(..)
        , length
        , list
        , fromAxis
        , fromCount
        , displace
        , grid
        , fromRange
        , fromDomain
        , positionBy
        )

{-| Plot primities!

# Definitions
@docs Value, Point, Element

# Plot elements
@docs PlotConfig, toPlotConfig, toPlotConfigCustom, plot

## Series

### Line
@docs LineConfig, toLineConfig, lineSerie

### Area
@docs AreaConfig, toAreaConfig, areaSerie

### Dots
@docs DotsConfig, toDotsConfig, dotsSerie

## Axis elements
@docs xAxis, xAxisAt, yAxis, yAxisAt

### Value and position helpers
@docs onAxis, fromAxis, fromCount

### Axis line
@docs toAxisLineConfig, AxisLineConfig, axisLine

### Grid lines
@docs grid

### Labels
@docs LabelConfig, toLabelConfig, labels, label, viewLabel

### Ticks
@docs TickConfig, toTickConfig, ticks, viewTick

# General

## Value Helpers
@docs fromRange, fromDomain

## Helpers
@docs Interpolation, positionBy, list

## Fake SVG Attributes
@docs length, displace

-}

import Html exposing (Html)
import Svg exposing (Svg, g, text_, tspan, path, text, line)
import Svg.Attributes exposing (d, fill, transform, class, y2, x2)
import Utils exposing (..)


-- PUBLIC TYPES


{-| -}
type alias Value =
    Float


{-| -}
type alias Point =
    ( Value, Value )



-- INTERNAL TYPES


{-| -}
type Element a msg
    = Axis (Meta a -> Meta AxisMeta) (List (Element AxisMeta msg))
    | SerieElement (Axised Reach) (Serie msg)
    | Line (List (Svg.Attribute msg)) (Meta a -> List Point)
    | Position (Meta a -> Point) (List (Svg msg))
    | List (List (Svg.Attribute msg)) (Meta a -> List (Element a msg))
    | SVGView (Svg msg)


type Serie msg
    = LineSerie (LineConfig msg)
    | DotsSerie (DotsConfig msg)
    | AreaSerie (AreaConfig msg)



-- PRIMITIVES


{-| -}
positionBy : (Meta a -> Point) -> List (Svg msg) -> Element a msg
positionBy =
    Position


{-| -}
positionAt : Point -> List (Svg msg) -> Element a msg
positionAt point =
    Position (always point)


{-| -}
xAxis : List (Element AxisMeta msg) -> Element PlotMeta msg
xAxis =
    let
        toAxisMeta meta =
            { orientation = X
            , axisScale = meta.scale.x
            , oppositeAxisScale = meta.scale.y
            , axisIntercept = clampToZero meta.scale.y.reach.lower meta.scale.y.reach.upper
            , toSVGPoint = meta.toSVGPoint
            , scale = meta.scale
            }
    in
        Axis toAxisMeta


{-| -}
xAxisAt : (Value -> Value -> Value) -> List (Element AxisMeta msg) -> Element PlotMeta msg
xAxisAt toAxisIntercept =
    let
        toAxisMeta meta =
            { orientation = X
            , axisScale = meta.scale.x
            , oppositeAxisScale = meta.scale.y
            , axisIntercept = toAxisIntercept meta.scale.y.reach.lower meta.scale.y.reach.upper
            , toSVGPoint = meta.toSVGPoint
            , scale = meta.scale
            }
    in
        Axis toAxisMeta


{-| -}
yAxis : List (Element AxisMeta msg) -> Element PlotMeta msg
yAxis =
    let
        toAxisMeta meta =
            { orientation = Y
            , axisScale = meta.scale.y
            , oppositeAxisScale = meta.scale.x
            , axisIntercept = clampToZero meta.scale.x.reach.lower meta.scale.x.reach.upper
            , toSVGPoint = \( x, y ) -> meta.toSVGPoint ( y, x )
            , scale = meta.scale
            }
    in
        Axis toAxisMeta


{-| -}
yAxisAt : (Value -> Value -> Value) -> List (Element AxisMeta msg) -> Element PlotMeta msg
yAxisAt toAxisIntercept =
    let
        toAxisMeta meta =
            { orientation = Y
            , axisScale = meta.scale.y
            , oppositeAxisScale = meta.scale.x
            , axisIntercept = toAxisIntercept meta.scale.x.reach.lower meta.scale.x.reach.upper
            , toSVGPoint = \( x, y ) -> meta.toSVGPoint ( y, x )
            , scale = meta.scale
            }
    in
        Axis toAxisMeta


{-| -}
axisLine : AxisLineConfig msg -> Element AxisMeta msg
axisLine (AxisLineConfig { attributes }) =
    Line attributes (fromAxis (\p l h -> [ ( l, p ), ( h, p ) ]))


{-| -}
labels : LabelConfig msg -> Element AxisMeta msg
labels (LabelConfig config) =
    list [ class "elm-plot__labels" ] (label config.attributes config.format) config.positions


{-| -}
label : List (Svg.Attribute msg) -> (Value -> String) -> Value -> Element AxisMeta msg
label attributes format value =
    positionBy (onAxis value) [ viewLabel attributes (format value) ]


{-| -}
ticks : TickConfig msg -> Element AxisMeta msg
ticks (TickConfig config) =
    list [ class "elm-plot__ticks" ] (tick config.attributes) config.positions


{-| -}
tick : List (Svg.Attribute msg) -> Value -> Element AxisMeta msg
tick attributes value =
    positionBy (onAxis value) [ viewTick attributes ]


{-| -}
grid : List (Svg.Attribute msg) -> (Meta AxisMeta -> List Value) -> Element AxisMeta msg
grid attributes toValues =
    list [ class "elm-plot__grid" ] (fullLengthline attributes) toValues


{-| -}
list : List (Svg.Attribute msg) -> (b -> Element a msg) -> (Meta a -> List b) -> Element a msg
list attributes toElement toValues =
    List attributes (toValues >> List.map toElement)


{-| -}
fullLengthline : List (Svg.Attribute msg) -> Value -> Element AxisMeta msg
fullLengthline attributes value =
    Line attributes (fromAxis (\_ l h -> [ ( l, value ), ( h, value ) ]))



-- SERIES


{-| -}
lineSerie : LineConfig msg -> Element a msg
lineSerie config =
    let
        (LineConfig innerConfig) =
            config
    in
        SerieElement (findReachFromPoints innerConfig.data) (LineSerie config)


{-| -}
dotsSerie : DotsConfig msg -> Element a msg
dotsSerie config =
    let
        (DotsConfig innerConfig) =
            config
    in
        SerieElement (findReachFromPoints innerConfig.data) (DotsSerie config)


{-| -}
areaSerie : AreaConfig msg -> Element a msg
areaSerie config =
    let
        (AreaConfig innerConfig) =
            config
    in
        SerieElement (findReachFromPoints innerConfig.data) (AreaSerie config)



-- POSITION HELPERS


clampToZero : Value -> Value -> Value
clampToZero lower upper =
    clamp 0 lower upper


{-| -}
fromCount : Int -> Meta AxisMeta -> List Float
fromCount count meta =
    toDelta meta.axisScale.reach.lower meta.axisScale.reach.upper count
        |> toValuesFromDelta meta.axisScale.reach.lower meta.axisScale.reach.upper


{-| Produce a value from the range of the plot.
-}
fromRange : (Value -> Value -> b) -> Meta a -> b
fromRange toPoints { scale } =
    toPoints scale.x.reach.lower scale.x.reach.upper


{-| Produce a value from the domain of the plot.
-}
fromDomain : (Value -> Value -> b) -> Meta a -> b
fromDomain toSomething { scale } =
    toSomething scale.y.reach.lower scale.y.reach.upper


{-| Provides you with the axis' interception with the opposite axis, the lowerst and highest value.
-}
fromAxis : (Value -> Value -> Value -> b) -> Meta AxisMeta -> b
fromAxis toSomething meta =
    toSomething meta.axisIntercept meta.axisScale.reach.lower meta.axisScale.reach.upper


{-| Place at `value` on current axis.
-}
onAxis : Value -> Meta AxisMeta -> Point
onAxis value meta =
    ( value, meta.axisIntercept )



-- PUBLIC VIEWS


{-| -}
viewLabel : List (Svg.Attribute msg) -> String -> Svg msg
viewLabel attributes formattetValue =
    text_ attributes [ tspan [] [ text formattetValue ] ]


{-| -}
viewTick : List (Svg.Attribute msg) -> Svg msg
viewTick attributes =
    line attributes []



-- CONFIGS


{-| -}
type LineConfig msg
    = LineConfig
        { attributes : List (Svg.Attribute msg)
        , interpolation : Interpolation
        , data : List Point
        }


{-| -}
toLineConfig :
    { attributes : List (Svg.Attribute msg)
    , interpolation : Interpolation
    , data : List Point
    }
    -> LineConfig msg
toLineConfig config =
    LineConfig config


{-| -}
type AreaConfig msg
    = AreaConfig
        { attributes : List (Svg.Attribute msg)
        , interpolation : Interpolation
        , data : List Point
        }


{-| -}
toAreaConfig :
    { attributes : List (Svg.Attribute msg)
    , interpolation : Interpolation
    , data : List Point
    }
    -> AreaConfig msg
toAreaConfig config =
    AreaConfig config


{-| -}
type DotsConfig msg
    = DotsConfig
        { attributes : List (Svg.Attribute msg)
        , data : List Point
        , radius : Float
        }


{-| -}
toDotsConfig :
    { attributes : List (Svg.Attribute msg)
    , data : List Point
    , radius : Float
    }
    -> DotsConfig msg
toDotsConfig config =
    DotsConfig config


{-| -}
type TickConfig msg
    = TickConfig
        { attributes : List (Svg.Attribute msg)
        , positions : Meta AxisMeta -> List Value
        }


{-| -}
toTickConfig :
    { attributes : List (Svg.Attribute msg)
    , positions : Meta AxisMeta -> List Value
    }
    -> TickConfig msg
toTickConfig config =
    TickConfig config


{-| -}
type LabelConfig msg
    = LabelConfig
        { attributes : List (Svg.Attribute msg)
        , format : Value -> String
        , positions : Meta AxisMeta -> List Value
        }


{-| -}
toLabelConfig :
    { attributes : List (Svg.Attribute msg)
    , format : Value -> String
    , positions : Meta AxisMeta -> List Value
    }
    -> LabelConfig msg
toLabelConfig config =
    LabelConfig config


{-| -}
type AxisLineConfig msg
    = AxisLineConfig { attributes : List (Svg.Attribute msg) }


{-| -}
toAxisLineConfig :
    { attributes : List (Svg.Attribute msg) }
    -> AxisLineConfig msg
toAxisLineConfig config =
    AxisLineConfig config



-- ATTRIBUTES


{-| -}
displace : ( Float, Float ) -> Svg.Attribute msg
displace displacement =
    transform (toTranslate displacement)


{-| -}
length : Float -> Svg.Attribute msg
length length =
    y2 (toString length)


type alias Attribute c =
    c -> c


{-| -}
type Interpolation
    = Bezier
    | NoInterpolation



-- PLOT CUSTOMIZATIONS


{-| -}
type PlotConfig msg
    = PlotConfig
        { attributes : List (Svg.Attribute msg)
        , id : String
        , margin :
            { top : Int
            , right : Int
            , bottom : Int
            , left : Int
            }
        , proportions :
            { x : Int
            , y : Int
            }
        , toDomain : Value -> Value -> { lower : Value, upper : Value }
        , toRange : Value -> Value -> { lower : Value, upper : Value }
        }


{-| -}
toPlotConfig :
    { attributes : List (Svg.Attribute msg)
    , id : String
    , margin :
        { top : Int
        , right : Int
        , bottom : Int
        , left : Int
        }
    , proportions :
        { x : Int
        , y : Int
        }
    }
    -> PlotConfig msg
toPlotConfig { attributes, id, margin, proportions } =
    PlotConfig
        { attributes = []
        , id = id
        , margin = margin
        , proportions = proportions
        , toDomain = \min max -> { lower = min, upper = max }
        , toRange = \min max -> { lower = min, upper = max }
        }


{-| -}
toPlotConfigCustom :
    { attributes : List (Svg.Attribute msg)
    , id : String
    , margin :
        { top : Int
        , right : Int
        , bottom : Int
        , left : Int
        }
    , proportions :
        { x : Int
        , y : Int
        }
    , toDomain : Value -> Value -> { lower : Value, upper : Value }
    , toRange : Value -> Value -> { lower : Value, upper : Value }
    }
    -> PlotConfig msg
toPlotConfigCustom config =
    PlotConfig config


{-| Render your plot!
-}
plot : PlotConfig msg -> List (Element PlotMeta msg) -> Svg msg
plot config elements =
    viewPlot config elements (toPlotMeta config elements)



-- PLOT META


type alias Axised a =
    { x : a
    , y : a
    }


type alias Reach =
    { lower : Float
    , upper : Float
    }


type alias Scale =
    { reach : Reach
    , offset : Reach
    , length : Float
    }


type alias Meta a =
    { a
        | toSVGPoint : Point -> Point
        , scale : Axised Scale
    }


type alias PlotMeta =
    { id : String }


type alias AxisMeta =
    { orientation : Orientation
    , axisScale : Scale
    , oppositeAxisScale : Scale
    , axisIntercept : Value
    }


type Orientation
    = X
    | Y


toPlotMeta : PlotConfig msg -> List (Element PlotMeta msg) -> Meta PlotMeta
toPlotMeta (PlotConfig { id, margin, proportions, toRange, toDomain }) elements =
    let
        reach =
            findPlotReach elements

        range =
            toRange reach.x.lower reach.x.upper

        domain =
            toDomain reach.y.lower reach.y.upper

        scale =
            { x = toScale proportions.x range margin.left margin.right
            , y = toScale proportions.y domain margin.top margin.bottom
            }
    in
        { scale = scale
        , toSVGPoint = toSVGPoint scale.x scale.y
        , id = id
        }


toScale : Int -> Reach -> Int -> Int -> Scale
toScale length reach offsetLower offsetUpper =
    { length = toFloat length
    , offset = Reach (toFloat offsetLower) (toFloat offsetUpper)
    , reach = reach
    }



-- VIEW PLOT


viewPlot : PlotConfig msg -> List (Element PlotMeta msg) -> Meta PlotMeta -> Html msg
viewPlot (PlotConfig config) elements meta =
    let
        viewBoxValue =
            "0 0 " ++ toString meta.scale.x.length ++ " " ++ toString meta.scale.y.length

        attributes =
            config.attributes
                ++ [ Svg.Attributes.viewBox viewBoxValue, Svg.Attributes.id meta.id ]
    in
        Svg.svg attributes (scaleDefs meta :: (viewElements meta elements))


scaleDefs : Meta PlotMeta -> Svg.Svg msg
scaleDefs meta =
    Svg.defs []
        [ Svg.clipPath [ Svg.Attributes.id (toClipPathId meta) ]
            [ Svg.rect
                [ Svg.Attributes.x (toString meta.scale.x.offset.lower)
                , Svg.Attributes.y (toString meta.scale.y.offset.lower)
                , Svg.Attributes.width (toString (getInnerLength meta.scale.x))
                , Svg.Attributes.height (toString (getInnerLength meta.scale.y))
                ]
                []
            ]
        ]



-- VIEW ELEMENTS


viewElements : Meta a -> List (Element a msg) -> List (Svg msg)
viewElements meta elements =
    List.map (viewElement meta) elements


viewElement : Meta a -> Element a msg -> Svg msg
viewElement meta element =
    case element of
        Axis toMeta elements ->
            g [ class "elm-plot__axis" ] (viewElements (toMeta meta) elements)

        SerieElement _ serie ->
            viewSerie meta serie

        Line attributes toPoints ->
            viewPath attributes (makeLinePath NoInterpolation (toPoints meta) meta)

        Position toPosition children ->
            viewPositioned (toPosition meta) children meta

        List attributes toElements ->
            g attributes (List.map (viewElement meta) (toElements meta))

        SVGView view ->
            view


viewSerie : Meta a -> Serie msg -> Svg msg
viewSerie meta serie =
    case serie of
        LineSerie (LineConfig config) ->
            viewPath config.attributes (makeLinePath config.interpolation config.data meta)

        DotsSerie (DotsConfig config) ->
            g [] (List.map (meta.toSVGPoint >> toSVGCircle config.radius) config.data)

        AreaSerie (AreaConfig config) ->
            g [] []


viewPositioned : Point -> List (Svg msg) -> Meta a -> Svg msg
viewPositioned point children meta =
    g [ transform (toTranslate (meta.toSVGPoint point)) ] children



-- VIEW LINE


viewPath : List (Svg.Attribute msg) -> String -> Svg msg
viewPath attributes pathString =
    path (d pathString :: fill "transparent" :: attributes |> List.reverse) []


makeLinePath : Interpolation -> List Point -> Meta a -> String
makeLinePath interpolation points meta =
    case points of
        p1 :: rest ->
            M p1 :: (toLinePath interpolation (p1 :: rest)) |> toPath meta

        _ ->
            ""


toSVGCircle : Float -> Point -> Svg.Svg a
toSVGCircle radius ( x, y ) =
    Svg.circle
        [ Svg.Attributes.cx (toString x)
        , Svg.Attributes.cy (toString y)
        , Svg.Attributes.r (toString radius)
        ]
        []



-- PATH STUFF


type PathType
    = L Point
    | M Point
    | S Point Point Point
    | Z


toPath : Meta a -> List PathType -> String
toPath meta pathParts =
    List.foldl (\part result -> result ++ toPathTypeString meta part) "" pathParts


toPathTypeString : Meta a -> PathType -> String
toPathTypeString meta pathType =
    case pathType of
        M point ->
            toPathTypeStringSinglePoint meta "M" point

        L point ->
            toPathTypeStringSinglePoint meta "L" point

        S p1 p2 p3 ->
            toPathTypeStringS meta p1 p2 p3

        Z ->
            "Z"


toPathTypeStringSinglePoint : Meta a -> String -> Point -> String
toPathTypeStringSinglePoint meta typeString point =
    typeString ++ " " ++ pointToString meta point


toPathTypeStringS : Meta a -> Point -> Point -> Point -> String
toPathTypeStringS meta p1 p2 p3 =
    let
        ( point1, point2 ) =
            toBezierPoints p1 p2 p3
    in
        "S" ++ " " ++ pointToString meta point1 ++ "," ++ pointToString meta point2


magnitude : Float
magnitude =
    0.5


toBezierPoints : Point -> Point -> Point -> ( Point, Point )
toBezierPoints ( x0, y0 ) ( x, y ) ( x1, y1 ) =
    ( ( x - ((x1 - x0) / 2 * magnitude), y - ((y1 - y0) / 2 * magnitude) )
    , ( x, y )
    )


pointToString : Meta a -> Point -> String
pointToString meta point =
    let
        ( x, y ) =
            meta.toSVGPoint point
    in
        (toString x) ++ "," ++ (toString y)


toLinePath : Interpolation -> List Point -> List PathType
toLinePath smoothing =
    case smoothing of
        NoInterpolation ->
            List.map L

        Bezier ->
            toSPathTypes [] >> List.reverse


toSPathTypes : List PathType -> List Point -> List PathType
toSPathTypes result points =
    case points of
        [ p1, p2 ] ->
            S p1 p2 p2 :: result

        [ p1, p2, p3 ] ->
            toSPathTypes (S p1 p2 p3 :: result) [ p2, p3 ]

        p1 :: p2 :: p3 :: rest ->
            toSPathTypes (S p1 p2 p3 :: result) (p2 :: p3 :: rest)

        _ ->
            result



-- VIEW HELPERS


toClipPathId : Meta PlotMeta -> String
toClipPathId plot =
    plot.id ++ "__scale-clip-path"


toTranslate : ( Float, Float ) -> String
toTranslate ( x, y ) =
    "translate(" ++ (toString x) ++ "," ++ (toString y) ++ ")"


toRotate : Float -> Float -> Float -> String
toRotate d x y =
    "rotate(" ++ (toString d) ++ " " ++ (toString x) ++ " " ++ (toString y) ++ ")"


toStyle : List ( String, String ) -> String
toStyle styles =
    List.foldr (\( p, v ) r -> r ++ p ++ ":" ++ v ++ "; ") "" styles


toPixels : Float -> String
toPixels pixels =
    toString pixels ++ "px"


toPixelsInt : Int -> String
toPixelsInt =
    toPixels << toFloat


addDisplacement : Point -> Point -> Point
addDisplacement ( x, y ) ( dx, dy ) =
    ( x + dx, y + dy )



-- SCALING HELPERS


getRange : Scale -> Value
getRange scale =
    let
        range =
            scale.reach.upper - scale.reach.lower
    in
        if range > 0 then
            range
        else
            1


getInnerLength : Scale -> Value
getInnerLength scale =
    scale.length - scale.offset.lower - scale.offset.upper


scaleValue : Scale -> Value -> Value
scaleValue scale v =
    (v * (getInnerLength scale) / (getRange scale)) + scale.offset.lower


toSVGPoint : Scale -> Scale -> Point -> Point
toSVGPoint xScale yScale ( x, y ) =
    ( scaleValue xScale (x - xScale.reach.lower)
    , scaleValue yScale (yScale.reach.upper - y)
    )



-- META


applyAttributes : List (a -> a) -> a -> a
applyAttributes attributes config =
    List.foldl (<|) config attributes


findPlotReach : List (Element a msg) -> Axised Reach
findPlotReach elements =
    List.filterMap getReach elements
        |> List.foldl strechReach Nothing
        |> Maybe.withDefault (Axised (Reach 0 1) (Reach 0 1))


getReach : Element a msg -> Maybe (Axised Reach)
getReach element =
    case element of
        SerieElement reach _ ->
            Just reach

        _ ->
            Nothing


findReachFromPoints : List Point -> Axised Reach
findReachFromPoints points =
    List.unzip points |> (\( xValues, yValues ) -> Axised (findReachFromValues xValues) (findReachFromValues yValues))


findReachFromValues : List Value -> Reach
findReachFromValues values =
    { lower = getLowest values
    , upper = getHighest values
    }


getLowest : List Float -> Float
getLowest values =
    Maybe.withDefault 0 (List.minimum values)


getHighest : List Float -> Float
getHighest values =
    Maybe.withDefault 1 (List.maximum values)


strechReach : Axised Reach -> Maybe (Axised Reach) -> Maybe (Axised Reach)
strechReach elementReach plotReach =
    case plotReach of
        Just reach ->
            Just <|
                Axised
                    (strechSingleReach elementReach.x reach.x)
                    (strechSingleReach elementReach.y reach.y)

        Nothing ->
            Just elementReach


strechSingleReach : Reach -> Reach -> Reach
strechSingleReach elementReach plotReach =
    { lower = min plotReach.lower elementReach.lower
    , upper = max plotReach.upper elementReach.upper
    }


toInitialPlot : List (Element PlotMeta msg) -> Axised Reach -> Meta PlotMeta
toInitialPlot elements reach =
    { id = "elm-plot"
    , toSVGPoint = identity
    , scale =
        Axised
            (Scale reach.x (Reach 0 0) 100)
            (Scale reach.y (Reach 0 0) 100)
    }


applyTranslators : Meta PlotMeta -> Meta PlotMeta
applyTranslators meta =
    { meta | toSVGPoint = toSVGPoint meta.scale.x meta.scale.y }



-- UPDATE HELPERS


updateXScale : scale -> { p | scale : Axised scale } -> { p | scale : Axised scale }
updateXScale xScale ({ scale } as config) =
    { config | scale = { scale | x = xScale } }


updateYScale : scale -> { p | scale : Axised scale } -> { p | scale : Axised scale }
updateYScale yScale ({ scale } as config) =
    { config | scale = { scale | y = yScale } }


updateScaleLength : Int -> Scale -> Scale
updateScaleLength length scale =
    { scale | length = toFloat length }


updateScaleOffset : Int -> Int -> Scale -> Scale
updateScaleOffset lower upper ({ offset } as scale) =
    { scale | offset = { offset | lower = toFloat lower, upper = toFloat upper } }


updateScaleReach : Reach -> Scale -> Scale
updateScaleReach reach scale =
    { scale | reach = reach }


updateScaleLowerReach : (Float -> Float) -> Scale -> Scale
updateScaleLowerReach toLowest ({ reach } as scale) =
    { scale | reach = { reach | lower = toLowest reach.lower } }


updateScaleUpperReach : (Float -> Float) -> Scale -> Scale
updateScaleUpperReach toHighest ({ reach } as scale) =
    { scale | reach = { reach | upper = toHighest reach.upper } }
