"""Reproducible structural scan analysis; no physical power/coverage claims."""
import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BITS = 1024


def analyze():
    destination = ROOT / 'docs' / 'analysis'
    destination.mkdir(parents=True, exist_ok=True)
    with (destination / 'chain_comparison.csv').open('w', newline='') as stream:
        writer = csv.writer(stream)
        writer.writerow(['chains', 'min_length', 'max_length', 'imbalance',
                         'shift_clocks', 'shift_plus_capture_clocks',
                         'valid_output_bits', 'masked_output_slots',
                         'scan_data_ports', 'ideal_shift_speedup'])
        for chains in (1, 2, 3, 4, 8, 16, 32):
            lengths = [len(range(c, BITS, chains)) for c in range(chains)]
            assert sum(lengths) == BITS
            assert max(lengths) - min(lengths) <= 1
            longest = max(lengths)
            writer.writerow([chains, min(lengths), longest,
                             longest-min(lengths), longest, longest+1,
                             BITS, chains*longest-BITS, 2*chains,
                             round(BITS/longest, 6)])
    with (destination / 'scan_map_4chains.csv').open('w', newline='') as stream:
        writer = csv.writer(stream)
        writer.writerow(['state_bit', 'state_element', 'element_bit', 'chain',
                         'position_from_input', 'unload_cycle_zero_based'])
        for bit in range(BITS):
            chain = bit % 4
            position = bit // 4
            writer.writerow([bit, 'pc' if bit < 32 else f'r{bit//32}',
                             bit % 32, chain, position, 255-position])
    print('Wrote docs/analysis/chain_comparison.csv and scan_map_4chains.csv')


if __name__ == '__main__':
    analyze()
