import Foundation

/// Heuristic mapping from `\usepackage` / `\documentclass` names
/// to TeX Live package names (CTAN → TL).
///
/// Source of truth for CTAN→TL: https://tug.org/~mseven/ctan-to-tl.tsv
/// Only entries where CTAN name ≠ TL name are listed.
public enum TeXLivePackageOverrides {
    public static let documentClass: [String: String] = [
        "book": "latex",
        "article": "latex",
        "report": "latex",
        "letter": "latex",
    ]

    public static let usepackage: [String: String] = [
        // MARK: - LaTeX core (part of `latex` distribution)
        "fontenc": "latex",
        "inputenc": "latex",
        "textcomp": "latex",
        "alltt": "latex",
        "ifthen": "latex",

        // MARK: - LaTeX tools bundle
        "array": "tools",
        "afterpage": "tools",
        "bm": "tools",
        "calc": "tools",
        "dcolumn": "tools",
        "enumerate": "tools",
        "hhline": "tools",
        "indentfirst": "tools",
        "longtable": "tools",
        "multicol": "tools",
        "shellesc": "tools",
        "showkeys": "tools",
        "tabularx": "tools",
        "theorem": "tools",
        "varioref": "tools",
        "verbatim": "tools",
        "xspace": "tools",

        // MARK: - Graphics bundle
        "graphicx": "graphics",
        "color": "graphics",
        "epsfig": "graphics",
        "trig": "graphics",
        "xcolor": "xcolor",

        // MARK: - AMS packages
        "amsfonts": "amsfonts",
        "amsmath": "amsmath",
        "amssymb": "amssymb",
        "amsthm": "amscls",
        "amscd": "amsmath",
        "amsopn": "amsmath",
        "amstext": "amsmath",

        // MARK: - Hyperref ecosystem
        "hyperref": "hyperref",
        "nameref": "hyperref",
        "backref": "hyperref",

        // MARK: - Caption system
        "caption": "caption",
        "subcaption": "caption",
        "bicaption": "caption",

        // MARK: - Title/sectioning
        "titlesec": "titlesec",
        "titleps": "titlesec",
        "titletoc": "titlesec",

        // MARK: - LaTeX3
        "expl3": "l3kernel",
        "xparse": "l3packages",

        // MARK: - KOMA-Script
        "koma-script": "koma-script",
        "scrartcl": "koma-script",
        "scrbase": "koma-script",
        "scrbook": "koma-script",
        "scrextend": "koma-script",
        "scrlayer": "koma-script",
        "scrlayer-scrpage": "koma-script",
        "scrletter": "koma-script",
        "scrlfile": "koma-script",
        "scrlttr2": "koma-script",
        "scrreprt": "koma-script",
        "tocbasic": "koma-script",
        "typearea": "koma-script",

        // MARK: - pgf / TikZ
        "tikz": "pgf",
        "pgfkeys": "pgf",
        "pgfplots": "pgfplots",
        "pgfplotstable": "pgfplots",

        // MARK: - Font bundles (psnfss)
        "helvet": "psnfss",
        "courier": "psnfss",
        "times": "psnfss",
        "mathptmx": "psnfss",
        "pifont": "psnfss",

        // MARK: - Engine detection (iftex)
        "ifetex": "iftex",
        "ifluatex": "iftex",
        "ifpdf": "iftex",
        "ifvtex": "iftex",
        "ifxetex": "iftex",
        "iftex": "iftex",

        // MARK: - BibTeX/bibliography
        "biblatex": "biblatex",
        "biber": "biber",
        "cite": "cite",
        "chapterbib": "cite",

        // MARK: - Common standalone packages (identity or near-identity)
        "fontspec": "fontspec",
        "polyglossia": "polyglossia",
        "babel": "babel",
        "booktabs": "booktabs",
        "fancyhdr": "fancyhdr",
        "enumitem": "enumitem",
        "listings": "listings",
        "minted": "minted",
        "csquotes": "csquotes",
        "microtype": "microtype",
        "siunitx": "siunitx",
        "luatex": "luatex",
        "pdftex": "pdftex",
        "natbib": "natbib",
        "makeidx": "latex",

        // MARK: - XeTeX / CJK
        "xetex": "xetex",
        "xeCJK": "xecjk",
        "ctex": "ctex",

        // MARK: - pstricks
        "pstricks-base": "pstricks",

        // MARK: - Miscellaneous high-frequency
        "bbm": "bbm-macros",
        "nicefrac": "units",
        "mathrsfs": "jknapltx",
        "mathrfs": "jknapltx",
    ]

    public static func texlivePackage(for element: TeXElement) -> String? {
        let key = element.value.lowercased()
        switch element.kind {
        case .documentClass: return documentClass[key]
        case .usepackage, .requirePackage: return usepackage[key]
        default: return nil
        }
    }
}
