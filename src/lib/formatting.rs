#![allow(clippy::enum_glob_use)]

use super::find_suites;
use super::suite;
use super::suite::CompileAndRunError;
use super::suite::GetSuiteConfigError;
use std::fmt;
use std::path::Path;
use std::process;

pub fn easy_format<F: Fn(&mut fmt::Formatter<'_>) -> fmt::Result>(func: F) -> impl fmt::Display {
    struct Formatable<F: Fn(&mut fmt::Formatter<'_>) -> fmt::Result> {
        func: F,
    }
    impl<F: Fn(&mut fmt::Formatter<'_>) -> fmt::Result> fmt::Display for Formatable<F> {
        fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
            (self.func)(f)
        }
    }
    Formatable { func }
}

fn process_output(output: &process::Output) -> impl fmt::Display + '_ {
    easy_format(move |f| {
        write!(
            f,
            r#"
 = Exit code: {} =
{}
{}"#,
            output.status,
            process_stdout(&output.stdout),
            process_stderr(&output.stderr)
        )
    })
}

fn process_stdout(stdout: &[u8]) -> impl fmt::Display + '_ {
    easy_format(move |f| {
        write!(
            f,
            r#" = Std Out =
{}"#,
            String::from_utf8_lossy(stdout)
        )
    })
}

fn process_stderr(stderr: &[u8]) -> impl fmt::Display + '_ {
    easy_format(move |f| {
        write!(
            f,
            r#" = Std Err =
{}"#,
            String::from_utf8_lossy(stderr)
        )
    })
}

fn compiler_error<'a>(
    err: &'a suite::CompileError,
    suite: impl AsRef<Path> + 'a,
) -> impl fmt::Display + 'a {
    easy_format(move |f| {
        use suite::CompileError::*;
        match err {
            ReadingTargets(err) => write!(
                f,
                "targets.txt found in suite {} but could not be read!. Details:\n{}",
                suite.as_ref().display(),
                err
            ),
            Process(err) => panic!("Failed to execute compiler! Details:\n{}", err),
            Compiler(output) | CompilerStdErrNotEmpty(output) => {
                write!(f, "Compilation failed!\n{}", process_output(&output))
            }
            SuiteDoesNotExist => {
                panic!("Path was not suite - this should have been checked already!")
            }
            DeletingElmStuff(e) => panic!("Could not delete elm-stuff directory! Details: {}", e),
        }
    })
}

fn run_error<'a>(err: &'a suite::RunError, out_dir: &'a Path) -> impl fmt::Display + 'a {
    easy_format(move |f| {
        use suite::RunError::*;
        match err {
            NodeNotFound(err) => write!(
                f,
                "Could not find node executable to run generated Javascript. Details:\n{}",
                err
            ),
            SuiteDoesNotExist => {
                panic!("Path was not suite - this should have been checked already!")
            }
            NodeProcess(err) => panic!("The node process errored unexpectedly:\n{}", err),
            WritingHarness(err) => panic!(
                "Cannot add the test harness to the output directory. Details:\n{}",
                err
            ),
            ExpectedOutputNotUtf8(_) => panic!("Expected output is not valid utf8"),
            CopyingExpectedOutput(err) => panic!(
                "The expected output exists but cannot be copied. Details:\n{}",
                err
            ),
            Runtime(output) => {
                write!(f, "{}", process_output(&output))?;
                write!(
                    f,
                    "\n\nTo inspect the built files that caused this error see:\n  {}",
                    out_dir.display()
                )
            }

            OutputProduced(output) => write!(
                f,
                "The suite ran without error but produced the following output!:\n{}",
                process_output(&output)
            ),
            Timeout {
                after,
                stdout,
                stderr,
            } => write!(
                f,
                "Running of the suite was stopped after {}.{}

To inspect the built files that caused this error see: {}",
                humantime::format_duration(*after),
                easy_format(|f| {
                    if !stdout.is_empty() || !stderr.is_empty() {
                        write!(
                            f,
                            " Before it stopped the process procuduced the following output:
{}
{}",
                            process_stdout(stdout),
                            process_stderr(stderr)
                        )
                    } else {
                        write!(f, "(The process prouduced no output)")
                    }
                }),
                out_dir.display()
            ),
            WritingExpectedOutput(err) => panic!(
                "Error whilst writing expected output to disk. Details:\n{}",
                err
            ),
        }
    })
}

pub fn compile_and_run_error<'a, Pe: AsRef<Path> + 'a, Ps: AsRef<Path> + 'a>(
    err: &'a CompileAndRunError,
    suite: Ps,
    out_dir: Pe,
    retries: usize,
) -> impl fmt::Display + 'a {
    easy_format(move |f| {
        use CompileAndRunError::*;
        use GetSuiteConfigError::*;

        match &err {
            SuiteNotExist => write!(
                f,
                "The provided path to a suite: \"{}\"  does not exist",
                suite.as_ref().display()
            ),

            SuiteNotDir => write!(
                f,
                "The provided path to a suite: \"{}\" exists but is not a directory",
                suite.as_ref().display()
            ),

            SuiteNotElm => write!(
                f,
                "The suite directory: \"{}\" is not an Elm application or package",
                suite.as_ref().display()
            ),

            OutDirIsNotDir => write!(
                f,
                "{} must either be a directory or a path where elm-torture can create one!",
                out_dir.as_ref().display()
            ),

            CannotGetSuiteConfig(CannotRead(e)) => write!(
                f,
                "{} {}",
                [
                    "Each suite must contain a file 'output.json', containing the text that",
                    "the suite should send to and receive from ports. When elm-torture tried",
                    "to read the file it got an error:"
                ]
                .join("\n"),
                e
            ),
            CannotGetSuiteConfig(Parse(error)) => write!(
                f,
                "Error parsing 'output.json' as a json file containing the suite config: {}",
                error
            ),

            CompileFailure { allowed, reason } => {
                write!(
                    f,
                    "Failed to compile suite {} after {} retries.\n{}\n",
                    &suite.as_ref().display(),
                    retries,
                    indented::indented(compiler_error(&reason, &suite))
                )?;
                if *allowed {
                    write!(f, "Failure allowed, continuing...")
                } else {
                    Ok(())
                }
            }

            RunFailure { allowed, reason } => {
                write!(
                    f,
                    "Suite {} failed at run time.\n{}\n",
                    &suite.as_ref().display(),
                    indented::indented(run_error(&reason, out_dir.as_ref()))
                )?;
                if *allowed {
                    write!(f, "Failure allowed, continuing...")
                } else {
                    Ok(())
                }
            }

            ExpectedCompileFailure => write!(
                f,
                "elm-torture expected a failure when compiling suite {}",
                &suite.as_ref().display(),
            ),
            ExpectedRunFailure => write!(
                f,
                "elm-torture expected a failure when running suite {}",
                &suite.as_ref().display(),
            ),

            Server(err) => write!(f, "could not run testing server {}", &err),
        }
    })
}

pub fn find_suite_error<'a>(
    err: &'a find_suites::Error,
    suite_dir: &'a Path,
) -> impl fmt::Display + 'a {
    easy_format(move |fmt| {
        use find_suites::Error::*;
        match err {
            ProvidedPathIsNotDir => write!(
                fmt,
                "elm-torture cannot run suites in {} as it is not a directory!
    Please check the path and try again.
    ",
                suite_dir.display()
            ),
            ReadingDir(e) => Err(e).unwrap(),
        }
    })
}

pub fn suites_error(err: &suite::SuitesError) -> impl fmt::Display + '_ {
    use suite::SuitesError;
    easy_format(move |_| match err {
        SuitesError::ResolvingCompiler(e) => panic!("Could not resolve the elm compiler {:?}", e), // SuitesError::CannotDetectStdlibVariant(e) => {
                                                                                                   //     panic!("Failed to detect stdlib variant due to error: {:?}", e)
                                                                                                   // }
    })
}

#[macro_export]
macro_rules! writeln_indented {
    ($dst:expr, $($arg:tt)*) => (std::write!(
        $dst,
        "{}",
        indented::indented($crate::formatting::easy_format(|f| {
            writeln!(f, $($arg)*)
        }))
    ))
}
