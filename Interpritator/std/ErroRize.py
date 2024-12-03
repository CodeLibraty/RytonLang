import os
import sys

def error(massage=None, type=None, critical=False):
    if not massage:
        sys.exit(1)

    if not type:
        print('Error: not arg "type" error')
        sys.exit(1)

    print(f'\033[1m\033[31m[{type} ERROR]\033[0m \033[31m{massage}\033[0m')

    if critical == True:
        sys.exit(1)
    elif critical == False:
        pass
    else:
        print(f'Error: arg "critical" only: True or False')
        sys.exit(1)
