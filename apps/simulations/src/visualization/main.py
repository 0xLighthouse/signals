"""
Main visualization pipeline for orchestrating chart generation.
"""

from pathlib import Path
from typing import Dict, Any, List, Optional
import matplotlib.pyplot as plt

from .data_loader import SimulationDataLoader
from .charts import TimelineChart, GovernanceMetricsChart, UserBehaviorChart, TokenFluxChart
from ..cadcad.config import get_visualization_config


class VisualizationPipeline:
    """Main pipeline for generating all visualization charts."""

    def __init__(self, results_dir: str = "results"):
        """Initialize the visualization pipeline."""
        self.config = get_visualization_config()
        self.data_loader = SimulationDataLoader(results_dir)

        # Initialize chart instances
        self.charts = {
            "timeline": TimelineChart(),
            "governance": GovernanceMetricsChart(),
            "user_behavior": UserBehaviorChart(),
            "token_flux": TokenFluxChart(),
        }

    def generate_all_charts(
        self, csv_path: Optional[Path] = None, summary_path: Optional[Path] = None
    ) -> Dict[str, plt.Figure]:
        """Generate all charts and return them as a dictionary."""
        # Load data
        if csv_path:
            df, summary = self.data_loader.load_results(csv_path, summary_path)
        else:
            df, summary = self.data_loader.load_latest_results()

        print(f"📊 Generating visualizations from {len(df)} data points...")

        # Generate all charts
        figures = {}
        for chart_name, chart_instance in self.charts.items():
            try:
                print(f"📈 Creating {chart_name} chart...")
                fig = chart_instance.create(df, summary)
                figures[chart_name] = fig
                print(f"✅ {chart_name} chart created successfully")
            except Exception as e:
                print(f"❌ Error creating {chart_name} chart: {e}")
                # Continue with other charts even if one fails
                continue

        return figures

    def save_all_charts(
        self, figures: Dict[str, plt.Figure], output_dir: Optional[Path] = None
    ) -> List[Path]:
        """Save all charts to files."""
        if output_dir is None:
            output_dir = Path(self.config.output_dir)

        output_dir.mkdir(parents=True, exist_ok=True)
        saved_files = []

        for chart_name, fig in figures.items():
            try:
                output_path = output_dir / f"{chart_name}.{self.config.figure_format}"

                # Use the chart's save method for consistent settings
                chart_instance = self.charts[chart_name]
                chart_instance.save_chart(fig, output_path)

                saved_files.append(output_path)
                print(f"💾 Saved {chart_name} chart to {output_path}")
            except Exception as e:
                print(f"❌ Error saving {chart_name} chart: {e}")
                continue

        return saved_files

    def show_all_charts(self, figures: Dict[str, plt.Figure]) -> None:
        """Display all charts if configured to do so."""
        if self.config.show_plots:
            print("🖼️  Displaying charts...")
            plt.show()
        else:
            print("📊 Charts generated but not displayed (show_plots=False)")

    def run_complete_pipeline(
        self,
        csv_path: Optional[Path] = None,
        summary_path: Optional[Path] = None,
        output_dir: Optional[Path] = None,
    ) -> Dict[str, Any]:
        """Run the complete visualization pipeline."""
        print("🚀 Starting visualization pipeline...")

        try:
            # Generate charts
            figures = self.generate_all_charts(csv_path, summary_path)

            if not figures:
                print("❌ No charts were generated successfully")
                return {"success": False, "figures": {}, "saved_files": []}

            # Save charts
            saved_files = self.save_all_charts(figures, output_dir)

            # Show charts if configured
            self.show_all_charts(figures)

            print(f"🎉 Visualization pipeline completed successfully!")
            print(f"📊 Generated {len(figures)} charts")
            print(f"💾 Saved {len(saved_files)} files")

            return {
                "success": True,
                "figures": figures,
                "saved_files": saved_files,
                "charts_generated": len(figures),
                "files_saved": len(saved_files),
            }

        except Exception as e:
            print(f"❌ Visualization pipeline failed: {e}")
            import traceback

            traceback.print_exc()
            return {"success": False, "error": str(e)}

    def generate_single_chart(
        self, chart_name: str, csv_path: Optional[Path] = None, summary_path: Optional[Path] = None
    ) -> Optional[plt.Figure]:
        """Generate a single chart by name."""
        if chart_name not in self.charts:
            print(f"❌ Unknown chart type: {chart_name}")
            print(f"Available charts: {list(self.charts.keys())}")
            return None

        # Load data
        if csv_path:
            df, summary = self.data_loader.load_results(csv_path, summary_path)
        else:
            df, summary = self.data_loader.load_latest_results()

        # Generate the specific chart
        try:
            print(f"📈 Creating {chart_name} chart...")
            chart_instance = self.charts[chart_name]
            fig = chart_instance.create(df, summary)
            print(f"✅ {chart_name} chart created successfully")
            return fig
        except Exception as e:
            print(f"❌ Error creating {chart_name} chart: {e}")
            import traceback

            traceback.print_exc()
            return None


def main():
    """Main function for running visualization as a script."""
    import argparse

    parser = argparse.ArgumentParser(description="Generate visualization charts")
    parser.add_argument("--results-dir", default="results", help="Results directory")
    parser.add_argument("--output-dir", help="Output directory for charts")
    parser.add_argument("--chart", help="Generate only a specific chart")
    parser.add_argument("--csv-path", help="Specific CSV file to visualize")
    parser.add_argument("--summary-path", help="Specific summary file to use")

    args = parser.parse_args()

    # Create pipeline
    pipeline = VisualizationPipeline(args.results_dir)

    # Convert string paths to Path objects if provided
    csv_path = Path(args.csv_path) if args.csv_path else None
    summary_path = Path(args.summary_path) if args.summary_path else None
    output_dir = Path(args.output_dir) if args.output_dir else None

    if args.chart:
        # Generate single chart
        fig = pipeline.generate_single_chart(args.chart, csv_path, summary_path)
        if fig and output_dir:
            output_dir.mkdir(parents=True, exist_ok=True)
            chart_instance = pipeline.charts[args.chart]
            output_path = output_dir / f"{args.chart}.{pipeline.config.figure_format}"
            chart_instance.save_chart(fig, output_path)
            print(f"💾 Saved {args.chart} chart to {output_path}")
        if fig and pipeline.config.show_plots:
            plt.show()
    else:
        # Run complete pipeline
        result = pipeline.run_complete_pipeline(csv_path, summary_path, output_dir)
        if not result["success"]:
            exit(1)


if __name__ == "__main__":
    main()
