# Final project report

This is the final submission supplied in `DFT_PROJECT_REPORT (2).zip` on
19 November 2026. Its 41 files are preserved exactly as exported from Overleaf.
This version supersedes earlier report drafts. The repository's member handoffs,
analysis data, and validation reports remain supporting development records.

- [DFT_PROJECT_REPORT.pdf](DFT_PROJECT_REPORT.pdf): compiled final report.
- [main.tex](main.tex): main IEEE-format document.
- [authors.tex](authors.tex): final shared-affiliation author block.
- [source_code_appendix.tex](source_code_appendix.tex): complete source appendix.
- [code_listings_setup.tex](code_listings_setup.tex): VHDL listing configuration.
- `image.png`: MIPS core simulation waveform supplied with the final report.
- The eight PDF/PNG plot pairs are the final titleless figures; matching copies
  replace the older figures under `docs/figures/`.
- The 19 VHDL files are self-contained appendix snapshots, byte-identical to
  their counterparts in `rtl/` and `tb/` at import time. Develop hardware using
  `rtl/` and `tb/`; keep the report snapshots synchronized when revising it.

`SOURCE_MANIFEST.json` is preserved from the uploaded export. Its paths describe
the earlier `code/` layout; the final appendix deliberately imports the flat
filenames stored beside `main.tex`.

## Compile locally

Run these commands from this directory with a LaTeX distribution installed:

```powershell
pdflatex -interaction=nonstopmode -halt-on-error main.tex
pdflatex -interaction=nonstopmode -halt-on-error main.tex
```

The result is `main.pdf`. All imported files and plots are local to this folder;
no sibling repository directory is required. For Overleaf, upload the contents
of this folder and select `main.tex` as the main document. The checked-in
`DFT_PROJECT_REPORT.pdf` was compiled from these exact source files.
