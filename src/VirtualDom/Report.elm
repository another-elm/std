module VirtualDom.Report exposing
  ( Report
  , empty
  , addProblem
  , addWarning
  )


type alias Report =
  { problems : List String
  , warnings : List String
  }


empty : Report
empty =
  Report [] []


addProblem : Report -> String -> Report
addProblem { problems, warnings } newProblem =
  { problems = newProblem :: problems
  , warnings = warnings
  }


addWarning : Report -> String -> Report
addWarning { problems, warnings } newWarning =
  { problems = problems
  , warnings = newWarning :: warnings
  }


