# Phase 6: Plots - Context

**Gathered:** 2026-02-27
**Status:** Ready for planning

<domain>
## Phase Boundary

11 publication-grade matplotlib figures, one per metric from Phase 5, plus shared rcParams styling. OO API only (no pyplot state). Each plot function returns a Figure object; saving is the caller's responsibility.

</domain>

<decisions>
## Implementation Decisions

### Visual style & theme
- Color palette: Blue for legacy/status-quo, orange for Signals/new-regime — colorblind-safe, high contrast
- Font: Serif (Times-like) for all text — traditional academic/journal look
- Grid: Light gray horizontal grid lines only — helps read values without clutter
- rcParams set once at module import for consistency across all 11 chart types

### Comparison layout
- Bar charts (flip rate, Gini, ENP, top-k): Grouped bars — legacy and Signals side-by-side per category
- Lorenz curve (PLOT-09): Both distributions overlaid on same axes with 45-degree equality line and shaded Gini area
- Margin shift histogram (PLOT-02): Per-proposal bars — x-axis = (Signals margin - Legacy margin), positive means Signals made result closer/flipped
- Every dual-regime chart includes its own legend — figures are self-contained for individual extraction

### Output format & saving
- Each plot function returns a `matplotlib.figure.Figure` object — caller decides where/how to save
- Output formats: PDF (vector, publication) + PNG (preview, web) — both generated per plot by pipeline
- PNG at 300 DPI — standard print quality
- File naming: descriptive slugs (e.g., `flip_rate_summary.pdf`, `lorenz_curve.png`, `margin_shift_histogram.pdf`)

### Proposal story plots (PLOT-10)
- One proposal per figure — caller loops for multiple proposals
- Y-axis: net margin over time = (FOR - AGAINST) / (FOR + AGAINST) running over votes
- Two lines per plot: legacy margin (blue) and Signals margin (orange)
- Annotate key moments: vertical dashed line at lock-in point, marker where outcome flips between regimes

### Cumulative vote curve (PLOT-07)
- Y-axis: raw cumulative FOR votes (not net margin — distinct from PLOT-10)
- Two lines: legacy cumulative and Signals cumulative
- X-axis: vote order within the proposal

### Claude's Discretion
- Figure size per chart type (single-column vs wide as appropriate)
- Exact subplot arrangements for multi-panel figures
- Annotation positioning and styling details
- Color shading intensity for Lorenz area fills
- Lock duration histogram (PLOT-11) styling details

</decisions>

<specifics>
## Specific Ideas

- Figures should be individually extractable for a paper — each one fully self-contained with title, legend, axis labels
- Net margin over time is the "story" view — it shows when and how regimes diverge on a proposal
- The margin shift histogram with per-proposal bars is more informative than binned for typical proposal counts (10-30)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 06-plots*
*Context gathered: 2026-02-27*
