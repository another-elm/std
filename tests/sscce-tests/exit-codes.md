# Exit Codes

`elm-torture` uses exit codes between 32 and 63

    Format

    0010 0001: One or more suites failed at compile time
    0010 0010: One or more suites failed at run time
    0010 0100: One or more suites should have failed but did not
    0010 1000: Catch all error

    Bitwise or of the above - multiple suites failed for combination of reasons
