import os
import sys
import io

def debug(text, logs=False, folder=None):
    if logs == True:
        print(f'\033[1m\033[36m[DEBUG]\033[0m \033[36m{text}\033[0m')
    
        if folder:
            os.makedirs(f'./{folder}', exist_ok=True)
    
            with open(f'./{folder}/log.log', 'a', encoding='utf-8') as file_log:
                file_log.write(f'\n{text}')
        else:
            print("Error: not found path folder for logs")


    elif logs == False:
        pass

def clear_logs(folder=None):
    if folder:
        print('\033[1m\033[36m[Logs clear]\033[0m')
        try:
            os.remove(f'./{folder}/log.log')
        except Exception as e:
            print(e)
    else:
        print("Error: not found path folder for remove logs")
