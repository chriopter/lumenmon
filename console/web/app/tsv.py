#!/usr/bin/env python3
# TSV file reading and parsing utilities.
# Handles efficient reading of last N lines from TSV files.

import os

def read_last_line(filepath):
    """Read the last line of a file efficiently."""
    try:
        with open(filepath, 'rb') as f:
            f.seek(0, os.SEEK_END)
            file_size = f.tell()
            if file_size == 0:
                return None

            buffer_size = min(1024, file_size)
            f.seek(max(0, file_size - buffer_size))
            lines = f.read().decode('utf-8', errors='ignore').splitlines()

            for line in reversed(lines):
                if line.strip():
                    return line.strip()
    except Exception as e:
        print(f"Error reading {filepath}: {e}")
    return None

def read_last_n_lines(filepath, n=10):
    """Read the last N lines of a file."""
    try:
        with open(filepath, 'rb') as f:
            f.seek(0, os.SEEK_END)
            file_size = f.tell()
            if file_size == 0:
                return []

            buffer_size = min(8192, file_size)
            f.seek(max(0, file_size - buffer_size))
            lines = f.read().decode('utf-8', errors='ignore').splitlines()

            result = []
            for line in reversed(lines):
                if line.strip():
                    result.append(line.strip())
                    if len(result) >= n:
                        break

            return list(reversed(result))
    except Exception as e:
        print(f"Error reading {filepath}: {e}")
    return []

def parse_tsv_line(line):
    """Parse TSV line: timestamp interval value"""
    if not line:
        return None, None

    parts = line.split('\t')
    if len(parts) < 3:
        parts = line.split()

    if len(parts) >= 3:
        try:
            timestamp = int(parts[0])
            value = float(parts[2].rstrip('%'))
            return timestamp, value
        except (ValueError, IndexError):
            pass
    return None, None
