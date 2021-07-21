#!/usr/bin/env python3

import argparse

def main():
    parser = argparse.ArgumentParser(description=(
        "Generate a changelog (markdown) from the merge commits found in a revision range.\n"
        "By default, the range starts from the last tag and ends with the HEAD revision."
    ))
    parser.add_argument('rev1', metavar='REV1', type=str, nargs='?', help='Start revision (default: last tag)')
    parser.add_argument('rev2', metavar='REV2', type=str, nargs='?', help='End revision (default: HEAD)')

    args = parser.parse_args()
















if __name__ == "__main__":
    main()
