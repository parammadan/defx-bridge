# Loaded by bin/defxbridge. Sources the package code from the repository (no
# installation step needed) into a private environment and runs the CLI.
local({
  args <- commandArgs(trailingOnly = TRUE)
  root <- args[1]
  if (!requireNamespace("openxlsx", quietly = TRUE)) {
    message("defxbridge: error: R package 'openxlsx' is not installed; ",
            "run: Rscript -e 'install.packages(\"openxlsx\")'")
    quit(save = "no", status = 1L)
  }
  env <- new.env(parent = globalenv())
  files <- sort(list.files(file.path(root, "R"), pattern = "\\.R$", full.names = TRUE),
                method = "radix")
  for (f in files) sys.source(f, envir = env, keep.source = FALSE)
  status <- env$defxbridge_main(args[-1])
  quit(save = "no", status = status)
})
