
module Main exposing (..)

import Benchmark.Runner exposing (BenchmarkProgram, program)

import Array
import Benchmark exposing (..)
import List exposing (reverse)


main : BenchmarkProgram
main =
    program suite

cons : a -> List a -> List a
cons =
    (::)


map2 : (a -> b -> result) -> List a -> List b -> List result
map2 f xs1 xs2 =
  map5 (\a b _ _ _ -> f a b) xs1 xs2 xs1 xs1 xs1


{-|-}
map3 : (a -> b -> c -> result) -> List a -> List b -> List c -> List result
map3 f xs1 xs2 xs3 =
  map5 (\a b c _ _ -> f a b c) xs1 xs2 xs3 xs1 xs1


{-|-}
map4 : (a -> b -> c -> d -> result) -> List a -> List b -> List c -> List d -> List result
map4 f xs1 xs2 xs3 xs4 =
  map5 (\a b c d _ -> f a b c d) xs1 xs2 xs3 xs4 xs1



{-|-}
map5 : (a -> b -> c -> d -> e -> result) -> List a -> List b -> List c -> List d -> List e -> List result
map5 =
    List.map5

map2Help :  (a -> b -> result) -> List a -> List b -> List result -> List result
map2Help f xs1 xs2 ys =
  case (xs1, xs2) of
    (head1 :: rest1, head2 :: rest2) ->
      map2Help f rest1 rest2 (cons (f head1 head2) ys)
    _ ->
      ys

map3Help : (a -> b -> c -> result) -> List a -> List b -> List c-> List result -> List result
map3Help f xs1 xs2 xs3 ys =
  case (xs1, xs2, xs3) of
    (head1 :: rest1, head2 :: rest2, head3 :: rest3) ->
      map3Help f rest1 rest2 rest3 (cons (f head1 head2 head3) ys)
    _ ->
      ys

map4Help : (a -> b -> c -> d -> result) -> List a -> List b -> List c -> List d -> List result -> List result
map4Help f xs1 xs2 xs3 xs4 ys =
  case (xs1, xs2, (xs3, xs4)) of
    (head1 :: rest1, head2 :: rest2, (head3 :: rest3, head4 :: rest4)) ->
      map4Help f rest1 rest2 rest3 rest4 (cons (f head1 head2 head3 head4) ys)
    _ ->
      ys


map5Help : (a -> b -> c -> d -> e -> result) -> List a -> List b -> List c -> List d -> List e -> List result -> List result
map5Help f xs1 xs2 xs3 xs4 xs5 ys =
  case (xs1, xs2, (xs3, xs4, xs5)) of
    (head1 :: rest1, head2 :: rest2, (head3 :: rest3, head4 :: rest4, head5 :: rest5)) ->
      map5Help f rest1 rest2 rest3 rest4 rest5 (cons (f head1 head2 head3 head4 head5) ys)
    _ ->
      ys


suite : Benchmark
suite =
    let
        sampleList =
            List.range 0 4999
    in
    describe "mapping"
        [ Benchmark.compare "map2"
            "no kernel"
            (\_ -> map2 (\a b -> a + b) sampleList sampleList)
            "core"
            (\_ -> List.map2 (\a b -> a + b) sampleList sampleList)
        , Benchmark.compare "map3"
            "no kernel"
            (\_ -> map3 (\a b c -> a + b + c) sampleList sampleList sampleList)
            "core"
            (\_ -> List.map3 (\a b c -> a + b + c) sampleList sampleList sampleList)
        , Benchmark.compare "map4"
            "no kernel"
            (\_ -> map4 (\a b c d -> a + b + c + d) sampleList sampleList sampleList sampleList)
            "core"
            (\_ -> List.map4 (\a b c d -> a + b + c + d) sampleList sampleList sampleList sampleList)
        , Benchmark.compare "map5"
            "no kernel"
            (\_ -> map5 (\a b c d e -> a + b + c + d + e) sampleList sampleList sampleList sampleList sampleList)
            "core"
            (\_ -> List.map5 (\a b c d e -> a + b + c + d + e) sampleList sampleList sampleList sampleList sampleList)
        ]
