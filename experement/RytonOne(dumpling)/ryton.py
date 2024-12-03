import sys
from RytonOne import SharpyLang

def main():
    if len(sys.argv) != 2:
        print("Usage: python ryton_interpreter.py <filename>")
        sys.exit(1)

    filename = sys.argv[1]
    with open(filename, 'r') as file:
        code = file.read()

    sharpy = SharpyLang()
    sharpy.execute(code)

if __name__ == "__main__":
    main()
