"""
reports.py - PDF report generation with matplotlib charts.
"""
import io
import logging
from datetime import datetime
import matplotlib
matplotlib.use('Agg')  # Non-interactive backend
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
import numpy as np

logger = logging.getLogger(__name__)


def generate_report_pdf(simulation_result):
    """
    Generate a PDF report from a simulation result dict.
    Returns bytes of the PDF file.
    """
    result = simulation_result
    meta = result.get("job_meta", {})
    risk = result.get("combined_risk", {})
    stats = result.get("simulation_stats", {})
    t = stats.get("time", {})
    c = stats.get("cost", {})

    fig, axes = plt.subplots(2, 2, figsize=(11, 8.5))
    fig.suptitle("SCDO Simulation Report", fontsize=16, fontweight="bold", y=0.98)

    # ── Panel 1: Route & Meta Info ────────────────────────────
    ax1 = axes[0, 0]
    ax1.axis("off")
    cities = meta.get("cities", [])
    modes = meta.get("modes", [])
    route_str = ""
    for i, city in enumerate(cities):
        route_str += city
        if i < len(modes):
            route_str += f"  —[{modes[i]}]→  "

    info_lines = [
        f"Route: {route_str}",
        f"Cargo: {meta.get('cargo_type', 'N/A')}",
        f"Iterations: {stats.get('iterations', 'N/A')}",
        f"Date: {meta.get('target_date', 'N/A')}",
        f"Generated: {meta.get('timestamp', datetime.utcnow().isoformat())[:19]}",
        "",
        f"Combined Risk Score: {risk.get('score', 'N/A')}",
        f"Risk Level: {risk.get('level', 'N/A')}",
        f"Route Viable: {'Yes' if risk.get('route_viable', True) else 'NO'}",
        f"Recommendation: {risk.get('recommendation', 'N/A')}",
    ]
    ax1.text(0.05, 0.95, "\n".join(info_lines), transform=ax1.transAxes,
             fontsize=8, verticalalignment="top", fontfamily="monospace",
             bbox=dict(boxstyle="round,pad=0.5", facecolor="lightyellow", alpha=0.8))
    ax1.set_title("Route & Risk Summary", fontsize=10, fontweight="bold")

    # ── Panel 2: Lead Time Distribution ───────────────────────
    ax2 = axes[0, 1]
    if t:
        time_vals = [t.get("min",0), t.get("p5",0), t.get("mean",0),
                     t.get("p50",0), t.get("p95",0), t.get("max",0)]
        labels = ["Min", "P5", "Mean", "P50", "P95", "Max"]
        colors = ["#2ecc71", "#3498db", "#e74c3c", "#9b59b6", "#e67e22", "#95a5a6"]
        bars = ax2.bar(labels, time_vals, color=colors, edgecolor="white", linewidth=0.5)
        ax2.set_ylabel("Hours")
        ax2.set_title("Lead Time Distribution", fontsize=10, fontweight="bold")
        for bar, val in zip(bars, time_vals):
            ax2.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 1,
                     f"{val:.0f}h", ha="center", va="bottom", fontsize=7)

    # ── Panel 3: Cost Distribution ────────────────────────────
    ax3 = axes[1, 0]
    if c:
        cost_vals = [c.get("min",0), c.get("p5",0), c.get("mean",0),
                     c.get("p50",0), c.get("p95",0), c.get("max",0)]
        labels = ["Min", "P5", "Mean", "P50", "P95", "Max"]
        colors = ["#27ae60", "#2980b9", "#c0392b", "#8e44ad", "#d35400", "#7f8c8d"]
        bars = ax3.bar(labels, cost_vals, color=colors, edgecolor="white", linewidth=0.5)
        ax3.set_ylabel("USD ($)")
        ax3.set_title("Cost Distribution", fontsize=10, fontweight="bold")
        ax3.yaxis.set_major_formatter(ticker.FuncFormatter(lambda x, _: f"${x:,.0f}"))
        for bar, val in zip(bars, cost_vals):
            ax3.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 1,
                     f"${val:,.0f}", ha="center", va="bottom", fontsize=7)

    # ── Panel 4: Risk Breakdown ───────────────────────────────
    ax4 = axes[1, 1]
    weather_score = risk.get("weather_risk", {}).get("weather_risk_score", 0)
    sentiment_score = risk.get("sentiment_risk", {}).get("sentiment_risk_score", 0)
    combined_score = risk.get("score", 0)

    risk_labels = ["Weather\nRisk", "Sentiment\nRisk", "Combined\nRisk"]
    risk_vals = [weather_score, sentiment_score, combined_score]
    risk_colors = ["#3498db", "#e74c3c", "#f39c12"]
    bars = ax4.barh(risk_labels, risk_vals, color=risk_colors, edgecolor="white", height=0.5)
    ax4.set_xlim(0, 1.0)
    ax4.set_xlabel("Risk Score (0-1)")
    ax4.set_title("Risk Breakdown", fontsize=10, fontweight="bold")
    # Add threshold lines
    ax4.axvline(x=0.45, color="orange", linestyle="--", linewidth=0.8, alpha=0.7, label="Moderate")
    ax4.axvline(x=0.85, color="red", linestyle="--", linewidth=0.8, alpha=0.7, label="Critical")
    ax4.legend(fontsize=7, loc="lower right")
    for bar, val in zip(bars, risk_vals):
        ax4.text(val + 0.02, bar.get_y() + bar.get_height()/2,
                 f"{val:.3f}", ha="left", va="center", fontsize=8)

    plt.tight_layout(rect=[0, 0, 1, 0.95])

    # Save to bytes
    buf = io.BytesIO()
    fig.savefig(buf, format="pdf", dpi=150, bbox_inches="tight")
    plt.close(fig)
    buf.seek(0)
    return buf.getvalue()
