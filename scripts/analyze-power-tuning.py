#!/usr/bin/env python3

"""
Lambda Power Tuning Results Analyzer
Parses Power Tuning results and generates comparison graphs
"""

import json
import sys
import os
from pathlib import Path
from datetime import datetime
import argparse

try:
    import matplotlib.pyplot as plt
    import numpy as np
    MATPLOTLIB_AVAILABLE = True
except ImportError:
    MATPLOTLIB_AVAILABLE = False
    print("⚠️  matplotlib not installed. Install with: pip install matplotlib numpy")


def load_results(filepath):
    """Load and parse Power Tuning results JSON"""
    try:
        with open(filepath, 'r') as f:
            data = json.load(f)
        return data
    except Exception as e:
        print(f"❌ Error loading {filepath}: {e}")
        return None


def extract_metrics(results):
    """Extract metrics from Power Tuning results"""
    if not results:
        return None
    
    stats = results.get('stats', [])
    if not stats:
        stats = results.get('results', {}).get('stats', [])
    metrics = {
        'memory': [],
        'duration': [],
        'cost': [],
        'costPerMillion': [],
        'executions': []
    }
    
    for stat in stats:
        metrics['memory'].append(stat.get('memorySize', stat.get('value', 0)))
        metrics['duration'].append(stat.get('duration', stat.get('averageDuration', 0)))
        cost = stat.get('cost', stat.get('averagePrice', 0))
        metrics['cost'].append(cost)
        metrics['costPerMillion'].append(stat.get('costPerMillion', cost * 1000000))
        metrics['executions'].append(stat.get('count', stat.get('invocations', 0)))
    
    return metrics


def print_results_table(results, filepath=None):
    """Print results in a formatted table"""
    metrics = extract_metrics(results)
    if not metrics:
        print("❌ No metrics found in results")
        return
    
    print("\n" + "="*100)
    if filepath:
        print(f"📊 Results from: {filepath}")
    print("="*100)
    
    print(f"{'Memory':<12} {'Duration':<15} {'Cost/1M':<15} {'Cost/Inv':<15} {'Executions':<12}")
    print("-"*100)
    
    for i in range(len(metrics['memory'])):
        mem = metrics['memory'][i]
        dur = metrics['duration'][i]
        cost_per_m = metrics['costPerMillion'][i]
        cost_inv = metrics['cost'][i]
        execs = metrics['executions'][i]
        
        print(f"{mem:<12.0f} {dur:<15.2f}ms ${cost_per_m:<14.4f} ${cost_inv:<14.8f} {execs:<12.0f}")
    
    # Find optimal setting
    if metrics['costPerMillion']:
        min_cost_idx = metrics['costPerMillion'].index(min(metrics['costPerMillion']))
        optimal_memory = metrics['memory'][min_cost_idx]
        optimal_cost = metrics['costPerMillion'][min_cost_idx]
        optimal_duration = metrics['duration'][min_cost_idx]
        
        print("-"*100)
        print(f"\n💰 Optimal Memory Setting (lowest cost): {optimal_memory:.0f} MB")
        print(f"   Duration: {optimal_duration:.2f}ms | Cost per 1M: ${optimal_cost:.4f}")
    
    print("="*100 + "\n")


def generate_comparison_graph(results_files, output_file="tests/load/results/comparison.png"):
    """Generate comparison graph from multiple result files"""
    if not MATPLOTLIB_AVAILABLE:
        print("⚠️  Skipping graph generation (matplotlib required)")
        return
    
    fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(16, 12))
    fig.suptitle('Lambda Power Tuning Analysis', fontsize=16, fontweight='bold')
    
    colors = plt.cm.Set3(np.linspace(0, 1, len(results_files)))
    
    for idx, results_file in enumerate(results_files):
        results = load_results(results_file)
        if not results:
            continue
        
        metrics = extract_metrics(results)
        if not metrics:
            continue
        
        label = Path(results_file).stem
        color = colors[idx]
        
        # Duration vs Memory
        ax1.plot(metrics['memory'], metrics['duration'], 'o-', 
                label=label, linewidth=2, markersize=8, color=color)
        ax1.set_xlabel('Memory (MB)', fontsize=11, fontweight='bold')
        ax1.set_ylabel('Duration (ms)', fontsize=11, fontweight='bold')
        ax1.set_title('Execution Duration vs Memory', fontweight='bold')
        ax1.grid(True, alpha=0.3)
        ax1.legend()
        
        # Cost per 1M invocations
        ax2.plot(metrics['memory'], metrics['costPerMillion'], 's-', 
                label=label, linewidth=2, markersize=8, color=color)
        ax2.set_xlabel('Memory (MB)', fontsize=11, fontweight='bold')
        ax2.set_ylabel('Cost per 1M Invocations ($)', fontsize=11, fontweight='bold')
        ax2.set_title('Cost vs Memory', fontweight='bold')
        ax2.grid(True, alpha=0.3)
        ax2.legend()
        
        # Cost per invocation
        ax3.plot(metrics['memory'], [c*1000000 for c in metrics['cost']], '^-', 
                label=label, linewidth=2, markersize=8, color=color)
        ax3.set_xlabel('Memory (MB)', fontsize=11, fontweight='bold')
        ax3.set_ylabel('Cost per Invocation ($)', fontsize=11, fontweight='bold')
        ax3.set_title('Cost per Invocation vs Memory', fontweight='bold')
        ax3.grid(True, alpha=0.3)
        ax3.legend()
        
        # Efficiency (1000/duration per dollar)
        efficiency = [1000/metrics['costPerMillion'][i] if metrics['costPerMillion'][i] > 0 else 0 
                     for i in range(len(metrics['memory']))]
        ax4.plot(metrics['memory'], efficiency, 'd-', 
                label=label, linewidth=2, markersize=8, color=color)
        ax4.set_xlabel('Memory (MB)', fontsize=11, fontweight='bold')
        ax4.set_ylabel('Efficiency (ms/$)', fontsize=11, fontweight='bold')
        ax4.set_title('Efficiency vs Memory', fontweight='bold')
        ax4.grid(True, alpha=0.3)
        ax4.legend()
    
    plt.tight_layout()
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    print(f"✅ Graph saved to: {output_file}")
    print(f"   Open this file to view the performance analysis")


def main():
    parser = argparse.ArgumentParser(
        description='Analyze Lambda Power Tuning results',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # View a single result
  python3 scripts/analyze-power-tuning.py tests/load/results/results-20240101_120000.json
  
  # Compare multiple results
  python3 scripts/analyze-power-tuning.py \\
    tests/load/results/results-before.json \\
    tests/load/results/results-after.json \\
    --compare
  
  # Generate comparison graph
  python3 scripts/analyze-power-tuning.py \\
    tests/load/results/results-*.json \\
    --graph
        """
    )
    
    parser.add_argument('files', nargs='+', help='Result JSON files to analyze')
    parser.add_argument('--compare', action='store_true', help='Compare multiple results')
    parser.add_argument('--graph', action='store_true', help='Generate comparison graph')
    parser.add_argument('--output', default='tests/load/results/comparison.png', help='Output graph file')
    
    args = parser.parse_args()
    
    # Expand glob patterns
    all_files = []
    for pattern in args.files:
        if not pattern:
            continue
        matches = list(Path('.').glob(pattern))
        all_files.extend([str(f) for f in matches if f.is_file()])
    
    if not all_files:
        print(f"❌ No files found matching: {args.files}")
        sys.exit(1)
    
    all_files.sort()
    
    if len(all_files) == 1:
        # Single file - just print table
        results = load_results(all_files[0])
        if results:
            print_results_table(results, all_files[0])
    else:
        # Multiple files
        print(f"\n📊 Analyzing {len(all_files)} result files...\n")
        
        for results_file in all_files:
            results = load_results(results_file)
            if results:
                print_results_table(results, results_file)
        
        if args.compare or args.graph:
            print("\n📈 Generating comparison...")
            generate_comparison_graph(all_files, args.output)
    
    print("\n✅ Analysis complete!")


if __name__ == '__main__':
    main()
