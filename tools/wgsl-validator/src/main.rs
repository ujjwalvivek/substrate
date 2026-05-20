use std::{
    env, fs,
    path::{Path, PathBuf},
    process,
};

fn main() {
    let mut shared: Option<PathBuf> = None;
    let mut root: Option<PathBuf> = None;
    let mut feedback_bindings = false;
    let mut files: Vec<PathBuf> = Vec::new();

    let mut args = env::args().skip(1);
    while let Some(arg) = args.next() {
        match arg.as_str() {
            "--shared" => {
                let Some(path) = args.next() else { usage() };
                shared = Some(PathBuf::from(path));
            }
            "--root" => {
                let Some(path) = args.next() else { usage() };
                root = Some(PathBuf::from(path));
            }
            "--feedback-bindings" => {
                feedback_bindings = true;
            }
            "--help" | "-h" => {
                print_help();
                return;
            }
            other => files.push(PathBuf::from(other)),
        }
    }

    if files.is_empty() {
        let scan_root = root
            .as_deref()
            .map(Path::to_path_buf)
            .unwrap_or_else(|| env::current_dir().unwrap_or_default());
        files = discover_wgsl(&scan_root);
    }
    if files.is_empty() {
        eprintln!("no .wgsl files found");
        process::exit(2);
    }

    let shared_source = match &shared {
        Some(path) => match fs::read_to_string(path) {
            Ok(source) => Some(source),
            Err(error) => {
                eprintln!("cannot read shared file {}: {error}", path.display());
                process::exit(2);
            }
        },
        None => None,
    };

    let mut failed = false;
    for path in &files {
        match validate(path, shared_source.as_deref(), feedback_bindings) {
            Ok(()) => println!("valid: {}", path.display()),
            Err(report) => {
                failed = true;
                eprintln!("{report}");
            }
        }
    }

    if failed {
        eprintln!("validation FAILED");
        process::exit(1);
    }
    println!("OK: {} shader(s) valid.", files.len());
}

fn validate(path: &Path, shared: Option<&str>, feedback_bindings: bool) -> Result<(), String> {
    let source = fs::read_to_string(path)
        .map_err(|error| format!("cannot read {}: {error}", path.display()))?;

    let injected = if feedback_bindings && is_feedback_shader(&source) {
        FEEDBACK_BINDINGS
    } else {
        ""
    };
    let full = match shared {
        Some(prefix) => format!("{prefix}\n{injected}\n{source}"),
        None => format!("{injected}\n{source}"),
    };

    let label = path.display().to_string();
    match naga::front::wgsl::parse_str(&full) {
        Ok(module) => {
            let mut validator = naga::valid::Validator::new(
                naga::valid::ValidationFlags::all(),
                naga::valid::Capabilities::all(),
            );
            validator
                .validate(&module)
                .map(|_| ())
                .map_err(|error| format!("{label}: validation failed: {error}"))
        }
        Err(error) => Err(format!("{label}\n{}", error.emit_to_string(&full))),
    }
}

const FEEDBACK_BINDINGS: &str = r#"
@group(1) @binding(0) var feedbackSampler: sampler;
@group(1) @binding(1) var feedbackTexture: texture_2d<f32>;
"#;

fn is_feedback_shader(source: &str) -> bool {
    source
        .lines()
        .any(|line| line.contains("\"modes\"") && line.contains("\"feedback\""))
}

fn discover_wgsl(dir: &Path) -> Vec<PathBuf> {
    let mut found = Vec::new();
    let Ok(entries) = fs::read_dir(dir) else {
        return found;
    };
    for entry in entries.flatten() {
        let path = entry.path();
        if path.is_dir() {
            let name = path.file_name().and_then(|n| n.to_str()).unwrap_or("");
            if !matches!(name, "target" | "node_modules" | ".git") {
                found.extend(discover_wgsl(&path));
            }
        } else if path.extension().and_then(|e| e.to_str()) == Some("wgsl") {
            found.push(path);
        }
    }
    found.sort();
    found
}

fn print_help() {
    println!("usage: wgsl-validator [options] [files...]");
    println!();
    println!("Validates WGSL shaders with naga (the wgpu front-end).");
    println!("With no files given, scans the working directory recursively");
    println!("(skips target/, node_modules/, .git/).");
    println!();
    println!("options:");
    println!("  --shared <file.wgsl>       prepend shared WGSL to each file");
    println!("  --root <directory>         scan this directory when no files are given");
    println!("  --feedback-bindings        inject renderer feedback bindings for feedback shaders");
}

fn usage() -> ! {
    eprintln!("usage: wgsl-validator [options] [files...]");
    process::exit(2);
}
