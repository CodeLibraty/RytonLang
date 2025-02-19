import argparse
import os
from RytonBundleBuilder import pack_ryx_project
from RytonBundleUnPacker import unpack_ryx

def get_cache_dir(ryx_path):
    """Получаем путь к кэш-директории для конкретного .ryx"""
    cache_base = os.path.expanduser('~/.ryton/cache')
    ryx_name = os.path.basename(ryx_path)
    return os.path.join(cache_base, ryx_name)

def main():
    parser = argparse.ArgumentParser(description='Ryton RYX bundle tool')
    subparsers = parser.add_subparsers(dest='command')

    # Команда pack
    pack_parser = subparsers.add_parser('pack', help='Pack project into .ryx bundle')
    pack_parser.add_argument('project_dir', help='Project directory to pack')
    pack_parser.add_argument('-o', '--output', help='Output .ryx file', default='app.ryx')

    # Команда unpack
    unpack_parser = subparsers.add_parser('unpack', help='Unpack .ryx bundle')
    unpack_parser.add_argument('ryx_file', help='RYX file to unpack')
    unpack_parser.add_argument('-d', '--dir', help='Directory to extract to')

    # Команда run
    run_parser = subparsers.add_parser('run', help='Run .ryx bundle')
    run_parser.add_argument('ryx_file', help='RYX file to run')

    args = parser.parse_args()

    if args.command == 'pack':
        pack_ryx_project(args.project_dir, args.output)
        print(f"Packed project to {args.output}")

    elif args.command == 'unpack':
        extract_dir = args.dir or f"./extracted_{os.path.basename(args.ryx_file)}"
        metadata = unpack_ryx(args.ryx_file, extract_dir)
        print(f"Unpacked {metadata['name']} v{metadata['version']} to {extract_dir}")

    elif args.command == 'run':
        cache_dir = get_cache_dir(args.ryx_file)
        metadata = unpack_ryx(args.ryx_file, get_cache_dir(args.ryx_file))
        print(f"Running {metadata['name']} v{metadata['version']}")
        
        # Запускаем main.py из кэша
        os.chdir(cache_dir)
        os.system(f"ryton run {os.path.join(get_cache_dir(args.ryx_file), 'DeltaShell.ry')}")

if __name__ == '__main__':
    main()
