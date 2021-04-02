module Test.Tuple exposing (tests)

import Basics exposing (..)
import Tuple exposing (..)
import Test exposing (..)
import Expect
import Fuzz


tests : Test
tests =
    describe "Tuple Tests"
        [ describe "first"
            [ test "extracts first element" <|
                \() -> Expect.equal 1 (first ( 1, 2 ))
            ]
        , describe "second"
            [ test "extracts second element" <|
                \() -> Expect.equal 2 (second ( 1, 2 ))
            ]
        , describe "mapFirst"
            [ test "applies function to first element" <|
                \() -> Expect.equal ( 5, 1 ) (mapFirst ((*) 5) ( 1, 1 ))
            ]
        , describe "mapSecond"
            [ test "applies function to second element" <|
                \() -> Expect.equal ( 1, 5 ) (mapSecond ((*) 5) ( 1, 1 ))
            ]
        , describe "equality"
            [ test "0 tuple" <|
                \() ->
                    Expect.equal () ()
            , describe "2 tuple"
                [ test "equal" <|
                    \() -> Expect.equal (0, 0) (0, 0)
                , fuzz Fuzz.int "not equal 1" <|
                    \a -> Expect.notEqual (-1, a) (0, a)
                , fuzz Fuzz.int "not equal 2" <|
                    \a -> Expect.notEqual (a, 0) (a, 1)
                ]
            , describe "3 tuple"
                [ test "equal" <|
                    \() -> Expect.equal (0, 0, 0) (0, 0, 0)
                , fuzz2 Fuzz.int Fuzz.int "not equal 1" <|
                    \a b -> Expect.notEqual (-1, a, b) (0, a, b)
                , fuzz2 Fuzz.int Fuzz.int "not equal 2" <|
                    \a b -> Expect.notEqual (a, 0, b) (a, 1, b)
                , fuzz2 Fuzz.int Fuzz.int "not equal 3" <|
                    \a b -> Expect.notEqual (a, b, "h") (a, b, "g")
                ]
            ]
        , describe "ordering"
            [ describe "2 tuple"
                [ test "eq" <|
                    \() -> Expect.equal EQ (compare (0, 0) (0, 0))
                , fuzz2 Fuzz.float Fuzz.float "lt 1" <|
                    \a b -> Expect.equal LT (compare (-1, a) (0, b))
                , test "lt 2" <|
                    \() -> Expect.equal LT (compare (0, -1) (0, 0))
                , fuzz2 Fuzz.float Fuzz.float "gt 1" <|
                    \a b -> Expect.equal GT (compare (1, a) (0, b))
                , test "gt 2" <|
                    \() -> Expect.equal GT (compare (0, 1) (0, 0))
                ]
            , describe "3 tuple"
                [ test "eq" <|
                    \() -> Expect.equal EQ (compare (0, 0) (0, 0))
                , fuzz3 Fuzz.float Fuzz.float (Fuzz.tuple (Fuzz.char, Fuzz.char)) "lt 1" <|
                    \a b (c, d) -> Expect.equal LT (compare (-1, a, c) (0, b, d))
                , fuzz2 Fuzz.float Fuzz.float "lt 2" <|
                    \a b -> Expect.equal LT (compare (0, -1, a) (0, 0, b))
                , test "lt 3" <|
                    \() -> Expect.equal LT (compare (0, 0, -1) (0, 0, 0))
                ]
            ]
        ]
