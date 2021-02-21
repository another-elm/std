#![warn(clippy::all, clippy::pedantic)]
// https://github.com/rust-lang/rust-clippy/issues/5822
#![allow(clippy::option_if_let_else)]

mod lib;

use colored::Colorize;
use lib::cli;
use lib::formatting;
use lib::suite;
use rayon::prelude::*;
use std::io::Write;
use std::{collections::HashSet, fs, process};
use std::{num::NonZeroI32, path::Path};

const WELCOME_MESSAGE: &str = "Elm Torture - stress tests for an elm compiler";

const CATCH_ALL_ERROR_CODE: i32 = 0x28;

#[allow(clippy::enum_glob_use)]
fn get_exit_code(err: &suite::CompileAndRunError) -> i32 {
    use suite::CompileAndRunError::*;

    match err {
        SuiteNotExist
        | SuiteNotDir
        | SuiteNotElm
        | OutDirIsNotDir
        | CannotGetSuiteConfig(_)
        | Server(_) => CATCH_ALL_ERROR_CODE,

        CompileFailure { allowed, .. } => {
            if *allowed {
                0
            } else {
                0x21
            }
        }

        RunFailure { allowed, .. } => {
            if *allowed {
                0
            } else {
                0x22
            }
        }
        ExpectedCompileFailure | ExpectedRunFailure => 0x24,
    }
}

fn sscce_result_printer(
    suite::CompileAndRunResults {
        suite,
        sscce_out_dir,
        errors,
    }: &suite::CompileAndRunResults<impl AsRef<Path>>,
) {
    let errors_to_print = errors.iter().filter_map(|(ol, (retries, me))| match me {
        Some(suite::CompileAndRunError::RunFailure { allowed, .. })
        | Some(suite::CompileAndRunError::CompileFailure { allowed, .. })
            if *allowed =>
        {
            None
        }
        e => e.as_ref().map(|ee| (ol, (retries, ee))),
    });
    for ((elm_compiler, opt_level), (retries, e)) in errors_to_print {
        println!(
            "{} compiling with {} in {} optimisation mode\n{}",
            suite.as_ref().display().to_string().black().on_white(),
            elm_compiler.to_string().black().on_white(),
            opt_level.to_string().black().on_white(),
            indented::indented(formatting::compile_and_run_error(
                e,
                suite,
                &sscce_out_dir,
                *retries
            ))
        );
    }
}

#[allow(clippy::too_many_lines)]
fn run_suites(
    suites: &[impl AsRef<Path> + Sync],
    instructions: &cli::Instructions,
) -> Option<NonZeroI32> {
    assert!(!suites.is_empty());
    println!(
        "{}

Running the following {} SSCCE{}:
{}
",
        WELCOME_MESSAGE,
        suites.len(),
        if suites.len() == 1 { "" } else { "s" },
        indented::indented(formatting::easy_format(|f| {
            for path in suites.iter() {
                writeln!(f, "{}", path.as_ref().display())?
            }
            Ok(())
        }))
    );

    match suite::compile_and_run_suites(suites.par_iter(), instructions) {
        Ok(res_iter) => {
            let suite_results: Vec<_> = res_iter
                .into_par_iter()
                .inspect(sscce_result_printer)
                .collect();

            println!(
                "
elm-torture has run the following {} SSCCE{}:
{}
",
                suites.len(),
                if suites.len() == 1 { "" } else { "s" },
                indented::indented(formatting::easy_format(|f| {
                    let mut opt_levels_of_interest = HashSet::new();
                    loop {
                        let mut current_opt_level = None;
                        for suite::CompileAndRunResults { suite, errors, .. } in &suite_results {
                            use suite::CompileAndRunError;
                            for (sscce_run_type, (_, possible_error)) in errors.iter() {
                                let (compiler, run_opt_level) = sscce_run_type;
                                let should_print = if let Some(ol) = current_opt_level {
                                    ol == sscce_run_type
                                } else if opt_levels_of_interest.contains(sscce_run_type) {
                                    false
                                } else {
                                    current_opt_level = Some(sscce_run_type);
                                    opt_levels_of_interest.insert(sscce_run_type);
                                    writeln!(
                                        f,
                                        "Compiling with {} in {} optimisation mode",
                                        compiler.to_string().black().on_white(),
                                        run_opt_level.to_string().black().on_white(),
                                    )?;
                                    true
                                };
                                if should_print {
                                    writeln_indented!(
                                f,
                                "{} ({})",
                                suite.as_ref().display(),
                                match possible_error {
                                    Some(CompileAndRunError::RunFailure {
                                        allowed: true, ..
                                    }) => "allowed run failure".yellow(),
                                    Some(CompileAndRunError::CompileFailure {
                                        allowed: true,
                                        ..
                                    }) => "allowed compile failure".yellow(),
                                    Some(CompileAndRunError::ExpectedCompileFailure) =>
                                        "success when elm-torture expected a compile time failure"
                                            .red(),
                                    Some(CompileAndRunError::ExpectedRunFailure) =>
                                        "success when elm-torture expected a run time failure".red(),
                                    Some(_) => "failure".red(),
                                    None => "success".green(),
                                }
                            )?
                                }
                            }
                        }
                        if current_opt_level.is_none() {
                            break;
                        }
                    }
                    Ok(())
                }))
            );
            let code = suite_results
                .iter()
                .flat_map(|suite::CompileAndRunResults { errors, .. }| {
                    errors.iter().filter_map(|(_, (_, e))| e.as_ref())
                })
                .fold(0, |code, error| code | get_exit_code(error));
            NonZeroI32::new(code)
        }
        Err(e) => {
            println!("{}", formatting::suites_error(&e));

            NonZeroI32::new(CATCH_ALL_ERROR_CODE)
        }
    }
}

fn run_app(instructions: cli::Instructions) -> Option<NonZeroI32> {
    match &instructions.task {
        cli::Task::DumpConfig(config_file) => {
            let mut file = fs::File::create(config_file).expect("could create config file");
            serde_json::to_writer_pretty(&mut file, &instructions.config.serialize())
                .expect("could not serialize config");
            writeln!(&mut file).expect("could not write to file config");
            None
        }
        cli::Task::RunSuites(ref suite_dir) => match lib::find_suites::find_suites(&suite_dir) {
            Ok(suites) => run_suites(&suites, &instructions),
            Err(ref err) => {
                eprint!("{}", formatting::find_suite_error(err, suite_dir));
                NonZeroI32::new(0x28)
            }
        },
    }
}

fn main() {
    env_logger::init();
    process::exit(run_app(cli::get_cli_task()).map_or(0, NonZeroI32::get));
}
